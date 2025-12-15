import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'package:snevva/models/queryParamViewModels/step_goal_vm.dart';
import 'package:snevva/services/api_service.dart';
import 'package:snevva/env/env.dart';
import 'package:snevva/consts/consts.dart';

class StepCounterController extends GetxController {
  RxInt stepGoal = 8000.obs;
  RxInt todaySteps = 0.obs;

  SharedPreferences? _prefs;

  @override
  void onInit() {
    super.onInit();
    _initPrefs();
  }

  // ================================================================
  // INIT
  // ================================================================

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    await loadGoal();
    await loadTodaySteps();
  }

  // ================================================================
  // TODAY STEPS (from background isolate)
  // ================================================================

  Future<void> loadTodaySteps() async {
    if (_prefs == null) return;
    todaySteps.value = _prefs!.getInt("todaySteps") ?? 0;
  }

  Future<void> saveTodaySteps(int value) async {
    if (_prefs == null) return;
    todaySteps.value = value;
    await _prefs!.setInt("todaySteps", value);
  }

  // ================================================================
  // STEP GOAL
  // ================================================================

  Future<void> saveGoal(int goal) async {
    if (_prefs == null) return;
    stepGoal.value = goal;
    await _prefs!.setInt("step_goal", goal);
  }

  Future<void> loadGoal() async {
    if (_prefs == null) return;
    stepGoal.value = _prefs!.getInt("step_goal") ?? 8000;
  }

  // ================================================================
  // UPDATE GOAL (local + server)
  // ================================================================

  Future<void> updateStepGoal(int goal) async {
    await saveGoal(goal);

    final model = StepGoalVM(
      day: DateTime.now().day,
      month: DateTime.now().month,
      year: DateTime.now().year,
      time: TimeOfDay.now().format(Get.context!),
      count: goal,
    );

    await _saveStepGoalRemote(model);
  }

  Future<void> _saveStepGoalRemote(StepGoalVM model) async {
    try {
      final payload = {
        "Day": model.day,
        "Month": model.month,
        "Year": model.year,
        "Time": model.time,
        "Count": model.count,
      };

      final response = await ApiService.post(
        savestepGoal,
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

  // ================================================================
  // SAVE DAILY STEP RECORD (server)
  // ================================================================

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

      final response = await ApiService.post(
        stepRecord,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response && response.statusCode >= 400) {
        print('Error ❌ Failed to save step record: ${response.statusCode}');
      } else {
        print("✅ Step record saved successfully!");
      }
    } catch (e) {
      print('Error ❌ Exception while saving step record');
    }
  }
}
