import 'dart:async';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:snevva/common/custom_snackbar.dart';
import 'package:snevva/env/env.dart';

import 'package:snevva/models/queryParamViewModels/step_goal_vm.dart';
import 'package:snevva/services/api_service.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/services/file_storage_service.dart';

import '../../common/global_variables.dart';

// ─────────────────────────────────────────────────────────────────────────────
// StepCounterController
//
// Hive has been replaced by FileStorageService:
//   • _saveToFile()        — replaces _safePutSteps()
//   • _loadTodayStepsFromFile() — replaces loadTodayStepsFromHive()
//   • _pollFileToday()     — replaces _pollHiveToday()
//   • buildStepsHistoryMap() reads from FileStorageService.readRecentStepsMap()
//
// SharedPreferences is kept only for the fast-path "today_steps" counter and
// config (step_goal, last_sync keys) — these are all tiny, low-frequency values.
// ─────────────────────────────────────────────────────────────────────────────

class StepCounterController extends GetxController {
  // =======================
  // OBSERVABLE STATE
  // =======================
  RxInt todaySteps = 0.obs;
  RxInt stepGoal = 8000.obs;

  final FlutterBackgroundService _service = FlutterBackgroundService();

  int lastSteps = 0;
  RxInt lastStepsRx = 0.obs;
  final RxList<FlSpot> stepSpots = <FlSpot>[].obs;
  final RxMap<String, int> stepsHistoryByDate = <String, int>{}.obs;
  // Kept for API-fetched history used by the monthly graph
  final RxList<_StepEntry> stepsHistoryList = <_StepEntry>[].obs;
  double lastPercent = 0.0;

  double get _currentPercent =>
      stepGoal.value == 0 ? 0.0 : todaySteps.value / stepGoal.value;

  static const String _lastSyncedDateKey = "last_synced_step_date";
  static const Duration _syncInterval = Duration(hours: 4);
  static const Duration _filePollInterval = Duration(seconds: 30);
  static const String _lastSyncKey = "last_step_sync_time";

  late SharedPreferences _prefs;
  Timer? _filePoller;
  StreamSubscription? _stepsUpdatedSubscription;
  bool _isRealtimeTrackingActive = false;
  DateTime _lastServiceEventAt = DateTime.fromMillisecondsSinceEpoch(0);
  final Map<String, List<FlSpot>> _monthlySpotsCache = <String, List<FlSpot>>{};

  static const _stepChannel =
      MethodChannel('com.coretegra.snevva/step_detector');

  // =======================
  // INIT
  // =======================
  @override
  Future<void> onInit() async {
    super.onInit();
    await _init();
    await buildStepsHistoryMap();
    await loadTodayStepsFromFile();
  }

  @override
  void onClose() {
    _stepChannel.setMethodCallHandler(null);
    deactivateRealtimeTracking();
    super.onClose();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();

    _checkDayReset();
    scheduleMidnightReset();

    await loadGoal();

    // MethodChannel handler: native StepCounterService pushes live steps
    _stepChannel.setMethodCallHandler((call) async {
      if (call.method == 'onStepDetected') {
        final int newSteps = (call.arguments as int?) ?? 0;
        _lastServiceEventAt = DateTime.now();

        if (newSteps > todaySteps.value) {
          lastSteps = todaySteps.value;
          lastStepsRx.value = lastSteps;
          lastPercent = _currentPercent;
          todaySteps.value = newSteps;
          todaySteps.refresh();
          await _saveToFile(newSteps);
          await _maybeSyncSteps();
        }
      }
    });

    _startFilePoller();
  }

  // =======================
  // FILE POLLER (replaces Hive poller)
  // =======================
  void _startFilePoller() {
    _filePoller?.cancel();
    _filePoller = Timer.periodic(_filePollInterval, (_) {
      if (DateTime.now().difference(_lastServiceEventAt) >= _filePollInterval) {
        _pollFileToday();
      }
    });
  }

