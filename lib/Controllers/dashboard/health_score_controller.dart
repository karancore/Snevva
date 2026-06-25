import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../BMI/bmi_controller.dart';
import '../Hydration/hydration_stat_controller.dart';
import '../MoodTracker/mood_controller.dart';
import '../ReportScan/scan_report_controller.dart';
import '../SleepScreen/sleep_controller.dart';
import '../StepCounter/step_counter_controller.dart';

class HealthScoreController extends GetxController {
  // Score Variables
  RxDouble overallHealthScore = 0.0.obs;
  RxDouble ratingOutOf10 = 0.0.obs;
  RxString healthCategory = 'Loading...'.obs;
  RxString healthQuote = ''.obs;

  @override
  void onInit() {
    super.onInit();
    calculateHealthScore();
    _setupReactiveWorkers();
  }

  void _setupReactiveWorkers() {
    try {
      final stepCtrl = Get.find<StepCounterController>();
      debounce(
        stepCtrl.stepsHistoryByDate,
        (_) => calculateHealthScore(),
        time: const Duration(milliseconds: 400),
      );
    } catch (_) {}

    try {
      final sleepCtrl = Get.find<SleepController>();
      debounce(
        sleepCtrl.weeklySleepHistory,
        (_) => calculateHealthScore(),
        time: const Duration(milliseconds: 400),
      );
    } catch (_) {}

    try {
      final hydroCtrl = Get.find<HydrationStatController>();
      debounce(
        hydroCtrl.waterHistoryByDate,
        (_) => calculateHealthScore(),
        time: const Duration(milliseconds: 400),
      );
    } catch (_) {}

    try {
      final moodCtrl = Get.find<MoodController>();
      ever(moodCtrl.selectedMood, (_) => calculateHealthScore());
    } catch (_) {}

    try {
      final bmiCtrl = Get.find<BmiController>();
      ever(bmiCtrl.bmi_text, (_) => calculateHealthScore());
    } catch (_) {}
  }

