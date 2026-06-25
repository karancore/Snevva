import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../Controllers/Hydration/hydration_stat_controller.dart';
import '../../Controllers/MoodTracker/mood_controller.dart';
import '../../Controllers/SleepScreen/sleep_controller.dart';
import '../../Controllers/StepCounter/step_counter_controller.dart';
import '../../Controllers/dashboard/health_score_controller.dart';

class HealthSummaryDialogHelper {
  static void show(BuildContext context, bool isDarkMode) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Health Summary',
      barrierColor: Colors.black.withOpacity(0.65),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => HealthSummaryDialog(isDarkMode: isDarkMode),
      transitionBuilder:
          (_, anim, __, child) => ScaleTransition(
            scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            child: FadeTransition(opacity: anim, child: child),
          ),
    );
  }
}

class HealthSummaryDialog extends StatelessWidget {
  final bool isDarkMode;

  const HealthSummaryDialog({Key? key, required this.isDarkMode})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HealthScoreController>();
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final scale = w / 400.0; // scale factor for responsiveness

    DateTime yesterday = DateTime.now().subtract(const Duration(days: 1));
    String formattedDate = DateFormat('MMMM d, yyyy').format(yesterday);

    // Attempt to grab actual data for UI realism
    int waterCurrent = 0, waterGoal = 2000;
    int stepCurrent = 0, stepGoal = 8000;
    int sleepMins = 0, sleepGoalMins = 480;
    String moodCurrent = 'Good';

    if (Get.isRegistered<HydrationStatController>()) {
      final h = Get.find<HydrationStatController>();
      String key = "${yesterday.year}-${yesterday.month}-${yesterday.day}";
      waterCurrent = h.waterHistoryByDate[key] ?? 0;
      waterGoal = h.waterGoal.value > 0 ? h.waterGoal.value : 2000;
    }

    if (Get.isRegistered<StepCounterController>()) {
      final s = Get.find<StepCounterController>();
      String key =
          "${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";
      stepCurrent = s.stepsHistoryByDate[key] ?? 0;
      stepGoal = s.stepGoal.value > 0 ? s.stepGoal.value : 8000;
    }

    if (Get.isRegistered<SleepController>()) {
      final sl = Get.find<SleepController>();
      String key =
          "${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";
      Duration? d = sl.weeklySleepHistory[key];
      if (d != null) sleepMins = d.inMinutes;
      sleepGoalMins =
          sl.sleepGoal.value.inMinutes > 0 ? sl.sleepGoal.value.inMinutes : 480;
    }

    if (Get.isRegistered<MoodController>()) {
      final m = Get.find<MoodController>();
      moodCurrent =
          m.selectedMood.value.isNotEmpty ? m.selectedMood.value : 'Good';
    }

    double waterPct = (waterCurrent / waterGoal).clamp(0.0, 1.0);
    double stepPct = (stepCurrent / stepGoal).clamp(0.0, 1.0);
    double sleepPct = (sleepMins / sleepGoalMins).clamp(0.0, 1.0);
    double moodPct =
        moodCurrent == 'Pleasant' || moodCurrent == 'Good'
            ? 1.0
            : (moodCurrent == 'Unpleasant' ? 0.3 : 0.8);

    bool isConsistent = controller.overallHealthScore.value >= 70;

    String dynamicInsight = "";
    String dynamicFocusTitle = "Focus for today";
    String dynamicFocusContent = "";
    IconData dynamicFocusIcon = Icons.track_changes_rounded;
    Color dynamicFocusColor = Colors.blue;