  // =======================
  // DAY RESET
  // =======================
  Future<void> _checkDayReset() async {
    final todayKey = _dayKey(now);
    final lastDate = _prefs.getString("last_step_date");

    if (lastDate != null && lastDate != todayKey) {
      await _forceSyncPreviousDay(lastDate);
    }

    if (lastDate != todayKey) {
      debugPrint("🌅 New day detected → resetting steps");

      todaySteps.value = 0;
      lastSteps = 0;
      lastStepsRx.value = 0;
      lastPercent = 0.0;

      stepsHistoryByDate.remove(todayKey);
      stepsHistoryByDate.refresh();
      await _prefs.setInt('today_steps', 0);
      await _prefs.setString("last_step_date", todayKey);

      // Flush stale buffer and queue yesterday for sync
      await FileStorageService().flushStepsToDaily();
      if (lastDate != null) {
        await FileStorageService().addToSyncQueue(lastDate);
      }
    }
  }

  void scheduleMidnightReset() {
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    Timer(nextMidnight.difference(now), () {
      _checkDayReset();
      scheduleMidnightReset();
    });
  }

  Future<void> _forceSyncPreviousDay(String dayKey) async {
    final alreadySynced = _prefs.getString(_lastSyncedDateKey);

    if (alreadySynced == dayKey) {
      debugPrint("⏭️ Yesterday already synced");
      return;
    }

    // Read from file storage instead of Hive
    final steps = await FileStorageService().readDailySteps(dayKey);
    if (steps <= 0) return;

    final parts = dayKey.split("-");
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);

    final payload = {
      "Day": day,
      "Month": month,
      "Year": year,
      "Time": "23:59",
      "Count": steps,
    };

    try {
      await ApiService.post(
        stepRecord,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      await _prefs.setString(_lastSyncedDateKey, dayKey);
      debugPrint("✅ Yesterday steps force-synced: $steps");
    } catch (e) {
      debugPrint("❌ Failed to force sync yesterday: $e");
    }
  }

  // =======================
  // LISTEN TO BACKGROUND SERVICE
  // =======================
  void _listenToBackgroundSteps() {
    _stepsUpdatedSubscription?.cancel();
    _stepsUpdatedSubscription = _service.on("steps_updated").listen((
      event,
    ) async {
      _lastServiceEventAt = DateTime.now();
      if (event == null) return;

      final int newSteps = event["steps"] ?? 0;

      lastSteps = todaySteps.value;
      lastStepsRx.value = lastSteps;
      lastPercent = _currentPercent;

      todaySteps.value = newSteps;

      await _saveToFile(todaySteps.value);
      await _maybeSyncSteps();
    });
  }

  void activateRealtimeTracking() {
    if (_isRealtimeTrackingActive) return;
    _isRealtimeTrackingActive = true;
    _startFilePoller();
  }

  void deactivateRealtimeTracking() {
    _isRealtimeTrackingActive = false;
  }

  // =======================
  // STEP UPDATES
  // =======================
  void updateSteps(int newSteps) async {
    if (newSteps <= todaySteps.value) return;

    lastSteps = todaySteps.value;
    lastStepsRx.value = lastSteps;
    lastPercent = _currentPercent;

    todaySteps.value = newSteps;

    _saveToFile(todaySteps.value);
    await _maybeSyncSteps();
  }

  // =======================
  // FILE STORAGE (replaces Hive)
  // =======================

  Future<void> _pollFileToday() async {
    try {
      await _prefs.reload();
      final todayKey = _dayKey(DateTime.now());

      // Fast-path: SharedPrefs holds the latest step count written by native
      final prefSteps = _prefs.getInt('today_steps') ?? 0;
      // Secondary: daily file (reflects flushed buffer)
      final fileSteps = await FileStorageService().readDailySteps(todayKey);
      final effective = prefSteps > fileSteps ? prefSteps : fileSteps;

      if (effective != todaySteps.value) {
        lastSteps = todaySteps.value;
        lastStepsRx.value = lastSteps;
        lastPercent = _currentPercent;
        todaySteps.value = effective;
        todaySteps.refresh();
        await updateStepSpots();
        stepSpots.refresh();
        _debugLog("🔎 File poll detected change: todaySteps = $effective");
      }
    } catch (e) {
      _debugLog('❌ Poll file error: $e');
    }
  }

