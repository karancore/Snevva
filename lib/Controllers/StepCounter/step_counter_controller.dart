
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:snevva/common/custom_snackbar.dart';
import 'package:snevva/env/env.dart';

import 'package:snevva/models/steps_model.dart';
import 'package:snevva/models/queryParamViewModels/step_goal_vm.dart';
import 'package:snevva/services/api_service.dart';
import 'package:snevva/consts/consts.dart';

import '../../common/global_variables.dart';

class StepCounterController extends GetxController {
  // =======================
  // OBSERVABLE STATE
  // =======================
  RxInt todaySteps = 0.obs;
  RxInt stepGoal = 8000.obs;

  // final FlutterBackgroundService _service = FlutterBackgroundService();

  int lastSteps = 0;
  final RxList<FlSpot> stepSpots = <FlSpot>[].obs;
  final RxMap<String, int> stepsHistoryByDate = <String, int>{}.obs;
  RxList<StepEntry> stepsHistoryList = <StepEntry>[].obs;
  double lastPercent = 0.0;

  late Box<StepEntry> _stepBox;
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
    _prefs = await SharedPreferences.getInstance();
    _stepBox = Hive.box<StepEntry>('step_history');

    _checkDayReset();

    await loadGoal();
    await loadTodayStepsFromHive();