    if (waterCurrent == 0 && stepCurrent == 0 && sleepMins == 0) {
      dynamicInsight =
      "It looks like you didn't log many metrics yesterday. Tracking your habits is the first step to improving them!";
      dynamicFocusContent =
      "Try logging your water intake and steps today. Every little bit counts.";
      dynamicFocusIcon = Icons.assignment_rounded;
      dynamicFocusColor = Colors.blue;
    } else if (waterCurrent == 0) {
      dynamicInsight =
      "You didn't log any water yesterday. Staying hydrated is crucial for your overall health and energy levels.";
      dynamicFocusContent =
      "Focus on drinking at least a few glasses of water today.";
      dynamicFocusIcon = Icons.water_drop_rounded;
      dynamicFocusColor = Colors.blue;
    } else if (stepCurrent == 0) {
      dynamicInsight =
      "No steps were recorded yesterday. Movement helps keep your body and mind feeling fresh.";
      dynamicFocusContent =
      "Try to take a short 10-minute walk today to get your body moving.";
      dynamicFocusIcon = Icons.directions_run_rounded;
      dynamicFocusColor = Colors.green;
    } else if (sleepMins == 0) {
      dynamicInsight =
      "You didn't log your sleep last night. Tracking sleep helps you understand your energy patterns.";
      dynamicFocusContent =
      "Remember to log your sleep tonight so we can help you rest better.";
      dynamicFocusIcon = Icons.nights_stay_rounded;
      dynamicFocusColor = Colors.deepPurple;
    } else {
      Map<String, double> metrics = {
        'water': waterPct,
        'steps': stepPct,
        'sleep': sleepPct,
      };
      var lowestMetric = metrics.entries.reduce((a, b) =>
      a.value < b.value
          ? a
          : b);

      if (lowestMetric.value >= 0.8) {
        dynamicInsight =
        "You are doing amazing! All your metrics from yesterday were excellent. Keep it up!";
        dynamicFocusTitle = "What went well";
        dynamicFocusContent =
        "Great sleep, hydration, and activity! You're building strong healthy habits.";
        dynamicFocusIcon = Icons.check_circle_outline_rounded;
        dynamicFocusColor = Colors.green;
      } else {
        if (lowestMetric.key == 'water') {
          dynamicInsight =
          "You missed your hydration goal yesterday. Drinking water consistently improves energy levels!";
          dynamicFocusContent =
          "Try carrying a water bottle today to remind yourself to drink more.";
          dynamicFocusIcon = Icons.water_drop_rounded;
          dynamicFocusColor = Colors.blue;
        } else if (lowestMetric.key == 'steps') {
          dynamicInsight =
          "Your step count was a bit low yesterday. A short walk can do wonders for your mood and health.";
          dynamicFocusContent =
          "Try taking a 15-minute walk during your break today to get those steps in!";
          dynamicFocusIcon = Icons.directions_run_rounded;
          dynamicFocusColor = Colors.green;
        } else if (lowestMetric.key == 'sleep') {
          dynamicInsight =
          "You didn't get enough sleep yesterday. Lack of sleep can impact your recovery and focus.";
          dynamicFocusContent =
          "Try going to bed 30 minutes earlier tonight to get better rest.";
          dynamicFocusIcon = Icons.nights_stay_rounded;
          dynamicFocusColor = Colors.deepPurple;
        }
      }
    }

    Color bgColor = isDarkMode ? const Color(0xFF2C2C2E) : Colors.white;
    Color textColor = isDarkMode ? Colors.white : const Color(0xFF1C1C1E);
    Color textSubColor = isDarkMode ? Colors.white70 : const Color(0xFF8E8E93);
    Color primaryPurple = const Color(0xFFA95BFF);

