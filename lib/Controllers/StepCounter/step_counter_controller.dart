import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'package:snevva/env/env.dart';
import 'package:snevva/models/queryParamViewModels/step_goal_vm.dart';
import 'package:snevva/services/api_service.dart';
import '../../consts/consts.dart';

class StepCounterController extends GetxController {
  RxInt stepsgoals = 0.obs;
  RxInt todaySteps = 0.obs;

  SharedPreferences? _prefs;

  @override
  void onInit() {
    super.onInit();
    _initPrefs();
  }

  /// Initialize SharedPreferences and load saved steps & goal
  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    loadTodaySteps();
    loadStepGoal();
  }

  /// Save today's step count locally
  Future<void> savetodayStepsLocally() async {
    if (_prefs == null) return;
    await _prefs!.setInt('todaySteps', todaySteps.value);
    print('👣 Today steps saved locally: ${todaySteps.value}');
  }

  /// Load today's step count from local storage
  void loadTodaySteps() {
    todaySteps.value = _prefs?.getInt('todaySteps') ?? 0;
  }

  /// Load step goal from local storage (default 8500)
  void loadStepGoal() {
    stepsgoals.value = _prefs?.getInt('step_goal') ?? 8500;
  }

  /// Update step goal both locally and remotely
  Future<void> updateStepGoal(int goal) async {
    stepsgoals.value = goal;
    stepsgoals.refresh();

    // Save locally
    await _prefs?.setInt('step_goal', goal);

    // Save remotely
    final stepGoalVM = StepGoalVM(
      day: DateTime.now().day,
      month: DateTime.now().month,
      year: DateTime.now().year,
      time: TimeOfDay.now().format(Get.context!),
      count: goal,
    );

    await _saveStepGoal(stepGoalVM);
  }

  /// API call to save step goal remotely
  Future<void> _saveStepGoal(StepGoalVM stepModel) async {
    try {
      final payload = {
        'Day': stepModel.day,
        'Month': stepModel.month,
        'Year': stepModel.year,
        'Time': stepModel.time,
        'Count': stepModel.count,
      };

      final response = await ApiService.post(
        stepGoal,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response) {
        print('Error ❌ Failed to save step goal: ${response.statusCode}');
        return;
      }

      print("✅ Step goal saved successfully: $response");
    } catch (e) {
      print('Error❌ Exception while saving step goal');
    }
  }

  /// Save step record both locally and remotely
  Future<void> saveStepRecord(int count) async {
    try {
      final now = DateTime.now();
      final payload = {
        "Day": now.day,
        "Month": now.month,
        "Year": now.year,
        "Time": TimeOfDay.now().format(Get.context!),
        "Count": count,
      };

      todaySteps.value = count;
      await savetodayStepsLocally();

      final response = await ApiService.post(
        stepRecord,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response && response.statusCode >= 400) {
        print('Error ❌ Failed to save step record: ${response.statusCode}');
      } else {
        print('✅ Step record saved successfully');
      }
    } catch (e) {
      print('Error ❌ Exception while saving step record');
    }
  }
}