  void calculateHealthScore() {
    double totalScore = 0.0;

    // Yesterday's Date
    DateTime yesterday = DateTime.now().subtract(const Duration(days: 1));
    String yesterdayKey = DateFormat('yyyy-MM-dd').format(yesterday);
    // yesterdayKey is zero-padded "yyyy-MM-dd" and used for all lookups

    // 1. Physical Activity = 20%
    double physicalScore = 0.0;
    try {
      if (Get.isRegistered<StepCounterController>()) {
        final stepCtrl = Get.find<StepCounterController>();
        int yesterdaySteps = stepCtrl.stepsHistoryByDate[yesterdayKey] ?? 0;
        int stepGoal =
            stepCtrl.stepGoal.value > 0 ? stepCtrl.stepGoal.value : 8000;
        double progress = yesterdaySteps / stepGoal;
        if (progress > 1.0) progress = 1.0;
        physicalScore = progress * 20.0;
      }
    } catch (e) {
      debugPrint("Error calculating Physical Activity score: \$e");
    }

    // 2. Sleep = 20%
    double sleepScore = 0.0;
    try {
      if (Get.isRegistered<SleepController>()) {
        final sleepCtrl = Get.find<SleepController>();
        Duration? yesterdaySleep = sleepCtrl.weeklySleepHistory[yesterdayKey];
        if (yesterdaySleep != null) {
          int sleepMins = yesterdaySleep.inMinutes;
          int goalMins =
              sleepCtrl.sleepGoal.value.inMinutes > 0
                  ? sleepCtrl.sleepGoal.value.inMinutes
                  : 480;
          double progress = sleepMins / goalMins;
          if (progress > 1.0) progress = 1.0;
          sleepScore = progress * 20.0;
        }
      }
    } catch (e) {
      debugPrint("Error calculating Sleep score: \$e");
    }

    // 3. Nutrition (Hydration) = 15%
    double nutritionScore = 0.0;
    try {
      if (Get.isRegistered<HydrationStatController>()) {
        final hydroCtrl = Get.find<HydrationStatController>();
        // waterHistoryByDate uses non-padded keys: "yyyy-M-d"
        String hydrationKey =
            "${yesterday.year}-${yesterday.month}-${yesterday.day}";
        int yesterdayWater = hydroCtrl.waterHistoryByDate[hydrationKey] ?? 0;
        int waterGoal =
            hydroCtrl.waterGoal.value > 0 ? hydroCtrl.waterGoal.value : 2000;
        double progress = yesterdayWater / waterGoal;
        if (progress > 1.0) progress = 1.0;
        nutritionScore = progress * 15.0;
      }
    } catch (e) {
      debugPrint("Error calculating Nutrition score: \$e");
    }

    // 4. Mental Wellness = 15%
    double mentalScore = 0.0;
    try {
      if (Get.isRegistered<MoodController>()) {
        final moodCtrl = Get.find<MoodController>();
        // Using current mood as proxy if yesterday's isn't easily accessible
        String currentMood = moodCtrl.selectedMood.value;
        if (currentMood == 'Pleasant' || currentMood == 'Good') {
          mentalScore = 15.0;
        } else if (currentMood == 'Unpleasant') {
          mentalScore = 5.0;
        } else {
          mentalScore = 10.0; // Default/Neutral
        }
      }
    } catch (e) {
      debugPrint("Error calculating Mental Wellness score: \$e");
    }

    // 5. Medical Reports = 20%
    double medicalScore =
        20.0; // Defaulting to max unless we can parse a negative report
    try {
      if (Get.isRegistered<ScanReportController>()) {
        final scanCtrl = Get.find<ScanReportController>();
        if (scanCtrl.reportHistory.isNotEmpty) {
          medicalScore = 18.0;
        }
      }
    } catch (e) {
      debugPrint("Error calculating Medical Reports score: \$e");
    }

    // 6. BMI & Lifestyle = 10%
    double bmiScore = 0.0;
    try {
      if (Get.isRegistered<BmiController>()) {
        final bmiCtrl = Get.find<BmiController>();
        String bmiText = bmiCtrl.bmi_text.value;
        if (bmiText == 'Great-Shape') {
          bmiScore = 10.0;
        } else if (bmiText == 'Underweight' || bmiText == 'Overweight') {
          bmiScore = 5.0;
        } else {
          bmiScore = 2.0; // Obese
        }
      }
    } catch (e) {
      debugPrint("Error calculating BMI score: \$e");
    }

    totalScore =
        physicalScore +
        sleepScore +
        nutritionScore +
        mentalScore +
        medicalScore +
        bmiScore;

    // Minimum fallback to prevent 0 if no data
    if (totalScore == 0.0) {
      totalScore =
          65.0; // Give an average baseline if literally nothing is registered yet
    }

    totalScore = totalScore.clamp(0.0, 100.0);

    overallHealthScore.value = totalScore;
    ratingOutOf10.value = double.parse((totalScore / 10.0).toStringAsFixed(1));

    _updateCategoryAndQuote(totalScore);
  }

  void _updateCategoryAndQuote(double score) {
    if (score >= 90) {
      healthCategory.value = 'Excellent';
      healthQuote.value =
          'Keep up the fantastic work! Your lifestyle is perfectly balanced.';
    } else if (score >= 75) {
      healthCategory.value = 'Good';
      healthQuote.value =
          'You are doing great! A few tweaks can make you even better.';
    } else if (score >= 60) {
      healthCategory.value = 'Average';
      healthQuote.value =
          'You are on the right track, but there is room for improvement.';
    } else if (score >= 40) {
      healthCategory.value = 'Needs Attention';
      healthQuote.value =
          'It is time to focus on your health. Start with small, consistent changes.';
    } else {
      healthCategory.value = 'High Risk';
      healthQuote.value =
          'Please consult a healthcare professional and prioritize your well-being immediately.';
    }
  }
}