  Future<void> _saveToFile(int steps) async {
    // Append to file buffer — Kotlin's BufferManager is the primary writer;
    // this call ensures the Dart isolate also records steps if both are active.
    await FileStorageService().appendStepEvent(steps);
    // Also keep SharedPrefs fast-path up to date
    await _prefs.setInt('today_steps', steps);

    _invalidateMonthlySpotsCache(month: DateTime.now());
    await updateStepSpots();
    stepSpots.refresh();
  }

  Future<void> loadTodayStepsFromFile() async {
    final todayKey = _dayKey(DateTime.now());
    // Prefer SharedPrefs fast-path (written by native service every step)
    final prefSteps = _prefs.getInt('today_steps') ?? 0;
    final fileSteps = await FileStorageService().readDailySteps(todayKey);
    final steps = prefSteps > fileSteps ? prefSteps : fileSteps;

    final prev = todaySteps.value;

    if (prev != steps) {
      lastSteps = prev;
      lastStepsRx.value = lastSteps;
      lastPercent = (stepGoal.value == 0) ? 0.0 : lastSteps / stepGoal.value;

      todaySteps.value = steps;
      todaySteps.refresh();
      debugPrint("📊 Loaded from file (changed): $steps steps (prev=$prev)");

      await updateStepSpots();
      stepSpots.refresh();
    } else {
      await updateStepSpots();
    }
  }

