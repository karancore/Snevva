import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:health/health.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/common/custom_snackbar.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/env/env.dart';
import 'package:snevva/models/queryParamViewModels/step_goal_vm.dart';
import 'package:snevva/services/api_service.dart';
import 'package:snevva/services/file_storage_service.dart';
import 'package:snevva/services/tracking_service_manager.dart';

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
      MethodChannel('com.coretegra.snevvaa/step_detector');

  bool _isSyncingSteps = false;


  // =======================
  // INIT
  // =======================
  @override
  Future<void> onInit() async {
    super.onInit();
    _init();
    await buildStepsHistoryMap();
    await loadTodayStepsFromFile();
  }

  @override
  void onClose() {
    _stepChannel.setMethodCallHandler(null);
    deactivateRealtimeTracking();
    _iosHealthPoller?.cancel();
    super.onClose();
  }

  Future<void> _init() async {
   _prefs = await SharedPreferences.getInstance();
    _checkDayReset();
    scheduleMidnightReset();

    await loadGoal();


   if (Platform.isIOS) {
     // iOS primary: HealthKit (initialised below after common setup).
     // CMPedometer (IOSStepService.swift) remains active as backup — its
     // MethodChannel events are handled by the unconditional handler below,
     // but are ignored while HealthKit is the active source.
   } else {
     // Android: MethodChannel + file poller (unchanged)
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

   if (Platform.isIOS) {
     await _initIOSHealthKit();
   }
  }

  // ─────────────────────────────────────────────────────────────────────────────
// iOS / Apple HealthKit
// ─────────────────────────────────────────────────────────────────────────────

  // HealthKit fields — iOS only, null on Android
  Health? _iosHealth;
  bool _iosHealthGranted = false;
  Timer? _iosHealthPoller;

  Future<void> _initIOSHealthKit() async {
    _iosHealth = Health();
    await _iosHealth!.configure();
    try {
      _iosHealthGranted = await _iosHealth!.requestAuthorization(
        [HealthDataType.STEPS],
        permissions: [HealthDataAccess.READ],
      );
    } catch (e) {
      debugPrint('⚠️ HealthKit auth error: $e');
      _iosHealthGranted = false;
    }

    if (_iosHealthGranted) {
      debugPrint('✅ HealthKit granted — primary step source active');
      await _fetchIOSStepsToday();
      await _fetchIOSStepsHistorical(days: 30);
      _startIOSHealthPoller();
    } else {
      debugPrint('⚠️ HealthKit not granted — CMPedometer backup active');
    }
  }

  Future<void> _fetchIOSStepsToday() async {
    if (_iosHealth == null || !_iosHealthGranted) return;
    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final steps = await _iosHealth!.getTotalStepsInInterval(midnight, now) ??
          0;
      if (steps <= 0) return;

      _debugLog('🍎 HealthKit today: $steps steps');
      final todayKey = _dayKey(now);

      // Update live counter
      if (steps > todaySteps.value) {
        lastSteps = todaySteps.value;
        lastStepsRx.value = lastSteps;
        lastPercent = _currentPercent;
        todaySteps.value = steps;
        todaySteps.refresh();
        await _prefs.setInt('today_steps', steps);
        await _maybeSyncSteps();
      }

      // Write to daily file so the graph reads it without waiting for native flush
      await FileStorageService().writeStepTotal(todayKey, steps);

      // Update history map immediately so the weekly graph shows today
      if ((stepsHistoryByDate[todayKey] ?? 0) < steps) {
        stepsHistoryByDate[todayKey] = steps;
        stepsHistoryByDate.refresh();
        _invalidateMonthlySpotsCache(month: now);
        await updateStepSpots();
        stepSpots.refresh();
      }
    } catch (e) {
      debugPrint('❌ HealthKit fetch today error: $e');
    }
  }

  Future<void> _fetchIOSStepsHistorical({int days = 30}) async {
    if (_iosHealth == null || !_iosHealthGranted) return;
    try {
      final now = DateTime.now();
      bool changed = false;
      for (int i = 1; i < days; i++) {
        // i=0 is today — handled by _fetchIOSStepsToday
        final date = now.subtract(Duration(days: i));
        final start = DateTime(date.year, date.month, date.day);
        final end = start.add(const Duration(days: 1));
        final steps = await _iosHealth!.getTotalStepsInInterval(start, end) ??
            0;
        if (steps <= 0) continue;
        final key = _dayKey(date);
        if ((stepsHistoryByDate[key] ?? 0) < steps) {
          stepsHistoryByDate[key] = steps;
          await FileStorageService().writeStepTotal(key, steps);
          changed = true;
        }
      }
      if (changed) {
        stepsHistoryByDate.refresh();
        _invalidateMonthlySpotsCache();
        await updateStepSpots();
        stepSpots.refresh();
      }
    } catch (e) {
      debugPrint('❌ HealthKit fetch historical error: $e');
    }
  }

  /// Fetches HealthKit data for every day in [month] and merges it into
  /// [stepsHistoryByDate] so the monthly chart reflects Apple Health data.
  Future<void> fetchIOSHealthKitForMonth(DateTime month) async {
    if (_iosHealth == null || !_iosHealthGranted) return;
    try {
      final now = DateTime.now();
      final isCurrentMonth = month.year == now.year && month.month == now.month;
      final daysInMonth = isCurrentMonth
          ? now.day
          : DateTime(month.year, month.month + 1, 0).day;

      bool changed = false;
      for (int day = 1; day <= daysInMonth; day++) {
        final date = DateTime(month.year, month.month, day);
        if (date.isAfter(now)) break;
        final end = (isCurrentMonth && day == now.day)
            ? now
            : date.add(const Duration(days: 1));
        final steps = await _iosHealth!.getTotalStepsInInterval(date, end) ?? 0;
        if (steps <= 0) continue;
        final key = _dayKey(date);
        if ((stepsHistoryByDate[key] ?? 0) < steps) {
          stepsHistoryByDate[key] = steps;
          await FileStorageService().writeStepTotal(key, steps);
          changed = true;
        }
      }
      if (changed) {
        stepsHistoryByDate.refresh();
        _invalidateMonthlySpotsCache(month: month);
      }
    } catch (e) {
      debugPrint('❌ HealthKit fetch month error: $e');
    }
  }

  void _startIOSHealthPoller() {
    _iosHealthPoller?.cancel();
    _iosHealthPoller = Timer.periodic(_filePollInterval, (_) {
      _fetchIOSStepsToday();
    });
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

    // ── Kotlin (StepCounterService) owns the day-change pipeline ────────────
    // When the sensor fires on the first step of a new day, Kotlin:
    //   1. Flushes yesterday's buffer → daily JSON
    //   2. Adds yesterday to sync_queue.json
    //   3. Enqueues ApiSyncWorker (no Flutter engine needed)
    //
    // _forceSyncPreviousDay() was the Dart fallback for when the app wasn't
    // opened. Since Kotlin runs 24/7 (foreground service), the fallback is
    // no longer needed — removing it prevents duplicate API calls.

    if (lastDate != todayKey) {
      debugPrint("🌅 New day detected → resetting UI step display");

      // Reset UI-only state. Do NOT touch `today_steps` in SharedPrefs —
      // that key is authoritative and owned by Kotlin's StepCounterService.
      todaySteps.value = 0;
      lastSteps = 0;
      lastStepsRx.value = 0;
      lastPercent = 0.0;

      stepsHistoryByDate.remove(todayKey);
      stepsHistoryByDate.refresh();
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

  // _forceSyncPreviousDay() has been removed.
  // Day-change sync is now owned entirely by Kotlin's StepCounterService which
  // enqueues ApiSyncWorker (pure Kotlin HTTP, no Flutter engine needed) whenever
  // the sensor fires on the first step of a new calendar day.  This runs even
  // when the app is never opened, solving the original gap.

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
    if (Platform.isIOS) {
      await _prefs.setInt('today_steps', steps);
      // Keep history map in sync so the weekly graph shows today without
      // waiting for the native 5-min buffer flush to the daily JSON file.
      final todayKey = _dayKey(DateTime.now());
      if ((stepsHistoryByDate[todayKey] ?? 0) < steps) {
        stepsHistoryByDate[todayKey] = steps;
        stepsHistoryByDate.refresh();
      }
      _invalidateMonthlySpotsCache(month: DateTime.now());
      await updateStepSpots();
      stepSpots.refresh();
      return;
    }
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
    // if (Platform.isIOS) {
    //   await _fetchIOSStepsToday();
    //   return;
    // }
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

    debugPrint('🔢 Calculated today steps from list: $todayTotal');

    if (todayTotal > todaySteps.value) {
      lastSteps = todaySteps.value;
      lastStepsRx.value = lastSteps;
      lastPercent = _currentPercent;

      todaySteps.value = todayTotal;
      todaySteps.refresh();

      await _saveToFile(todayTotal);

      // Seed the native StepCounterService so its internal counter starts
      // from the API value (e.g. 644 from a previous install) rather than 0.
      // This ensures the notification immediately shows the correct baseline
      // and the sensor increments from the right number.
      await TrackingServiceManager.instance.seedTodaySteps(todayTotal);
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

        // Cache locally ONLY if within the active sliding window (last 30 days) to prevent massive storage bounds while navigating historic months
        if (date.isAfter(DateTime.now().subtract(const Duration(days: 30)))) {
          await FileStorageService().writeStepTotal(key, merged);
        }

        stepsHistoryList.add(_StepEntry(date: date, steps: merged));
      }

      await calculateTodayStepsFromList(stepData);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isStepGoalSet', true);

      stepGoal.value =
          decoded['data']?['StepGoalData']?['Count'] ?? stepGoal.value;

      await buildStepsHistoryMap();

      // iOS: supplement API data with HealthKit readings for this month
      if (Platform.isIOS) {
        await fetchIOSHealthKitForMonth(DateTime(year, month));
      }

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

    // iOS: seed from stepsHistoryByDate which carries HealthKit readings
    // (covers last ~30 days without needing an API response).
    if (Platform.isIOS) {
      for (int day = 1; day <= totalDays; day++) {
        final key = _dayKey(
            DateTime(normalizedMonth.year, normalizedMonth.month, day));
        final steps = stepsHistoryByDate[key] ?? 0;
        if (steps > 0) dayToSteps[day] = steps;
      }
    }

    // Merge API data — prefer whichever value is larger
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
    if (_isSyncingSteps) return; // 🔒 in-flight guard — blocks concurrent calls

    final todayKey = _dayKey(now);
    final lastSyncMillis = _prefs.getInt(_lastSyncKey);
    final lastSyncTime = lastSyncMillis != null
        ? DateTime.fromMillisecondsSinceEpoch(lastSyncMillis)
        : null;
    final lastSyncedDate = _prefs.getString(_lastSyncedDateKey);

    final shouldSync = lastSyncedDate != todayKey ||
        lastSyncTime == null ||
        now.difference(lastSyncTime) >= _syncInterval;

    if (!shouldSync) return;

    _isSyncingSteps = true;
    try {
      await saveStepRecordToServer();
      await _prefs.setInt(_lastSyncKey, now.millisecondsSinceEpoch);
      await _prefs.setString(_lastSyncedDateKey, todayKey);
    } finally {
      _isSyncingSteps = false; // always release, even on failure
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

    // iOS: merge today's SharedPreferences fast-path so the weekly graph shows
    // today's count even between native buffer flushes (which happen every 5 min).
    if (Platform.isIOS) {
      final prefs = await SharedPreferences.getInstance();
      final todayKey = _dayKey(DateTime.now());
      final prefSteps = prefs.getInt('today_steps') ?? 0;
      if (prefSteps > (stepsHistoryByDate[todayKey] ?? 0)) {
        stepsHistoryByDate[todayKey] = prefSteps;
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
