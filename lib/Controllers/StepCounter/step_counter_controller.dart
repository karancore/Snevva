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

  static const String _stepsKey = "today_steps";
  static const String _dateKey = "last_step_date";


  @override
  void onInit() {
    super.onInit();
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    await _checkAndResetIfNewDay();
    await loadGoal();
    await _loadTodaySteps();
  }


  String _todayKey() {
    final now = DateTime.now();
    return "${now.year}-${now.month}-${now.day}";
  }

  Future<void> _checkAndResetIfNewDay() async {
    if (_prefs == null) return;

    final storedDate = _prefs!.getString(_dateKey);
    final today = _todayKey();

    if (storedDate != today) {
      // 🔥 New day → reset
      await _prefs!.setString(_dateKey, today);
      await _prefs!.setInt(_stepsKey, 0);
      todaySteps.value = 0;
    }
  }


  Future<void> _loadTodaySteps() async {
    if (_prefs == null) return;
    todaySteps.value = _prefs!.getInt(_stepsKey) ?? 0;
  }

  /// Called by background service / pedometer
  Future<void> addSteps(int delta) async {
    if (_prefs == null) return;

    await _checkAndResetIfNewDay();

    final updated = todaySteps.value + delta;
    todaySteps.value = updated;
    await _prefs!.setInt(_stepsKey, updated);
  }

  Future<void> setSteps(int value) async {
    if (_prefs == null) return;

    todaySteps.value = value;
    await _prefs!.setInt(_stepsKey, value);
  }


  Future<void> saveGoal(int goal) async {
    if (_prefs == null) return;
    stepGoal.value = goal;
    await _prefs!.setInt("step_goal", goal);
  }

  Future<void> loadGoal() async {
    if (_prefs == null) return;
    stepGoal.value = _prefs!.getInt("step_goal") ?? 8000;
  }


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
        print('❌ Failed to save step goal: ${response.statusCode}');
        return;
      }

      print("✅ Step goal saved successfully");
    } catch (e) {
      print('❌ Exception while saving step goal');
    }
  }


  Future<void> saveStepRecord() async {
    try {
      final now = DateTime.now();

      final payload = {
        "Day": now.day,
        "Month": now.month,
        "Year": now.year,
        "Time": TimeOfDay.now().format(Get.context!),
        "Count": todaySteps.value,
      };

      final response = await ApiService.post(
        stepRecord,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response && response.statusCode >= 400) {
        print('❌ Failed to save step record: ${response.statusCode}');
      } else {
        print("✅ Step record saved successfully!");
      }
    } catch (e) {
      print('❌ Exception while saving step record');
    }
  }
}
