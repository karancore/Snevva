import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:snevva/env/env.dart';

import 'package:snevva/models/steps_model.dart';
import 'package:snevva/models/queryParamViewModels/step_goal_vm.dart';
import 'package:snevva/services/api_service.dart';
import 'package:snevva/consts/consts.dart';

class StepCounterController extends GetxController {
  // =======================
  // OBSERVABLE STATE
  // =======================
  final RxInt todaySteps = 0.obs;
  final RxInt stepGoal = 8000.obs;

  int lastSteps = 0;
  double lastPercent = 0;

  // late final Box<StepEntry> _stepBox;
  
  late  Box<StepEntry> _stepBox;
  late SharedPreferences _prefs;


  // =======================
  // INIT
  // =======================
  @override
  void onInit() {
    super.onInit();
    _init();
  }

  Future<void> _init() async {
  _prefs = await SharedPreferences.getInstance(); // ✅ FIRST
  _stepBox = Hive.box<StepEntry>('step_history');

  _checkDayReset(); // ✅ now safe

    await loadGoal();
    await loadTodayStepsFromHive();
    if (todaySteps.value % 500 == 0) {
      saveStepRecordToServer();
    }
  }

  void _checkDayReset() {
    final now = DateTime.now();
    final lastDate = _prefs.getString("last_step_date");

    final todayKey = _dayKey(now);

    if (lastDate != todayKey) {
      todaySteps.value = 0;
      lastSteps = 0;
      lastPercent = 0;
      _prefs.setString("last_step_date", todayKey);
      _saveToHive(0);
    }
  }

  //  void updateSteps(int newSteps) {
  //     if (newSteps == todaySteps.value) return;

  //     // Preserve animation baseline
  //     lastSteps = todaySteps.value;

  //     todaySteps.value = newSteps; // 🔥 instant UI
  //     _saveToHive(newSteps);
  //   }

  //   /// Called by background pedometer
  //   void incrementSteps(int delta) {
  //     if (delta <= 0) return;
  //     updateSteps(todaySteps.value + delta);
  //   }

  /// Called by background pedometer
  void incrementSteps(int delta) {
    if (delta <= 0) return;

    lastSteps = todaySteps.value;
    todaySteps.value += delta;
    _saveToHive(todaySteps.value);
  }

  // =======================
  // HIVE PERSISTENCE
  // =======================
  void _saveToHive(int steps) {
    final today = DateTime.now();
    final key = _dayKey(today);

    _stepBox.put(key, StepEntry(date: _startOfDay(today), steps: steps));
  }

  Future<void> loadTodayStepsFromHive() async {
    final todayKey = _dayKey(DateTime.now());
    final entry = _stepBox.get(todayKey);
    todaySteps.value = entry?.steps ?? 0;
  }

  // =======================
  // DATE HELPERS
  // =======================
  String _dayKey(DateTime d) => "${d.year}-${d.month}-${d.day}";

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  // =======================
  // STEP GOAL (SharedPrefs)
  // =======================
  Future<void> loadGoal() async {
    stepGoal.value = _prefs.getInt("step_goal") ?? 8000;
  }

  Future<void> saveGoal(int goal) async {
    stepGoal.value = goal;
    await _prefs.setInt("step_goal", goal);
  }

  // =======================
  // UPDATE GOAL (LOCAL + API)
  // =======================
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

      if (response is http.Response && response.statusCode >= 400) {
        print("❌ Step goal save failed");
        return;
      }

      print("✅ Step goal synced");
    } catch (_) {
      print("❌ Step goal sync exception");
    }
  }

  // =======================
  // DAILY RECORD SYNC (API)
  // =======================
  Future<void> saveStepRecordToServer() async {
    try {
      final now = DateTime.now();

      final payload = {
        "Day": now.day,
        "Month": now.month,
        "Year": now.year,
        "Time": TimeOfDay.now().format(Get.context!),
        "Count": todaySteps.value,
      };

      await ApiService.post(
        stepRecord,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      print("✅ Daily step record synced");
    } catch (_) {
      print("❌ Step record sync failed");
    }
  }
}
