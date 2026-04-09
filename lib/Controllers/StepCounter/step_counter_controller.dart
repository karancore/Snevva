import 'dart:async';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/common/custom_snackbar.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/env/env.dart';
import 'package:snevva/models/queryParamViewModels/step_goal_vm.dart';
import 'package:snevva/services/api_service.dart';
import 'package:snevva/services/file_storage_service.dart';
import 'package:snevva/services/tracking_service_manager.dart';

class StepCounterController extends GetxController {
  RxInt todaySteps = 0.obs;
  RxInt stepGoal = 8000.obs;

  int lastSteps = 0;
  RxInt lastStepsRx = 0.obs;
  final RxList<FlSpot> stepSpots = <FlSpot>[].obs;
  final RxMap<String, int> stepsHistoryByDate = <String, int>{}.obs;
  final RxList<_StepEntry> _stepsHistoryList = <_StepEntry>[].obs;
  double lastPercent = 0.0;

  final Map<String, List<FlSpot>> _monthlySpotsCache = <String, List<FlSpot>>{};

  late SharedPreferences _prefs;
  Timer? _refreshTimer;
  StreamSubscription<int>? _nativeStepUpdatesSubscription;
  int _trackingClients = 0;

  @override
  Future<void> onInit() async {
    super.onInit();
    _prefs = await SharedPreferences.getInstance();
    await loadGoal();
    await loadRecentStepsData();
    await loadTodaySteps();
  }