  Future<void> calculateTodayStepsFromList(List stepsList) async {
    int todayTotal = 0;

    for (var item in stepsList) {
      if (item['Day'] == now.day &&
          item['Month'] == now.month &&
          item['Year'] == now.year) {
        todayTotal = max(todayTotal, item['Count']);
      }
    }

    debugPrint("🔢 Calculated today steps from list: $todayTotal");

    if (todayTotal > todaySteps.value) {
      lastSteps = todaySteps.value;
      lastStepsRx.value = lastSteps;
      lastPercent = _currentPercent;

      todaySteps.value = todayTotal;
      todaySteps.refresh();

      await _saveToFile(todayTotal);
    }
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

      debugPrint("🔄 Fetched step data from API: $stepData");

      stepsHistoryList.clear();

      for (final item in stepData) {
        final date = DateTime(item['Year'], item['Month'], item['Day']);
        final apiCount = (item['Count'] ?? 0) as int;
        final key = _dayKey(date);

        final fileCount = await FileStorageService().readDailySteps(key);
        final merged = apiCount > fileCount ? apiCount : fileCount;

        stepsHistoryList.add(_StepEntry(date: date, steps: merged));
      }

      await calculateTodayStepsFromList(stepData);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isStepGoalSet', true);

      stepGoal.value =
          decoded['data']?['StepGoalData']?['Count'] ?? stepGoal.value;

      await buildStepsHistoryMap();

      _invalidateMonthlySpotsCache(month: DateTime(year, month));
      _debugLog("✅ Loaded steps from API: ${stepsHistoryList.length}");
    } catch (e) {
      debugPrint("❌ Error loading steps from API: $e");
    }
  }

  // =======================
  // DATE HELPERS
  // =======================
  String _dayKey(DateTime d) => 
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

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
    final normalizedMonth = DateTime(month.year, month.month);
    final cacheKey = _monthCacheKey(normalizedMonth);
    final cached = _monthlySpotsCache[cacheKey];
    if (cached != null) return cached;

    final int totalDays =
        (normalizedMonth.year == DateTime.now().year &&
                normalizedMonth.month == DateTime.now().month)
            ? DateTime.now().day
            : DateTime(normalizedMonth.year, normalizedMonth.month + 1, 0).day;

    final Map<int, int> dayToSteps = {};
    for (final entry in stepsHistoryList) {
      if (entry.date.year == normalizedMonth.year &&
          entry.date.month == normalizedMonth.month) {
        dayToSteps[entry.date.day] = max(
          dayToSteps[entry.date.day] ?? 0,
          entry.steps,
        );
      }
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

      debugPrint("✅ Step goal synced");
    } catch (_) {
      debugPrint("❌ Step goal sync failed");
    }
  }

  Future<void> _maybeSyncSteps() async {
    if (todaySteps.value <= 0) return;

    final todayKey = _dayKey(now);

    final lastSyncMillis = _prefs.getInt(_lastSyncKey);
    final lastSyncTime =
        lastSyncMillis != null
            ? DateTime.fromMillisecondsSinceEpoch(lastSyncMillis)
            : null;

    final lastSyncedDate = _prefs.getString(_lastSyncedDateKey);

    if (lastSyncedDate != todayKey ||
        lastSyncTime == null ||
        now.difference(lastSyncTime) >= _syncInterval) {
      await saveStepRecordToServer();

      await _prefs.setInt(_lastSyncKey, now.millisecondsSinceEpoch);
      await _prefs.setString(_lastSyncedDateKey, todayKey);
    }
  }

  Future<void> saveStepRecordToServer() async {
    try {
      final steps = todaySteps.value;

      final payload = {
        "Day": now.day,
        "Month": now.month,
        "Year": now.year,
        "Time": TimeOfDay.now().format(Get.context!),
        "Count": steps,
      };

      await ApiService.post(
        stepRecord,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      debugPrint("✅ Daily step record synced");
    } catch (_) {
      debugPrint("❌ Step record sync failed");
    }
  }

  Future<void> buildStepsHistoryMap() async {
    stepsHistoryByDate.clear();
    _invalidateMonthlySpotsCache();

    // Read last 30 days from file storage
    final recentMap = await FileStorageService().readRecentStepsMap(days: 30);
    stepsHistoryByDate.addAll(recentMap);

    // Merge in API-fetched list (prefer larger value)
    for (final item in stepsHistoryList) {
      final key = _dayKey(item.date);
      final existing = stepsHistoryByDate[key] ?? 0;
      if (item.steps > existing) {
        stepsHistoryByDate[key] = item.steps;
      }
    }

    syncTodayIntakeFromMap();
    await updateStepSpots();
  }

  Future<void> updateStepSpots() async {
    stepSpots.clear();

    DateTime now = DateTime.now();
    DateTime monday = now.subtract(Duration(days: now.weekday - 1));

    for (int i = 0; i < 7; i++) {
      DateTime date = monday.add(Duration(days: i));
      String key = _dayKey(date);
      int steps = stepsHistoryByDate[key] ?? 0;
      stepSpots.add(FlSpot(i.toDouble(), steps.toDouble()));
    }

    stepSpots.refresh();
  }

  void syncTodayIntakeFromMap() {
    final key = _dayKey(DateTime.now());
    final mapValue = stepsHistoryByDate[key];

    if (mapValue != null && mapValue > todaySteps.value) {
      todaySteps.value = mapValue;
      todaySteps.refresh();
    }
  }

  void scheduleStepPush() {
    Timer.periodic(Duration(hours: 4), (timer) {
      saveStepRecordToServer();
    });
  }

  // Public safe accessors kept for backward compatibility
  Future<int> getStepsForKey(String key) =>
      FileStorageService().readDailySteps(key);

  Future<void> putStepsForKey(String key, int steps) =>
      FileStorageService().appendStepEvent(steps);

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

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }
}

// Lightweight local-only step entry (no Hive annotations needed)
class _StepEntry {
  final DateTime date;
  final int steps;
  const _StepEntry({required this.date, required this.steps});
}