    // Start listening AFTER loading initial data
    // _listenToBackgroundSteps();
  }

  // =======================
  // DAY RESET
  // =======================
  void _checkDayReset() {
    final now = DateTime.now();
    final todayKey = _dayKey(now);
    final lastDate = _prefs.getString("last_step_date");

    if (lastDate != todayKey) {
      todaySteps.value = 0;
      lastSteps = 0;
      lastPercent = 0.0;

      _prefs.setString("last_step_date", todayKey);
      _saveToHive(0);
    }
  }

  // =======================
  // LISTEN TO BACKGROUND SERVICE
  // =======================
  // void _listenToBackgroundSteps() {
  //   _service.on("steps_updated").listen((event) {
  //     if (event == null) return;

  //     final int newSteps = event["steps"] ?? 0;

  //     // Only update if steps actually increased
  //     if (newSteps <= todaySteps.value) return;

  //     // Store last value for animation
  //     lastSteps = todaySteps.value;
  //     lastPercent = _currentPercent;

  //     // Update reactive value
  //     todaySteps.value = newSteps;

  //     // Trigger API sync if needed
  //     _maybeSyncSteps();

  //     print("🔄 Controller received: $newSteps steps");
  //   });
  // }

  // =======================
  // STEP UPDATES (MANUAL - if needed)
  // =======================

  /// Manual update (use only if you have direct step data, not from service)
  void updateSteps(int newSteps) {
    if (newSteps <= todaySteps.value) return;

    lastSteps = todaySteps.value;
    lastPercent = _currentPercent;

    todaySteps.value = newSteps;

    _saveToHive(todaySteps.value);
    _maybeSyncSteps();
  }

  double get _currentPercent =>
      stepGoal.value == 0 ? 0.0 : todaySteps.value / stepGoal.value;

  // =======================
  // HIVE
  // =======================
  void _saveToHive(int steps) {
    final today = DateTime.now();
    final key = _dayKey(today);

    todaySteps.value = steps; // Ensure reactive variable is up to date
    // If not updating directly via binding

    _stepBox.put(key, StepEntry(date: _startOfDay(today), steps: steps));

    // Update graph immediately
    updateStepSpots();
  }

  Future<void> loadTodayStepsFromHive() async {
    final todayKey = _dayKey(DateTime.now());
    final entry = _stepBox.get(todayKey);

    final steps = entry?.steps ?? 0;

    todaySteps.value = steps;
    lastSteps = steps;
    lastPercent = _currentPercent;

    print("📊 Loaded from Hive: $steps steps");

    // Refresh graph with loaded data
    updateStepSpots();
  }

  Future<void> loadStepsfromAPI({required int month, required int year}) async {
    try {
      final payload = {"Month": month, "Year": year};

      final response = await ApiService.post(
        fetchStepsHistory,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      // ❌ API returned HTTP error
      if (response is http.Response) {
        CustomSnackbar.showError(
          context: Get.context!,
          title: 'Error',
          message: 'Failed to fetch step data: ${response.statusCode}',
        );
        return;
      }

      // ✅ SUCCESS → already decrypted Map
      final Map<String, dynamic> decoded = response as Map<String, dynamic>;

      final List<dynamic> stepData = decoded['data']?['StepData'] ?? [];

      print("🔄 Fetched step data from API: $stepData");

      stepsHistoryList.clear();

      for (final item in stepData) {
        final date = DateTime(item['Year'], item['Month'], item['Day']);

        stepsHistoryList.add(StepEntry(date: date, steps: item['Count'] ?? 0));
      }

      // ✅ Step goal
      stepGoal.value =
          decoded['data']?['StepGoalData']?['Count'] ?? stepGoal.value;

      // ✅ Build map + graph
      buildStepsHistoryMap();

      print("📊 Map: $stepsHistoryByDate");
      print("📈 Spots: $stepSpots");
      print("✅ Loaded steps from API: ${stepsHistoryList.length}");
    } catch (e) {
      print("❌ Error loading steps from API: $e");
    }
  }

  // =======================
  // DATE HELPERS
  // =======================
  String _dayKey(DateTime d) => "${d.year}-${d.month}-${d.day}";
  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  // =======================
  // STEP GOAL
  // =======================
  Future<void> loadGoal() async {
    stepGoal.value = _prefs.getInt("step_goal") ?? 8000;
  }

  Future<void> saveGoal(int goal) async {
    stepGoal.value = goal;
    await _prefs.setInt("step_goal", goal);
  }

  List<FlSpot> getMonthlyStepsSpots(DateTime month) {
    int totalDays = daysInMonth(month.year, month.month);
    List<FlSpot> spots = [];

    for (int day = 1; day <= totalDays; day++) {
      final key = "${month.year}-${month.month}-$day";
      final steps = stepsHistoryByDate[key] ?? 0;

      spots.add(FlSpot((day - 1).toDouble(), double.parse(steps.toString())));
    }

    return spots;
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

  // =======================
  // API
  // =======================
  Future<void> _saveStepGoalRemote(StepGoalVM model) async {
    try {
      final payload = {
        "Day": model.day,
        "Month": model.month,
        "Year": model.year,
        "Time": model.time,
        "Count": model.count,
      };

      await ApiService.post(
        savestepGoal,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      print("✅ Step goal synced");
    } catch (_) {
      print("❌ Step goal sync failed");
    }
  }

  /// 🔁 Sync every 500 steps (LIVE)
  void _maybeSyncSteps() {
    if (todaySteps.value % 500 == 0 && todaySteps.value > 0) {
      saveStepRecordToServer();
    }
  }

  Future<void> saveStepRecordToServer() async {
    try {
      final now = DateTime.now();
      final date = DateUtils.dateOnly(DateTime.now());

      final payload = {
        "Day": now.day,
        "Month": now.month,
        "Year": now.year,
        "Time": TimeOfDay.now().format(Get.context!),
        "Count": todaySteps.value,
      };

      final newRecord = StepEntry(date: date, steps: todaySteps.value);
      stepsHistoryList.add(newRecord);
      buildStepsHistoryMap();

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

  void buildStepsHistoryMap() {
    stepsHistoryByDate.clear();
    for (final item in stepsHistoryList) {
      final key = "${item.date.year}-${item.date.month}-${item.date.day}";
      stepsHistoryByDate.update(
        key,
        (v) => v + item.steps,
        ifAbsent: () => item.steps ?? 0,
      );
    }
    syncTodayIntakeFromMap();
    updateStepSpots();
  }

  void syncTodayIntakeFromMap() {
    final key = DateFormat('yyyy-MM-dd').format(DateTime.now());
    todaySteps.value = (stepsHistoryByDate[key] ?? 0).toInt();
  }

  void updateStepSpots() {
    stepSpots.clear();
    DateTime now = DateTime.now();
    // Monday = 1, Sunday = 7. Find Monday of current week.
    DateTime monday = now.subtract(Duration(days: now.weekday - 1));

    for (int i = 0; i < 7; i++) {
      DateTime date = monday.add(Duration(days: i));
      String key = _dayKey(date);

      // Use map value if present, otherwise fallback to Hive (local source of truth)
      // This ensures if map is empty (app restart), we still get data for graph
      int steps = stepsHistoryByDate[key] ?? _stepBox.get(key)?.steps ?? 0;

      // Update map to keep it in sync for other usages
      stepsHistoryByDate[key] = steps;

      stepSpots.add(FlSpot(i.toDouble(), steps / 1000.0));
    }
  }
}
