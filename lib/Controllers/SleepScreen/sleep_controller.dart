import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:get/get.dart';
import 'package:get/get_connect/http/src/response/response.dart' as http;
import 'package:get_storage/get_storage.dart';
import 'package:hive/hive.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:snevva/common/custom_snackbar.dart';
import 'package:snevva/env/env.dart';
import 'package:snevva/models/awake_interval.dart';
import 'package:snevva/services/api_service.dart';
import 'package:snevva/common/agent_debug_logger.dart';

import '../../common/global_variables.dart';

import '../../models/hive_models/sleep_log.dart';
import '../../services/sleep/sleep_noticing_service.dart';

enum SleepState { sleeping, awake }

class SleepController extends GetxService {
  // Storage keys
  static const String BEDTIME_KEY = 'user_bedtime_ms';
  static const String WAKETIME_KEY = 'user_waketime_ms';

  // Observable state
  final Rx<Duration> currentSleepDuration = Duration.zero.obs;
  final Rx<Duration> sleepGoal = const Duration(hours: 8).obs;
  final RxBool isSleeping = false.obs;
  final Rx<DateTime?> sleepStartTime = Rxn<DateTime>();
  final RxDouble sleepProgress = 0.0.obs; // 0.0 to 1.0

  // User sleep schedule
  final Rxn<TimeOfDay> bedtime = Rxn<TimeOfDay>();
  final Rxn<TimeOfDay> waketime = Rxn<TimeOfDay>();

  // Weekly sleep history
  final RxMap<String, Duration> weeklySleepHistory = <String, Duration>{}.obs;

  // Background service
  final _service = FlutterBackgroundService();
  StreamSubscription? _sleepUpdateSubscription;
  StreamSubscription? _sleepSavedSubscription;
  StreamSubscription? _goalReachedSubscription;

  static const _sleepCandidateStartKey = "sleep_candidate_start";
  static const _sleepCandidateHadPhoneUsageKey = "sleep_candidate_had_phone";
  static const _correctedSleepMinutesPrefix = "sleep_corrected_minutes_";

  RxBool isMonthlyView = false.obs;

  final RxList<FlSpot> monthlySleepSpots = <FlSpot>[].obs;

  final Rx<DateTime?> newBedtime = Rx<DateTime?>(null);
  final Rx<Duration> deepSleepDuration = Rx<Duration>(Duration.zero);
  final Rx<Duration> sleepGoalInitial = Rx<Duration>(Duration.zero);
  final RxList<Rx<Duration?>> deepSleepDurations =
      List.generate(2, (_) => Rx<Duration?>(null)).obs;

  //final RxMap<String, Duration> deepSleepHistory = <String, Duration>{}.obs;
  final RxMap<String, Duration> weeklyDeepSleepHistory =
      <String, Duration>{}.obs;
  final RxMap<String, Duration> monthlyDeepSleepHistory =
      <String, Duration>{}.obs;

  /// Chart data
  final RxList<FlSpot> deepSleepSpots = <FlSpot>[].obs;
  final List<AwakeInterval> phoneUsageIntervals = [];

  static const String _lastUploadedSleepDateKey =
      "last_uploaded_sleep_bed_date";

  var _storage = GetStorage();