    final hour = DateTime
        .now()
        .hour;
    final greeting = hour < 12
        ? "Good Morning"
        : hour < 17
        ? "Good Afternoon"
        : "Good Evening";

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
            width: w * 0.92,
            constraints: BoxConstraints(maxHeight: size.height * 0.85),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.all(24 * scale),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        greeting,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 22 * scale,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      SizedBox(width: 8 * scale),
                      Text(
                        hour < 12 ? "☀️" : hour < 17 ? "🌤️" : "🌙",
                        style: TextStyle(fontSize: 22 * scale),
                      ),
                    ],
                  ),
                  SizedBox(height: 6 * scale),
                  Text(
                    "Here's how yesterday went",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14 * scale,
                      color: textSubColor,
                    ),
                  ),
                  SizedBox(height: 36 * scale),

                  // Hero Health Score (Semi-Circular Arc)
                  _buildHeroScore(scale, controller.overallHealthScore.value,
                      controller.healthCategory.value, isDarkMode, textColor,
                      textSubColor),

                  SizedBox(height: 36 * scale),

                  // Metrics Section (Compact Pills)
                  Wrap(
                    spacing: 12 * scale,
                    runSpacing: 12 * scale,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildMetricPill(
                          scale,
                          Icons.water_drop_rounded,
                          Colors.blue,
                          "Water",
                          "${(waterCurrent / 1000).toStringAsFixed(1)}L",
                          waterPct,
                          isDarkMode),
                      _buildMetricPill(
                          scale,
                          Icons.directions_run_rounded,
                          Colors.green,
                          "Steps",
                          NumberFormat('#,###').format(stepCurrent),
                          stepPct,
                          isDarkMode),
                      _buildMetricPill(
                          scale,
                          Icons.nights_stay_rounded,
                          Colors.deepPurple,
                          "Sleep",
                          "${sleepMins ~/ 60}h ${sleepMins % 60}m",
                          sleepPct,
                          isDarkMode),
                      _buildMetricPill(
                          scale,
                          Icons.sentiment_satisfied_rounded,
                          Colors.orange,
                          "Mood",
                          moodCurrent,
                          moodPct,
                          isDarkMode),
                    ],
                  ),

                  SizedBox(height: 24 * scale),

                  // AI Insight Section
                  _buildInsightCard(scale, isDarkMode, primaryPurple, textColor,
                      dynamicInsight),

                  SizedBox(height: 16 * scale),

                  // Achievement Section (Focus / Went Well)
                  _buildAchievementCard(
                      scale,
                      isDarkMode,
                      dynamicFocusTitle,
                      dynamicFocusContent,
                      dynamicFocusIcon,
                      dynamicFocusColor,
                      textColor),

                ],
              ),
            ),
          ),
        ),
    );
  }

  Widget _buildHeroScore(double scale, double score, String category,
      bool isDarkMode, Color textColor, Color subColor) {
    Color scoreColor;
    if (score >= 80)
      scoreColor = Colors.green;
    else if (score >= 60)
      scoreColor = Colors.orange;
    else
      scoreColor = Colors.red;

    return Column(
      children: [
        SizedBox(
          width: 180 * scale,
          height: 90 * scale, // Half height for semi-circle roughly
          child: CustomPaint(
            painter: HealthScoreArcPainter(
              progress: score / 100.0,
              backgroundColor: isDarkMode ? Colors.white10 : Colors.grey
                  .withOpacity(0.15),
              progressColor: scoreColor,
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "${score.toInt()}",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 48 * scale,
                      fontWeight: FontWeight.w800,
                      color: scoreColor,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    "out of 100",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12 * scale,
                      color: subColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: 16 * scale),
        Container(
          padding: EdgeInsets.symmetric(
              horizontal: 16 * scale, vertical: 6 * scale),
          decoration: BoxDecoration(
            color: scoreColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            category,
            style: TextStyle(
              fontFamily: 'Inter',
              color: scoreColor,
              fontWeight: FontWeight.bold,
              fontSize: 14 * scale,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricPill(double scale, IconData icon, Color color,
      String title, String value, double progress, bool isDarkMode) {
    // Roughly half width minus spacing
    double w = 140 * scale;

    return Container(
      width: w,
      padding: EdgeInsets.all(12 * scale),
      decoration: BoxDecoration(
        color: isDarkMode ? color.withOpacity(0.1) : color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18 * scale),
              SizedBox(width: 6 * scale),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12 * scale,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 8 * scale),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16 * scale,
              color: isDarkMode ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8 * scale),
          Container(
            height: 4 * scale,
            width: double.infinity,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(double scale, bool isDarkMode, Color primaryColor,
      Color textColor, String insightText) {
    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: isDarkMode ? primaryColor.withOpacity(0.15) : primaryColor
            .withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8 * scale),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_awesome_rounded, color: primaryColor,
                size: 20 * scale),
          ),
          SizedBox(width: 12 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Snevva Insight",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12 * scale,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                SizedBox(height: 4 * scale),
                Text(
                  insightText,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13 * scale,
                    color: textColor,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementCard(double scale, bool isDarkMode, String title,
      String content, IconData icon, Color iconColor, Color textColor) {
    Color cardColor = isDarkMode ? iconColor.withOpacity(0.15) : iconColor
        .withOpacity(0.05);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18 * scale),
              SizedBox(width: 8 * scale),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13 * scale,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 6 * scale),
          Text(
            content,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12 * scale,
              color: isDarkMode ? Colors.white70 : Colors.black87,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class HealthScoreArcPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color progressColor;

  HealthScoreArcPainter({
    required this.progress,
    required this.backgroundColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = progressColor
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw background arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi, // Start angle (180 degrees)
      pi, // Sweep angle (180 degrees)
      false,
      bgPaint,
    );

    // Draw progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi, // Start angle (180 degrees)
      pi * progress, // Sweep angle
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant HealthScoreArcPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.progressColor != progressColor;
  }
}
