import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:snevva/common/custom_snackbar.dart';
import 'package:snevva/env/env.dart';

import 'package:snevva/models/queryParamViewModels/step_goal_vm.dart';
import 'package:snevva/services/api_service.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/services/hive_service.dart';

import '../../common/global_variables.dart';
import '../../models/hive_models/steps_model.dart';

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
  RxList<StepEntry> stepsHistoryList = <StepEntry>[].obs;
  double lastPercent = 0.0;

  // Current percent of goal (used by UI animations)
  double get _currentPercent =>
      stepGoal.value == 0 ? 0.0 : todaySteps.value / stepGoal.value;

  static const String _lastSyncedDateKey = "last_synced_step_date";

  late Box<StepEntry> _stepBox;
  // Helper to avoid crashes when underlying Hive file gets closed by another isolate.
  // If a FileSystemException occurs, we attempt to reopen the box asynchronously
  // and return a safe fallback value.
  Future<void> _reopenStepBox() async {
    try {
      _stepBox = await HiveService().stepHistoryBox();

      debugPrint('🔁 Reopened step_history box');
    } catch (e) {
      debugPrint('❌ Failed to reopen step_history box: $e');
    }
  }

  /// Ensure the step_history box is opened and _stepBox assigned.
  Future<void> _ensureStepBox() async {
    try {
      _stepBox = await HiveService().stepHistoryBox();
    } catch (e) {
      debugPrint('❌ _ensureStepBox failed: $e');
      // Try reopen fallback
      await _reopenStepBox();
    }
  }

  int _safeGetSteps(String key) {
    try {
      return _stepBox.get(key)?.steps ?? 0;
    } catch (e) {
      if (e is FileSystemException) {
        // Reopen in background and return 0 for this tick
        _reopenStepBox();
        return 0;
      }
      // For any other error (including late init), attempt to ensure box is opened
      _ensureStepBox();
      return 0;
    }
  }

  Future<void> _safePutSteps(String key, StepEntry entry) async {
    try {
      await _stepBox.put(key, entry);
    } catch (e) {
      if (e is FileSystemException) {
        await _reopenStepBox();
        try {
          await _stepBox.put(key, entry);
        } catch (e2) {
          debugPrint('❌ Failed to put after reopen: $e2');
        }
      } else {
        // Attempt to ensure box and retry once for any other error
        await _ensureStepBox();
        try {
          await _stepBox.put(key, entry);
        } catch (e2) {
          debugPrint('❌ Failed to put after ensure: $e2');
        }
      }
    }
  }

  late SharedPreferences _prefs;
  Timer? _hivePoller;
  StreamSubscription? _stepsUpdatedSubscription;
  bool _isRealtimeTrackingActive = false;
  DateTime _lastServiceEventAt = DateTime.fromMillisecondsSinceEpoch(0);
  final Map<String, List<FlSpot>> _monthlySpotsCache = <String, List<FlSpot>>{};

  // MethodChannel for receiving live steps from the native StepCounterService
  static const _stepChannel =
      MethodChannel('com.coretegra.snevva/step_detector');

  static const Duration _syncInterval = Duration(hours: 4);
  static const Duration _hiveFallbackPollInterval = Duration(seconds: 30);
  static const String _lastSyncKey = "last_step_sync_time";

  // =======================
  // INIT
  // =======================
  @override
  Future<void> onInit() async {
    super.onInit();

    // Initialize prefs and Hive box
    await _init();

    // Load today's steps from Hive first
    await loadTodayStepsFromHive();
  }

  @override
  void onClose() {
    _stepChannel.setMethodCallHandler(null); // remove native listener
    deactivateRealtimeTracking();
    super.onClose();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    // Ensure box exists
    await _ensureStepBox();

    _checkDayReset();
    scheduleMidnightReset();

    await loadGoal();

    // Set up the MethodChannel handler so the native StepCounterService can
    // push live step counts directly into the Dart UI without relying on
    // the flutter_background_service `steps_updated` event (which is never
    // sent by the native service).
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
          await _saveToHive(newSteps);
          await _maybeSyncSteps();
        }
      }
    });

    // Always run the hive poller so the UI has a live fallback even when
    // the screen is not open (e.g. on app resume).
    _startHivePoller();
  }

  // Starts (or restarts) the periodic Hive poller.
  void _startHivePoller() {
    _hivePoller?.cancel();
    _hivePoller = Timer.periodic(_hiveFallbackPollInterval, (_) {
      // Only poll Hive when we haven't received a recent MethodChannel event.
      if (DateTime.now().difference(_lastServiceEventAt) >=
          _hiveFallbackPollInterval) {
        _pollHiveToday();
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

      // 🔥 CRITICAL FIXES
      stepsHistoryByDate.remove(todayKey);
      stepsHistoryByDate.refresh();
      // await _prefs.remove('today_steps');
      await _prefs.setInt('today_steps', 0);

      await _safePutSteps(
        todayKey,
        StepEntry(date: _startOfDay(now), steps: 0),
      );

      await _prefs.setString("last_step_date", todayKey);
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

    final steps = _safeGetSteps(dayKey);
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

      // Store last value for animation
      lastSteps = todaySteps.value;
      lastStepsRx.value = lastSteps;
      lastPercent = _currentPercent;

      // Update reactive value regardless (we'll persist to Hive afterwards)
      todaySteps.value = newSteps;

      // Persist to Hive
      await _saveToHive(todaySteps.value);

      // Trigger API sync if needed
      await _maybeSyncSteps();
    });
  }

  void activateRealtimeTracking() {
    if (_isRealtimeTrackingActive) return;

    _isRealtimeTrackingActive = true;
    // MethodChannel handler is already set up in _init(); no need to re-register.
    // Ensure the hive poller is running (it may have been cancelled by deactivate).
    _startHivePoller();
  }

  void deactivateRealtimeTracking() {
    // Keep the hive poller running so the UI still refreshes in background,
    // but mark tracking as inactive so activateRealtimeTracking can restart it.
    _isRealtimeTrackingActive = false;
    // The MethodChannel handler remains active (registered in _init) so native
    // steps are always received regardless of UI screen lifecycle.
  }

  // =======================
  // STEP UPDATES (MANUAL - if needed)
  // =======================

  /// Manual update (use only if you have direct step data, not from service)
  void updateSteps(int newSteps) async {
    if (newSteps <= todaySteps.value) return;

    lastSteps = todaySteps.value;
    lastStepsRx.value = lastSteps;
    lastPercent = _currentPercent;

    todaySteps.value = newSteps;

    _saveToHive(todaySteps.value);
    await _maybeSyncSteps();
  }

  // =======================
  // HIVE
  // =======================
  Future<void> _pollHiveToday() async {
    try {
      await _prefs.reload();
      final todayKey = _dayKey(DateTime.now());
      final steps = _safeGetSteps(todayKey);

      // Also check shared prefs fallback written by background isolate
      final prefSteps = _prefs.getInt('today_steps');
      final effective =
          (prefSteps != null && prefSteps > steps) ? prefSteps : steps;

      if (effective != todaySteps.value) {
        // Update reactive values and graph
        lastSteps = todaySteps.value;
        lastStepsRx.value = lastSteps;
        lastPercent = _currentPercent;
        todaySteps.value = effective;
        todaySteps.refresh();
        await updateStepSpots();
        stepSpots.refresh();
        _debugLog(
          "🔎 Hive poll detected change: todaySteps = $effective (hive=$steps pref=$prefSteps)",
        );
        // _checkDayReset();
      }
    } catch (e) {
      // ignore polling errors
      _debugLog('❌ Poll hive error: $e');
      // attempt reopen if filesystem issue
      if (e is FileSystemException) await _reopenStepBox();
    }
  }

  Future<void> _saveToHive(int steps) async {
    final today = DateTime.now();
    final key = _dayKey(today);

    // Persist safely
    await _safePutSteps(key, StepEntry(date: _startOfDay(today), steps: steps));

    _invalidateMonthlySpotsCache(month: today);

    // Update graph immediately and notify observers
    await updateStepSpots();
    stepSpots.refresh();
  }

  Future<void> loadTodayStepsFromHive() async {
    final todayKey = _dayKey(DateTime.now());
    final steps = _safeGetSteps(todayKey);

    // Preserve previous value so animations can interpolate from the
    // former step count to the new one. If this is the initial load
    // (todaySteps.value == 0 and lastSteps == 0) this will be harmless.
    final prev = todaySteps.value;

    if (prev != steps) {
      // Set lastSteps to previous value to enable smooth animation
      lastSteps = prev;
      lastStepsRx.value = lastSteps;
      lastPercent = (stepGoal.value == 0) ? 0.0 : lastSteps / stepGoal.value;

      todaySteps.value = steps;
      todaySteps.refresh();
      debugPrint("📊 Loaded from Hive (changed): $steps steps (prev=$prev)");

      /// Refresh graph with loaded data and notify observers
      await updateStepSpots();
      stepSpots.refresh();
    } else {
      // No change; just ensure graph is in syncebugPrint("📊 Loaded from Hive: $steps steps (no change)");
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

    // Only update if API data is greater than Hive data
    if (todayTotal > todaySteps.value) {
      // preserve previous value for smooth animation
      lastSteps = todaySteps.value;
      lastStepsRx.value = lastSteps;
      lastPercent = _currentPercent;

      todaySteps.value = todayTotal;
      todaySteps.refresh();

      // Persist and refresh graph
      await _saveToHive(todayTotal); // Save updated steps to Hive
      // stepSpots.refresh(); (already refreshed in _saveToHive)
    }
  }

  Future<void> loadStepsfromAPI({required int month, required int year}) async {
    try {
      // Ensure Hive box is available before processing API data
      await _ensureStepBox();

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

      debugPrint("🔄 Fetched step data from API: $stepData");

      stepsHistoryList.clear();

      // Merge API data with Hive: prefer the larger value for each day and persist if API is larger
      for (final item in stepData) {
        final date = DateTime(item['Year'], item['Month'], item['Day']);
        final apiCount = (item['Count'] ?? 0) as int;
        final key = _dayKey(date);

        final hiveCount = _safeGetSteps(key);

        final merged = apiCount > hiveCount ? apiCount : hiveCount;

        // If API has higher value, persist merged value to Hive
        if (apiCount > hiveCount) {
          await _safePutSteps(
            key,
            StepEntry(date: _startOfDay(date), steps: merged),
          );
        }

        stepsHistoryList.add(StepEntry(date: date, steps: merged));
      }

      await calculateTodayStepsFromList(stepData);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isStepGoalSet', true);

      // ✅ Step goal
      stepGoal.value =
          decoded['data']?['StepGoalData']?['Count'] ?? stepGoal.value;

      // ✅ Build map + graph (will merge with Hive inside)
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
    final normalizedMonth = DateTime(month.year, month.month);
    final cacheKey = _monthCacheKey(normalizedMonth);
    final cached = _monthlySpotsCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    // Determine the total days to plot (only till today if current month)
    final int totalDays =
        (normalizedMonth.year == DateTime.now().year &&
                normalizedMonth.month == DateTime.now().month)
            ? DateTime.now().day
            : DateTime(normalizedMonth.year, normalizedMonth.month + 1, 0).day;

    // Build a lookup map from API / stored data
    final Map<int, int> dayToSteps = {};
    for (final entry in stepsHistoryList) {
      if (entry.date.year == normalizedMonth.year &&
          entry.date.month == normalizedMonth.month) {
        // Keep the maximum steps per day if multiple entries exist
        dayToSteps[entry.date.day] = max(
          dayToSteps[entry.date.day] ?? 0,
          entry.steps,
        );
      }
    }

    // Generate FlSpots for the graph
    final List<FlSpot> spots = [];
    for (int day = 1; day <= totalDays; day++) {
      final steps = dayToSteps[day] ?? 0;
      spots.add(FlSpot((day - 1).toDouble(), steps.toDouble()));
    }

    final unmodifiableSpots = List<FlSpot>.unmodifiable(spots);
    _monthlySpotsCache[cacheKey] = unmodifiableSpots;
    _debugLog(
      "📅 [MonthlyGraph] cached ${unmodifiableSpots.length} spots for $cacheKey",
    );
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

  /// 🔁 Sync every 500 steps (LIVE)
  Future<void> _maybeSyncSteps() async {
    if (todaySteps.value <= 0) return;

    final todayKey = _dayKey(now);

    final lastSyncMillis = _prefs.getInt(_lastSyncKey);
    final lastSyncTime =
        lastSyncMillis != null
            ? DateTime.fromMillisecondsSinceEpoch(lastSyncMillis)
            : null;

    final lastSyncedDate = _prefs.getString(_lastSyncedDateKey);

    // 🔥 Always allow first sync of the day
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
      final date = DateUtils.dateOnly(DateTime.now());
      final steps = todaySteps.value;

      final payload = {
        "Day": now.day,
        "Month": now.month,
        "Year": now.year,
        "Time": TimeOfDay.now().format(Get.context!),
        "Count": steps,
      };

      final newRecord = StepEntry(date: date, steps: todaySteps.value);
      stepsHistoryList.add(newRecord);
      await buildStepsHistoryMap();

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
    // Start by populating map from local Hive (local source of truth when API is not called)
    stepsHistoryByDate.clear();
    _invalidateMonthlySpotsCache();

    // Ensure the box is available
    await _ensureStepBox();

    try {
      for (final key in _stepBox.keys) {
        try {
          final entry = _stepBox.get(key);
          if (entry == null) continue;
          final k = _dayKey(entry.date);
          stepsHistoryByDate[k] = entry.steps;
        } catch (e) {
          if (e is FileSystemException) {
            _reopenStepBox();
            // skip this entry; it'll be picked up on next build
            continue;
          }
        }
      }
    } catch (e) {
      // If iterating keys fails due to filesystem, attempt reopen and continue
      if (e is FileSystemException) {
        _reopenStepBox();
      }
    }

    // Merge API-provided entries (stepsHistoryList) on top, preferring the larger value
    for (final item in stepsHistoryList) {
      final key = "${item.date.year}-${item.date.month}-${item.date.day}";
      final existing = stepsHistoryByDate[key] ?? 0;
      final merged = item.steps > existing ? item.steps : existing;
      stepsHistoryByDate[key] = merged;

      // Ensure Hive also reflects merged result
      final hiveCount = _safeGetSteps(key);
      if (merged > hiveCount) {
        await _safePutSteps(
          key,
          StepEntry(date: _startOfDay(item.date), steps: merged),
        );
      }
    }

    syncTodayIntakeFromMap();
    await updateStepSpots();
  }

  // Update the weekly spot values by reading from the merged map and/or Hive.
  Future<void> updateStepSpots() async {
    // Ensure box is available
    await _ensureStepBox();

    stepSpots.clear();

    DateTime now = DateTime.now();
    DateTime monday = now.subtract(Duration(days: now.weekday - 1));

    for (int i = 0; i < 7; i++) {
      DateTime date = monday.add(Duration(days: i));
      String key = _dayKey(date);

      // Read-only access
      int steps = stepsHistoryByDate[key] ?? _safeGetSteps(key);

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

  // Public safe accessors so other parts of the app can read/write safely.
  int getStepsForKey(String key) => _safeGetSteps(key);

  Future<void> putStepsForKey(String key, StepEntry entry) async =>
      _safePutSteps(key, entry);

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