  // ─────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    _loadUserSleepTimes();
    _loadWeeklySleepData();
    _setupBackgroundServiceListeners();
    _checkIfAlreadySleeping();
    loadDeepSleepData();
    loadUserSleepTimes();
  }

  @override
  void onClose() {
    _sleepUpdateSubscription?.cancel();
    _sleepSavedSubscription?.cancel();
    _goalReachedSubscription?.cancel();
    super.onClose();
  }

  // ═══════════════════════════════════════════════════════════════
  // BACKGROUND SERVICE STREAM SETUP
  // ═══════════════════════════════════════════════════════════════

  void _setupBackgroundServiceListeners() {
    // Listen to sleep progress updates (sent every minute)
    _sleepUpdateSubscription = _service.on("sleep_update").listen((event) {
      if (event != null) {
        final elapsedMinutes = event['elapsed_minutes'] as int? ?? 0;
        final goalMinutes = event['goal_minutes'] as int? ?? 480;
        final sleeping = event['is_sleeping'] as bool? ?? false;

        currentSleepDuration.value = Duration(minutes: elapsedMinutes);
        sleepGoal.value = Duration(minutes: goalMinutes);
        isSleeping.value = sleeping;

        // Calculate progress (0.0 to 1.0)
        if (goalMinutes > 0) {
          sleepProgress.value = (elapsedMinutes / goalMinutes).clamp(0.0, 1.0);
        }

        print(
          "💤 Sleep update: ${elapsedMinutes}m / ${goalMinutes}m (${(sleepProgress.value * 100).toInt()}%)",
        );
      }
    });

    // Listen to sleep saved event
    _sleepSavedSubscription = _service.on("sleep_saved").listen((event) async {
      if (event != null) {
        final duration = event['duration'] as int? ?? 0;
        final goalMinutes = event['goal_minutes'] as int? ?? 480;
        final startTime = event['start_time'] as String?;
        final endTime = event['end_time'] as String?;

        print("✅ Sleep saved: ${duration}m (goal: ${goalMinutes}m)");

        // Reset state
        isSleeping.value = false;
        currentSleepDuration.value = Duration.zero;
        sleepProgress.value = 0.0;
        sleepStartTime.value = null;

        // Reload weekly data to show new entry
        await _loadWeeklySleepData();

        // Show success message
        Get.snackbar(
          '😴 Sleep Recorded',
          'You slept for ${_formatDuration(Duration(minutes: duration))}',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
        );
      }
    });

    // Listen to goal reached event
    _goalReachedSubscription = _service.on("sleep_goal_reached").listen((
      event,
    ) {
      if (event != null) {
        final elapsedMinutes = event['elapsed_minutes'] as int? ?? 0;
        final goalMinutes = event['goal_minutes'] as int? ?? 480;

        print("🎉 Sleep goal reached! ${elapsedMinutes}m / ${goalMinutes}m");

        // Show celebration message
        Get.snackbar(
          '🎉 Goal Reached!',
          'You\'ve completed your ${_formatDuration(Duration(minutes: goalMinutes))} sleep goal!',
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // SLEEP CONTROL METHODS
  // ═══════════════════════════════════════════════════════════════

  /// Start sleep tracking with a goal
  Future<void> startSleep({Duration? goal}) async {
    if (isSleeping.value) {
      print("⚠️ Sleep tracking already active");
      return;
    }

    final goalDuration = goal ?? sleepGoal.value;
    final goalMinutes = goalDuration.inMinutes;

    // Update local state
    isSleeping.value = true;
    sleepStartTime.value = DateTime.now();
    sleepGoal.value = goalDuration;
    currentSleepDuration.value = Duration.zero;
    sleepProgress.value = 0.0;

    // Start background tracking
    _service.invoke("start_sleep", {"goal_minutes": goalMinutes});

    print("🌙 Sleep tracking started with goal: ${goalMinutes}m");
  }

  /// Stop sleep tracking
  Future<void> stopSleep() async {
    if (!isSleeping.value) {
      print("⚠️ No active sleep tracking");
      return;
    }

    // Stop background tracking (will trigger save)
    _service.invoke("stop_sleep");

    print("☀️ Sleep tracking stopped");
  }

  /// Set sleep goal
  void setSleepGoal(Duration goal) {
    sleepGoal.value = goal;

    // If currently sleeping, update the goal in background service
    if (isSleeping.value) {
      final prefs = SharedPreferences.getInstance();
      prefs.then((p) => p.setInt("sleep_goal_minutes", goal.inMinutes));
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // SLEEP SCHEDULE METHODS
  // ═══════════════════════════════════════════════════════════════

  void setBedtime(TimeOfDay time) {
    bedtime.value = time;
    final minutes = _timeOfDayToMinutes(time);
    _storage.write(BEDTIME_KEY, minutes);

    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt(BEDTIME_KEY, minutes);
    });

    print('🛏️ Bedtime set → $time');
  }

  void setWakeTime(TimeOfDay time) {
    waketime.value = time;
    final minutes = _timeOfDayToMinutes(time);
    _storage.write(WAKETIME_KEY, minutes);

    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt(WAKETIME_KEY, minutes);
    });

    print('⏰ Waketime set → $time');
    refreshData(); // Refresh UI to show potential new slot if logic depends on it
  }

  // ═══════════════════════════════════════════════════════════════
  // DATA LOADING METHODS
  // ═══════════════════════════════════════════════════════════════

  void _loadUserSleepTimes() {
    final bedMin = _storage.read(BEDTIME_KEY);
    final wakeMin = _storage.read(WAKETIME_KEY);

    if (bedMin != null) {
      bedtime.value = _minutesToTimeOfDay(bedMin);
    }
    if (wakeMin != null) {
      waketime.value = _minutesToTimeOfDay(wakeMin);
    }
  }

  Future<void> _loadWeeklySleepData() async {
    try {
      final box = await Hive.openBox<SleepLog>('sleep_log');
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));

      weeklySleepHistory.clear();

      for (int i = 0; i < 7; i++) {
        final date = weekStart.add(Duration(days: i));
        final key = _dateKey(date);
        final log = box.get(key);

        if (log != null) {
          weeklySleepHistory[key] = Duration(minutes: log.durationMinutes);
        }
      }

      print(
        "📊 Weekly sleep data loaded: ${weeklySleepHistory.length} entries",
      );
    } catch (e) {
      print("❌ Error loading weekly sleep data: $e");
    }
  }

  Future<void> _checkIfAlreadySleeping() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sleeping = prefs.getBool("is_sleeping") ?? false;

      if (sleeping) {
        final startString = prefs.getString("sleep_start_time");
        final goalMinutes = prefs.getInt("sleep_goal_minutes") ?? 480;

        if (startString != null) {
          final start = DateTime.parse(startString);
          final elapsed = DateTime.now().difference(start);

          isSleeping.value = true;
          sleepStartTime.value = start;
          currentSleepDuration.value = elapsed;
          sleepGoal.value = Duration(minutes: goalMinutes);
          sleepProgress.value = (elapsed.inMinutes / goalMinutes).clamp(
            0.0,
            1.0,
          );

          print(
            "🔄 Restored active sleep session: ${elapsed.inMinutes}m / ${goalMinutes}m",
          );
        }
      }
    } catch (e) {
      print("❌ Error checking sleep state: $e");
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════════════════════════

  String _dateKey(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  int _timeOfDayToMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  TimeOfDay _minutesToTimeOfDay(int m) =>
      TimeOfDay(hour: m ~/ 60, minute: m % 60);

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;

    if (hours > 0) {
      return "${hours}h ${minutes}m";
    } else {
      return "${minutes}m";
    }
  }

  /// Get sleep status label based on duration
  String getSleepStatus(Duration? duration) {
    if (duration == null || duration.inMinutes <= 0) return '';

    final hours = duration.inMinutes / 60;

    if (hours < 4) return 'Very Poor';
    if (hours < 5.5) return 'Poor';
    if (hours < 7) return 'Okay';
    if (hours < 8.5) return 'Good';
    return 'Excellent';
  }

  /// Get sleep for a specific date
  Duration? getSleepForDate(DateTime date) {
    final key = _dateKey(date);
    return weeklySleepHistory[key];
  }

  /// Check if there's sleep data for a date
  bool hasSleepDataForDate(DateTime date) {
    return weeklySleepHistory.containsKey(_dateKey(date));
  }

  /// Get average sleep for the week
  Duration get averageWeeklySleep {
    if (weeklySleepHistory.isEmpty) return Duration.zero;

    final total = weeklySleepHistory.values.fold<int>(
      0,
      (sum, duration) => sum + duration.inMinutes,
    );

    return Duration(minutes: total ~/ weeklySleepHistory.length);
  }

  /// Refresh sleep data
  Future<void> refreshData() async {
    await _loadWeeklySleepData();
  }

  DateTime resolveNextWakeDateTime() {
    final wt = waketime.value!;
    final now = DateTime.now();

    DateTime wake = DateTime(now.year, now.month, now.day, wt.hour, wt.minute);

    // If wake time already passed → tomorrow
    if (wake.isBefore(now)) {
      wake = wake.add(const Duration(days: 1));
    }

    return wake;
  }

  Future<void> _finalizeSleepWithoutPhoneRetroactive(
    DateTime sleepStart,
    DateTime sleepEnd,
  ) async {
    final deep = sleepEnd.difference(sleepStart);
    if (deep.inMinutes < 10) return;

    await saveDeepSleepData(sleepStart, deep);
    await uploadsleepdatatoServer(sleepStart, sleepEnd);

    debugPrint("🔁 Retroactive sleep saved (no phone): $deep");
  }

  Future<void> finalizeSleepCycleRetroactive(
    DateTime sleepStart,
    DateTime sleepEnd,
  ) async {
    // Without live screen data, we assume worst-case: awake periods lost
    final deep = sleepEnd.difference(sleepStart);
    if (deep.inMinutes < 10) return;

    await saveDeepSleepData(sleepStart, deep);
    await uploadsleepdatatoServer(sleepStart, sleepEnd);

    debugPrint("🔁 Retroactive sleep saved (phone usage assumed)");
  }

  Future<void> _clearSleepCandidate(SharedPreferences prefs) async {
    await prefs.remove(_sleepCandidateStartKey);
    await prefs.remove(_sleepCandidateHadPhoneUsageKey);
  }

  int timeOfDayToMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  TimeOfDay minutesToTimeOfDay(int m) =>
      TimeOfDay(hour: m ~/ 60, minute: m % 60);

  // DateTime resolveSleepStart(DateTime referenceDate) {
  //   return DateTime(
  //     referenceDate.year,
  //     referenceDate.month,
  //     referenceDate.day,
  //     bedtime.value.hour,
  //     bedtimeTOD.minute,
  //   );
  // }

  DateTime buildDateTime(DateTime base, TimeOfDay tod) {
    return DateTime(base.year, base.month, base.day, tod.hour, tod.minute);
  }

  String dateKey(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  String _correctedPrefKeyForDateKey(String dayKey) =>
      "$_correctedSleepMinutesPrefix$dayKey";

  /// Corrected sleep duration for a given day (pref overrides Hive if present).
  Future<Duration> getCorrectedSleepForDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final key = dateKey(DateUtils.dateOnly(date));
    final mins = prefs.getInt(_correctedPrefKeyForDateKey(key));
    if (mins != null) return Duration(minutes: mins);
    return weeklyDeepSleepHistory[key] ?? Duration.zero;
  }

  // ─────────────────────────────────────────────
  // LOAD FROM HIVE
  // ─────────────────────────────────────────────

  String timeOfDayToString(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Returns a map with the durations:
  /// {
  ///   'beforePhone': Duration, // oldBedtime -> phonePickupTime
  ///   'afterPhone' : Duration, // newBedtime -> oldWakeTime
  ///   'total'      : Duration  // sum of both
  /// }
  ///
  ///
  DateTime normalizeForward(DateTime base, DateTime candidate) {
    // move candidate forward by whole days until it is after base
    DateTime c = candidate;
    while (!c.isAfter(base) && !c.isAtSameMomentAs(base)) {
      c = c.add(const Duration(days: 1));
    }
    return c;
  }

  void loadUserSleepTimes() {
    final bedMin = _storage.read(BEDTIME_KEY);
    final wakeMin = _storage.read(WAKETIME_KEY);

    if (bedMin is int) bedtime.value = minutesToTimeOfDay(bedMin);
    if (wakeMin is int) waketime.value = minutesToTimeOfDay(wakeMin);
  }

  Map<String, Duration> calculateSplitDeepSleep({
    required DateTime oldBedtime,
    required DateTime oldWakeTime,
    required DateTime phonePickupTime,
    required DateTime newBedtime,
  }) {
    // Segment 1: oldBedtime -> phonePickupTime
    DateTime seg1Start = oldBedtime;
    DateTime seg1End = phonePickupTime;
    if (seg1End.isBefore(seg1Start) || seg1End.isAtSameMomentAs(seg1Start)) {
      seg1End = seg1End.add(const Duration(days: 1));
    }

    // Segment 2: newBedtime -> oldWakeTime
    DateTime seg2Start = newBedtime;
    DateTime seg2End = oldWakeTime;
    if (seg2End.isBefore(seg2Start) || seg2End.isAtSameMomentAs(seg2Start)) {
      seg2End = seg2End.add(const Duration(days: 1));
    }

    Duration beforePhone = seg1End.difference(seg1Start);
    Duration afterPhone = seg2End.difference(seg2Start);

    // Guard against negative (shouldn't happen after normalization) just in case
    if (beforePhone.isNegative) beforePhone = Duration.zero;
    if (afterPhone.isNegative) afterPhone = Duration.zero;

    final total = beforePhone + afterPhone;
    return {
      'beforePhone': beforePhone,
      'afterPhone': afterPhone,
      'total': total,
    };
  }

  DateTime _parseTime(int year, int month, int day, String time) {
    final parts = time.split(':');
    return DateTime(year, month, day, int.parse(parts[0]), int.parse(parts[1]));
  }

  Future<void> savesleepToLocalStorage() async {
    final prefs = await SharedPreferences.getInstance();

    if (bedtime.value != null) {
      prefs.setInt('bedtime', timeOfDayToMinutes(bedtime.value!));
    }
    if (waketime.value != null) {
      prefs.setInt('waketime', timeOfDayToMinutes(waketime.value!));
    }

    await prefs.setBool('sleepGoalbool', true);
  }

  Future<void> updateSleepTimestoServer(
    TimeOfDay bedTime,
    TimeOfDay wakeTime,
  ) async {
    try {
      debugPrint("🟢 updateSleepTimestoServer called");
      debugPrint("🛏️ BedTime (TimeOfDay): $bedTime");
      debugPrint("⏰ WakeTime (TimeOfDay): $wakeTime");

      final payload = {
        'Day': DateTime.now().day,
        'Month': DateTime.now().month,
        'Year': DateTime.now().year,
        'Time': TimeOfDay.now().format(Get.context!),
        'SleepingFrom': timeOfDayToString(bedTime),
        'SleepingTo': timeOfDayToString(wakeTime),
      };

      debugPrint("📦 Payload being sent to server:");
      payload.forEach((k, v) => debugPrint("   👉 $k : $v"));

      debugPrint("🌍 API Endpoint: $sleepGoal");

      final response = await ApiService.post(
        sleepGoalAPI,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      debugPrint("📥 Raw API Response: $response");

      if (response is http.Response) {
        debugPrint("❌ Response is http.Response (failure case)");
        debugPrint("StatusCode: ${response.statusCode}");
        debugPrint("Body: ${response.body}");

        CustomSnackbar.showError(
          context: Get.context!,
          title: 'Error',
          message: 'Failed to update sleep times to server.',
        );
      } else {
        debugPrint("✅ Sleep times updated to server successfully");
      }
    } catch (e, stack) {
      debugPrint("🔥 Exception while updating sleep times");
      debugPrint("Error: $e");
      debugPrint("StackTrace: $stack");

      CustomSnackbar.showError(
        context: Get.context!,
        title: "Error",
        message: "Failed to update sleep times to server.",
      );
    }
  }

  Future<void> uploadsleepdatatoServer(
    DateTime bedDateTime,
    DateTime wakeDateTime,
  ) async {
    try {
      // Normalize wake across midnight
      DateTime wake = wakeDateTime;
      if (wake.isBefore(bedDateTime) || wake.isAtSameMomentAs(bedDateTime)) {
        wake = wake.add(const Duration(days: 1));
      }

      final duration = wake.difference(bedDateTime);
      if (duration.inMinutes < 10) {
        debugPrint("⛔ Sleep too short, skipping upload");
        return;
      }

      // 🔐 Dedup by BED DATE
      final prefs = await SharedPreferences.getInstance();
      final bedKey = dateKey(bedDateTime);
      final lastUploaded = prefs.getString(_lastUploadedSleepDateKey);

      if (lastUploaded == bedKey) {
        debugPrint("⏭️ Sleep already uploaded for $bedKey");
        return;
      }

      final payload = {
        "Day": bedDateTime.day,
        "Month": bedDateTime.month,
        "Year": bedDateTime.year,
        "Time": TimeOfDay.fromDateTime(wake).format(Get.context!),
        "SleepingFrom": timeOfDayToString(TimeOfDay.fromDateTime(bedDateTime)),
        "SleepingTo": timeOfDayToString(TimeOfDay.fromDateTime(wake)),
      };

      debugPrint("🛰️ Uploading sleep payload: $payload");

      final response = await ApiService.post(
        sleepGoalAPI,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response) {
        CustomSnackbar.showError(
          context: Get.context!,
          title: 'Error',
          message: 'Failed to upload sleep data.',
        );
        return;
      }

      await prefs.setString(_lastUploadedSleepDateKey, bedKey);
      debugPrint("✅ Sleep uploaded for bed date $bedKey");
    } catch (e) {
      debugPrint("🔥 Sleep upload error: $e");
    }
  }

  Future<void> loadDeepSleepData() async {
    final _box = await Hive.openBox<SleepLog>('sleep_log');
    debugPrint("📥 [loadDeepSleepData] START");

    weeklyDeepSleepHistory.clear();
    final prefs = await SharedPreferences.getInstance();

    debugPrint("📦 Hive entries count: ${_box.length}");

    for (final log in _box.values) {
      final key = dateKey(log.date);
      // Prefer corrected minutes stored in prefs (if any), else use Hive minutes.
      final correctedMins = prefs.getInt(_correctedPrefKeyForDateKey(key));
      final duration = Duration(minutes: correctedMins ?? log.durationMinutes);

      weeklyDeepSleepHistory[key] = duration;

      print("loadDeepSleepData ${deepSleepDuration.value}");

      debugPrint("   💤 Weekly ← Hive: $key → ${duration.inMinutes} min");
    }

    // 🔥 Set UI value for *today* (not last Hive entry)
    final todayKey = getCurrentDayKey();
    deepSleepDuration.value = weeklyDeepSleepHistory[todayKey] ?? Duration.zero;

    // #region agent log
    AgentDebugLogger.log(
      runId: 'sleep-ui',
      hypothesisId: 'UI',
      location: 'sleep_controller.dart:loadDeepSleepData:today_value',
      message: 'Loaded sleep durations and set today deepSleepDuration',
      data: {
        'todayKey': todayKey,
        'todayMinutes': deepSleepDuration.value.inMinutes,
        'entries': _box.length,
      },
    );
    // #endregion

    print(
      "loadDeepSleepData deepSleepDuration.value ${deepSleepDuration.value}",
    );

    weeklyDeepSleepHistory.refresh();
    updateDeepSleepSpots();
  }

  Duration? get idealWakeupDuration {
    return Duration(minutes: 720);
  }

  List<FlSpot> getMonthlyDeepSleepSpots(DateTime month) {
    print("📅 [MonthlyGraph] Requested month: ${month.year}-${month.month}");

    final int totalDays =
        (month.year == DateTime.now().year &&
                month.month == DateTime.now().month)
            ? DateTime.now()
                .day // 🔥 only till today
            : daysInMonth(month.year, month.month);

    print("📆 [MonthlyGraph] Total days to plot: $totalDays");
    print("🗂️ [MonthlyGraph] monthlyDeepSleepHistory keys:");
    monthlyDeepSleepHistory.keys.forEach((k) => print("   • $k"));

    List<FlSpot> spots = [];

    for (int day = 1; day <= totalDays; day++) {
      final date = DateTime(month.year, month.month, day);
      final key = dateKey(date);

      print("➡️ [Day $day] Checking key: $key");

      if (monthlyDeepSleepHistory.containsKey(key)) {
        final duration = monthlyDeepSleepHistory[key]!;
        final hours = duration.inMinutes / 60.0;

        print(
          "   ✅ FOUND → Duration: $duration | Minutes: ${duration.inMinutes} | Hours: $hours",
        );

        spots.add(FlSpot((day - 1).toDouble(), hours));
      } else {
        print("   ❌ NOT FOUND → Using 0.0 hours");
        spots.add(FlSpot((day - 1).toDouble(), 0.0));
      }
    }

    print("📈 [MonthlyGraph] Generated FlSpots:");
    for (final s in spots) {
      print("   • x=${s.x}, y=${s.y}");
    }

    print("✅ [MonthlyGraph] Total spots generated: ${spots.length}");

    return spots;
  }

  Future<List<FlSpot>> loadSleepfromAPI({
    required int month,
    required int year,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = {"Month": month, "Year": year};

      final response = await ApiService.post(
        fetchSleepHistory,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response) {
        CustomSnackbar.showError(
          context: Get.context!,
          title: 'Error',
          message: 'Failed to fetch sleep data',
        );
        return [];
      }

      final decoded = response as Map<String, dynamic>;
      print('decoded response: $decoded');

      final sleepData = decoded['data']?['SleepData'] ?? [];

      print("🛌 Fetched sleep data for $month/$year: $sleepData");
      monthlyDeepSleepHistory.clear();

      for (final item in sleepData) {
        // Ensure values are integers
        final int day =
            int.tryParse(item['Day'].toString()) ?? 0; // Convert to int
        final int month =
            int.tryParse(item['Month'].toString()) ?? 0; // Convert to int
        final int year =
            int.tryParse(item['Year'].toString()) ?? 0; // Convert to int

        final String from = item['SleepingFrom'];
        final String to = item['SleepingTo'];

        DateTime bedTime = _parseTime(year, month, day, from);
        DateTime wakeTime = _parseTime(year, month, day, to);

        // 🌙 If wake time is next day
        if (wakeTime.isBefore(bedTime)) {
          wakeTime = wakeTime.add(const Duration(days: 1));
        }

        final duration = wakeTime.difference(bedTime);

        final key = dateKey(DateTime(year, month, day));
        monthlyDeepSleepHistory[key] = duration;
        // Persist corrected minutes for this day so UI can show the corrected value.
        await prefs.setInt(
          _correctedPrefKeyForDateKey(key),
          duration.inMinutes,
        );
        final currentWeekStart = DateTime.now().subtract(
          Duration(days: DateTime.now().weekday - 1),
        );
        final currentWeekEnd = currentWeekStart.add(Duration(days: 6));
        final itemDate = DateTime(year, month, day);

        if (itemDate.isAfter(currentWeekStart.subtract(Duration(days: 1))) &&
            itemDate.isBefore(currentWeekEnd.add(Duration(days: 1)))) {
          weeklyDeepSleepHistory[key] = duration;
        }
      }

      if (sleepData.isNotEmpty) {
        final latestSleep = sleepData.first;

        bedtime.value = minutesToTimeOfDay(
          _parseTime(
                    year,
                    month,
                    latestSleep['Day'],
                    latestSleep['SleepingFrom'],
                  ).hour *
                  60 +
              _parseTime(
                year,
                month,
                latestSleep['Day'],
                latestSleep['SleepingFrom'],
              ).minute,
        );

        waketime.value = minutesToTimeOfDay(
          _parseTime(
                    year,
                    month,
                    latestSleep['Day'],
                    latestSleep['SleepingTo'],
                  ).hour *
                  60 +
              _parseTime(
                year,
                month,
                latestSleep['Day'],
                latestSleep['SleepingTo'],
              ).minute,
        );
      }

      // 🔁 Refresh weekly graph too
      updateDeepSleepSpots();
      savesleepToLocalStorage();

      final int totalDays =
          (year == year && month == month)
              ? DateTime.now()
                  .day // 🔥 only till today
              : daysInMonth(year, month);

      List<FlSpot> spots = [];

      for (int day = 1; day <= totalDays; day++) {
        final key = dateKey(DateTime(year, month, day));

        if (monthlyDeepSleepHistory.containsKey(key)) {
          final hours = monthlyDeepSleepHistory[key]!.inMinutes / 60.0;
          spots.add(FlSpot((day - 1).toDouble(), hours));
        } else {
          spots.add(FlSpot((day - 1).toDouble(), 0.0));
        }
      }
      print("✅ Sleep history loaded: $weeklyDeepSleepHistory");

      return spots;
    } catch (e) {
      print("❌ Error loading sleep data: $e");
      return [];
    }
  }

  Future<void> loadMonthlySleep({required int month, required int year}) async {
    isMonthlyView.value = true;

    try {
      final spots = await loadSleepfromAPI(month: month, year: year);
      monthlySleepSpots
        ..value = spots
        ..refresh();
    } catch (e) {
      debugPrint('❌ loadMonthlySleep error: $e');
    }
  }

  Future<void> saveDeepSleepData(
    DateTime bedDate,
    Duration duration, {
    bool overwrite = true,
  }) async {
    final _box = await Hive.openBox<SleepLog>('sleep_log');
    final key = dateKey(bedDate);

    debugPrint("💾 [saveDeepSleepData]");
    debugPrint("   Key: $key");
    debugPrint("   Duration (min): ${duration.inMinutes}");

    // If not overwriting and already exists, skip
    if (!overwrite && _box.containsKey(key)) {
      debugPrint("⛔ Already exists in Hive for $key and overwrite == false");
      return;
    }

    // Put always (put will overwrite existing key if present)
    await _box.put(
      key,
      SleepLog(
        date: DateTime(bedDate.year, bedDate.month, bedDate.day),
        durationMinutes: duration.inMinutes,
      ),
    );

    print("✅ HIVE SAVED: $key → ${duration.inMinutes} min");

    // Persist corrected minutes in SharedPreferences for quick UI access.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_correctedPrefKeyForDateKey(key), duration.inMinutes);

    // #region agent log
    AgentDebugLogger.log(
      runId: 'sleep-ui',
      hypothesisId: 'PREF',
      location: 'sleep_controller.dart:saveDeepSleepData:persist_corrected',
      message: 'Saved corrected sleep minutes to prefs',
      data: {'key': key, 'minutes': duration.inMinutes},
    );
    // #endregion

    weeklyDeepSleepHistory[key] = duration;

    deepSleepDuration.value = weeklyDeepSleepHistory[key] ?? Duration.zero;
    weeklyDeepSleepHistory.refresh();
    updateDeepSleepSpots();
  }

  String getCurrentDayKey() {
    final date = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  void updateDeepSleepSpots() {
    debugPrint("📊 [updateDeepSleepSpots] called");

    final weekStart = DateTime.now().subtract(
      Duration(days: DateTime.now().weekday - 1),
    );
    final List<FlSpot> spots = [];

    for (int i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      final key = dateKey(date);

      final minutes = weeklyDeepSleepHistory[key]?.inMinutes ?? 0;
      final hours = minutes / 60.0;

      spots.add(FlSpot(i.toDouble(), hours));
    }

    deepSleepSpots
      ..value = spots
      ..refresh();

    debugPrint("✅ Weekly graph updated");
  }

  DateTime getWakeUpTime(TimeOfDay waketime) {
    final now = DateTime.now();
    DateTime wake = DateTime(
      now.year,
      now.month,
      now.day,
      waketime.hour,
      waketime.minute,
    );

    if (wake.isBefore(now)) {
      wake = wake.add(const Duration(days: 1));
    }

    return wake;
  }

  Future<void> clearSleepData() async {
    final _box = await Hive.openBox<SleepLog>('sleep_log');
    await _box.clear();
    weeklyDeepSleepHistory.clear();
    deepSleepSpots.clear();
    debugPrint("🗑️ All sleep data cleared from Hive and controller.");
  }

  // ─────────────────────────────────────────────
  // MONITORING
  // ─────────────────────────────────────────────

  DateTime resolveSleepStart(DateTime now) {
    final bt = bedtime.value!;
    DateTime start = buildDateTime(now, bt);

    // If bedtime is in the future, it belongs to yesterday
    if (start.isAfter(now.add(const Duration(minutes: 5)))) {
      // small grace
      start = start.subtract(const Duration(days: 1));
    }

    return start;
  }

  DateTime resolveSleepEnd(DateTime sleepStart) {
    final wt = waketime.value!;
    DateTime end = buildDateTime(sleepStart, wt);

    if (!end.isAfter(sleepStart)) {
      end = end.add(const Duration(days: 1));
    }

    return end;
  }

  Future<void> startMonitoring() async {}
}