  Future<void> startTracking() async {
    _trackingClients++;
    await TrackingServiceManager.instance.startStepService();
    _nativeStepUpdatesSubscription ??=
        TrackingServiceManager.instance.watchTodaySteps().listen(
          _applyNativeSteps,
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('Native step updates stream error: $error');
          },
        );
    _refreshTimer ??= Timer.periodic(const Duration(seconds: 15), (_) {
      loadTodaySteps();
    });
    await loadTodaySteps();
  }

  void stopTracking() {
    if (_trackingClients > 0) {
      _trackingClients--;
    }
    if (_trackingClients > 0) return;

    _refreshTimer?.cancel();
    _refreshTimer = null;
    _nativeStepUpdatesSubscription?.cancel();
    _nativeStepUpdatesSubscription = null;
  }

  Future<void> loadTodaySteps() async {
    final nativeSteps = await TrackingServiceManager.instance.getTodaySteps();
    _applyNativeSteps(nativeSteps);
  }

  Future<void> _applyNativeSteps(int nativeSteps) async {
    final previous = todaySteps.value;

    if (nativeSteps == previous) {
      _mergeTodayIntoHistory();
      await updateStepSpots();
      return;
    }

    lastSteps = previous;
    lastStepsRx.value = previous;
    lastPercent = stepGoal.value == 0 ? 0.0 : previous / stepGoal.value;

    todaySteps.value = nativeSteps;
    todaySteps.refresh();

    _mergeTodayIntoHistory();
    _invalidateMonthlySpotsCache(month: DateTime.now());
    await updateStepSpots();
  }

  @override
  void onClose() {
    _trackingClients = 0;
    stopTracking();
    super.onClose();
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

      if (response is http.Response) {
        CustomSnackbar.showError(
          context: Get.context!,
          title: 'Error',
          message: 'Failed to fetch step data: ${response.statusCode}',
        );
        return;
      }

      final Map<String, dynamic> decoded = response as Map<String, dynamic>;
      final List<dynamic> stepData = decoded['data']?['StepData'] ?? [];

      _stepsHistoryList.clear();

      for (final item in stepData) {
        final date = DateTime(item['Year'], item['Month'], item['Day']);
        final apiCount = (item['Count'] ?? 0) as int;
        _stepsHistoryList.add(_StepEntry(date: date, steps: apiCount));
        await FileStorageService().writeStepTotal(_dayKey(date), apiCount);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isStepGoalSet', true);

      stepGoal.value =
          decoded['data']?['StepGoalData']?['Count'] ?? stepGoal.value;

      await buildStepsHistoryMap();
      await loadTodaySteps();

      _invalidateMonthlySpotsCache(month: DateTime(year, month));
      _debugLog(
          "Loaded ${_stepsHistoryList.length} step history rows from API");
    } catch (e) {
      debugPrint("Error loading step history: $e");
    }
  }

  Future<void> loadGoal() async {
    stepGoal.value = _prefs.getInt("step_goal") ?? 8000;
  }

  Future<void> saveGoal(int goal) async {
    stepGoal.value = goal;
    await _prefs.setInt("step_goal", goal);
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

      await ApiService.post(
        savestepGoal,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      debugPrint("Step goal synced");
    } catch (_) {
      debugPrint("Step goal sync failed");
    }
  }

  Future<void> buildStepsHistoryMap() async {
    stepsHistoryByDate.clear();
    _invalidateMonthlySpotsCache();

    for (final item in _stepsHistoryList) {
      final key = _dayKey(item.date);
      final existing = stepsHistoryByDate[key] ?? 0;
      if (item.steps > existing) {
        stepsHistoryByDate[key] = item.steps;
      }
    }

    await _mergeRecentLocalStepsIntoHistory();
    _mergeTodayIntoHistory();
    await updateStepSpots();
  }

  Future<void> loadRecentStepsData() async {
    stepsHistoryByDate.clear();
    await _mergeRecentLocalStepsIntoHistory();
    _mergeTodayIntoHistory();
    _invalidateMonthlySpotsCache(month: DateTime.now());
    await updateStepSpots();
  }

  Future<void> updateStepSpots() async {
    stepSpots.clear();

    final currentTime = DateTime.now();
    final monday = currentTime.subtract(
        Duration(days: currentTime.weekday - 1));

    for (int i = 0; i < 7; i++) {
      final date = monday.add(Duration(days: i));
      final key = _dayKey(date);
      final steps = stepsHistoryByDate[key] ?? 0;
      stepSpots.add(FlSpot(i.toDouble(), steps.toDouble()));
    }

    stepSpots.refresh();
  }

  List<FlSpot> getMonthlyStepsSpots(DateTime month) {
    final normalizedMonth = DateTime(month.year, month.month);
    final cacheKey = _monthCacheKey(normalizedMonth);
    final cached = _monthlySpotsCache[cacheKey];
    if (cached != null) return cached;

    final int totalDays =
    (normalizedMonth.year == DateTime
        .now()
        .year &&
        normalizedMonth.month == DateTime
            .now()
            .month)
        ? DateTime
        .now()
        .day
        : DateTime(normalizedMonth.year, normalizedMonth.month + 1, 0).day;

    final Map<int, int> dayToSteps = {};
    for (final entry in _stepsHistoryList) {
      if (entry.date.year == normalizedMonth.year &&
          entry.date.month == normalizedMonth.month) {
        dayToSteps[entry.date.day] = max(
          dayToSteps[entry.date.day] ?? 0,
          entry.steps,
        );
      }
    }

    for (final entry in stepsHistoryByDate.entries) {
      final date = _tryParseDayKey(entry.key);
      if (date == null) continue;
      if (date.year == normalizedMonth.year &&
          date.month == normalizedMonth.month) {
        dayToSteps[date.day] = max(dayToSteps[date.day] ?? 0, entry.value);
      }
    }

    if (normalizedMonth.year == DateTime
        .now()
        .year &&
        normalizedMonth.month == DateTime
            .now()
            .month) {
      dayToSteps[DateTime
          .now()
          .day] = max(
        dayToSteps[DateTime
            .now()
            .day] ?? 0,
        todaySteps.value,
      );
    }

    final List<FlSpot> spots = [];
    for (int day = 1; day <= totalDays; day++) {
      final steps = dayToSteps[day] ?? 0;
      spots.add(FlSpot((day - 1).toDouble(), steps.toDouble()));
    }

    final unmodifiableSpots = List<FlSpot>.unmodifiable(spots);
    _monthlySpotsCache[cacheKey] = unmodifiableSpots;
    return unmodifiableSpots;
  }

  String _dayKey(DateTime date) => "${date.year}-${date.month}-${date.day}";

  DateTime? _tryParseDayKey(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  String _monthCacheKey(DateTime date) => '${date.year}-${date.month}';

  void _invalidateMonthlySpotsCache({DateTime? month}) {
    if (month == null) {
      _monthlySpotsCache.clear();
      return;
    }

    _monthlySpotsCache.remove(
      _monthCacheKey(DateTime(month.year, month.month)),
    );
  }

  void _mergeTodayIntoHistory() {
    final key = _dayKey(DateTime.now());
    final existing = stepsHistoryByDate[key] ?? 0;

    if (todaySteps.value > existing) {
      stepsHistoryByDate[key] = todaySteps.value;
      stepsHistoryByDate.refresh();
    }

    final today = DateTime.now();
    final index = _stepsHistoryList.indexWhere(
          (entry) =>
      entry.date.year == today.year &&
          entry.date.month == today.month &&
          entry.date.day == today.day,
    );

    if (index == -1) {
      _stepsHistoryList.add(_StepEntry(date: today, steps: todaySteps.value));
      return;
    }

    final existingEntry = _stepsHistoryList[index];
    if (todaySteps.value > existingEntry.steps) {
      _stepsHistoryList[index] = _StepEntry(
        date: today,
        steps: todaySteps.value,
      );
      _stepsHistoryList.refresh();
    }
  }

  Future<void> _mergeRecentLocalStepsIntoHistory() async {
    final stepMap = await FileStorageService().readRecentStepsMap(days: 7);
    for (final entry in stepMap.entries) {
      if (entry.value <= 0) continue;
      final existing = stepsHistoryByDate[entry.key] ?? 0;
      if (entry.value >= existing) {
        stepsHistoryByDate[entry.key] = entry.value;
      }
    }
    stepsHistoryByDate.refresh();
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }
}

class _StepEntry {
  final DateTime date;
  final int steps;

  const _StepEntry({required this.date, required this.steps});
}
