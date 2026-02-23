import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:get/get.dart';
import 'package:get/get_connect/http/src/response/response.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/common/custom_snackbar.dart';
import 'package:snevva/env/env.dart';
import 'package:snevva/models/awake_interval.dart';
import 'package:snevva/services/api_service.dart';
import 'package:snevva/common/agent_debug_logger.dart';
import 'package:snevva/services/hive_service.dart';
import '../../common/global_variables.dart';
import '../../models/hive_models/sleep_log.dart';

enum SleepState { sleeping, awake }

class SleepController extends GetxService {
  // ✅ FIX: Single storage key set — SharedPreferences only, no GetStorage
  static const String BEDTIME_KEY = 'user_bedtime_ms';
  static const String WAKETIME_KEY = 'user_waketime_ms';

  // Observable state
  final Rx<Duration> currentSleepDuration = Duration.zero.obs;
  final Rx<Duration> sleepGoal = const Duration(hours: 8).obs;
  final RxBool isSleeping = false.obs;
  final Rx<DateTime?> sleepStartTime = Rxn<DateTime>();
  final RxDouble sleepProgress = 0.0.obs;

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

  final RxMap<String, Duration> weeklyDeepSleepHistory =
      <String, Duration>{}.obs;
  final RxMap<String, Duration> monthlyDeepSleepHistory =
      <String, Duration>{}.obs;

  final RxList<FlSpot> deepSleepSpots = <FlSpot>[].obs;
  final List<AwakeInterval> phoneUsageIntervals = [];

  static const String _lastUploadedSleepDateKey =
      "last_uploaded_sleep_bed_date";

  // ─────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    _loadUserSleepTimes();
    _loadWeeklySleepData();
    _setupBackgroundServiceListeners();
    _checkIfAlreadySleeping();
    loadDeepSleepData();
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
    _sleepUpdateSubscription = _service.on("sleep_update").listen((event) {
      if (event != null) {
        final elapsedMinutes = event['elapsed_minutes'] as int? ?? 0;
        final goalMinutes = event['goal_minutes'] as int? ?? 480;
        final sleeping = event['is_sleeping'] as bool? ?? false;
        final windowKey = event['current_sleep_window_key'] as String?;
        final startTimeStr = event['start_time'] as String?;

        currentSleepDuration.value = Duration(minutes: elapsedMinutes);
        sleepGoal.value = Duration(minutes: goalMinutes);
        isSleeping.value = sleeping;

        if (startTimeStr != null && sleepStartTime.value == null) {
          sleepStartTime.value = DateTime.tryParse(startTimeStr);
        }

        if (goalMinutes > 0) {
          sleepProgress.value = (elapsedMinutes / goalMinutes).clamp(0.0, 1.0);

          String targetKey;
          if (windowKey != null) {
            targetKey = windowKey;
          } else if (sleepStartTime.value != null) {
            targetKey = _dateKey(sleepStartTime.value!);
          } else {
            final now = DateTime.now();
            targetKey =
                "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
          }

          weeklySleepHistory[targetKey] = currentSleepDuration.value;
          updateDeepSleepSpots();
        }

        print(
          "💤 Sleep update: ${elapsedMinutes}m / ${goalMinutes}m (${(sleepProgress.value * 100).toInt()}%)",
        );
      }
    });

    _sleepSavedSubscription = _service.on("sleep_saved").listen((event) async {
      if (event != null) {
        final duration = event['duration'] as int? ?? 0;
        final goalMinutes = event['goal_minutes'] as int? ?? 480;

        print("✅ Sleep saved: ${duration}m (goal: ${goalMinutes}m)");

        isSleeping.value = false;
        currentSleepDuration.value = Duration.zero;
        sleepProgress.value = 0.0;
        sleepStartTime.value = null;

        await _loadWeeklySleepData();
        await loadDeepSleepData();

        Get.snackbar(
          '😴 Sleep Recorded',
          'You slept for ${_formatDuration(Duration(minutes: duration))}',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
        );
      }
    });

    _goalReachedSubscription = _service.on("sleep_goal_reached").listen((
      event,
    ) {
      if (event != null) {
        final elapsedMinutes = event['elapsed_minutes'] as int? ?? 0;
        final goalMinutes = event['goal_minutes'] as int? ?? 480;

        print("🎉 Sleep goal reached! ${elapsedMinutes}m / ${goalMinutes}m");

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

  Future<void> startSleep({Duration? goal}) async {
    if (isSleeping.value) {
      print("⚠️ Sleep tracking already active");
      return;
    }

    final goalDuration = goal ?? sleepGoal.value;
    final goalMinutes = goalDuration.inMinutes;

    isSleeping.value = true;
    sleepStartTime.value = DateTime.now();
    sleepGoal.value = goalDuration;
    currentSleepDuration.value = Duration.zero;
    sleepProgress.value = 0.0;

    _service.invoke("start_sleep", {"goal_minutes": goalMinutes});

    print("🌙 Sleep tracking started with goal: ${goalMinutes}m");
  }

  Future<void> stopSleep() async {
    if (!isSleeping.value) {
      print("⚠️ No active sleep tracking");
      return;
    }

    _service.invoke("stop_sleep");
    print("☀️ Sleep tracking stopped");
  }

  void setSleepGoal(Duration goal) {
    sleepGoal.value = goal;

    if (isSleeping.value) {
      SharedPreferences.getInstance().then(
        (p) => p.setInt("sleep_goal_minutes", goal.inMinutes),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // SLEEP SCHEDULE METHODS
  // ═══════════════════════════════════════════════════════════════

  /// ✅ FIX: setBedtime now writes ONLY to SharedPreferences.
  /// Removed GetStorage to eliminate the 'flutter.' prefix key collision.
  void setBedtime(TimeOfDay time) {
    bedtime.value = time;
    final minutes = _timeOfDayToMinutes(time);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt(BEDTIME_KEY, minutes);
    });
    print('🛏️ Bedtime set → $time ($minutes min)');
  }

  /// ✅ FIX: setWakeTime now writes ONLY to SharedPreferences.
  void setWakeTime(TimeOfDay time) {
    waketime.value = time;
    final minutes = _timeOfDayToMinutes(time);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt(WAKETIME_KEY, minutes);
    });
    print('⏰ Waketime set → $time ($minutes min)');
  }

  // ═══════════════════════════════════════════════════════════════
  // DATA LOADING METHODS
  // ═══════════════════════════════════════════════════════════════

  /// ✅ FIX: _loadUserSleepTimes now reads ONLY from SharedPreferences.
  Future<void> _loadUserSleepTimes() async {
    final prefs = await SharedPreferences.getInstance();
    final bedMin = prefs.getInt(BEDTIME_KEY);
    final wakeMin = prefs.getInt(WAKETIME_KEY);

    if (bedMin != null) bedtime.value = _minutesToTimeOfDay(bedMin);
    if (wakeMin != null) waketime.value = _minutesToTimeOfDay(wakeMin);

    debugPrint('📥 Loaded sleep times — bed: $bedMin, wake: $wakeMin');
  }

  /// ✅ FIX: loadUserSleepTimes (public) also reads only from SharedPreferences.
  Future<void> loadUserSleepTimes() async {
    await _loadUserSleepTimes();
  }

  Future<void> _loadWeeklySleepData() async {
    try {
      final box = HiveService().sleepLog;
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
          // ✅ FIX: Don't use raw elapsed time as sleep duration — it's misleading.
          // Only restore UI state; the background service will send real sleep_update events.
          isSleeping.value = true;
          sleepStartTime.value = start;
          sleepGoal.value = Duration(minutes: goalMinutes);
          // Leave currentSleepDuration as zero — background service will update it shortly.

          print("🔄 Restored active sleep session state (awaiting BG update)");
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
    if (hours > 0) return "${hours}h ${minutes}m";
    return "${minutes}m";
  }

  String getSleepStatus(Duration? duration) {
    if (duration == null || duration.inMinutes <= 0) return '';
    final hours = duration.inMinutes / 60;
    if (hours < 4) return 'Very Poor';
    if (hours < 5.5) return 'Poor';
    if (hours < 7) return 'Okay';
    if (hours < 8.5) return 'Good';
    return 'Excellent';
  }

  Duration? getSleepForDate(DateTime date) {
    final key = _dateKey(date);
    return weeklySleepHistory[key];
  }

  bool hasSleepDataForDate(DateTime date) {
    return weeklySleepHistory.containsKey(_dateKey(date));
  }

  Duration get averageWeeklySleep {
    if (weeklySleepHistory.isEmpty) return Duration.zero;
    final total = weeklySleepHistory.values.fold<int>(
      0,
      (sum, d) => sum + d.inMinutes,
    );
    return Duration(minutes: total ~/ weeklySleepHistory.length);
  }

  Future<void> refreshData() async {
    await _loadWeeklySleepData();
  }

  DateTime resolveNextWakeDateTime() {
    final wt = waketime.value!;
    final now = DateTime.now();
    DateTime wake = DateTime(now.year, now.month, now.day, wt.hour, wt.minute);
    if (wake.isBefore(now)) wake = wake.add(const Duration(days: 1));
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

  DateTime buildDateTime(DateTime base, TimeOfDay tod) {
    return DateTime(base.year, base.month, base.day, tod.hour, tod.minute);
  }

  String dateKey(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  String _correctedPrefKeyForDateKey(String dayKey) =>
      "$_correctedSleepMinutesPrefix$dayKey";

  Future<Duration> getCorrectedSleepForDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final key = dateKey(DateUtils.dateOnly(date));
    final mins = prefs.getInt(_correctedPrefKeyForDateKey(key));
    if (mins != null) return Duration(minutes: mins);
    return weeklyDeepSleepHistory[key] ?? Duration.zero;
  }

  String timeOfDayToString(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  DateTime normalizeForward(DateTime base, DateTime candidate) {
    DateTime c = candidate;
    while (!c.isAfter(base) && !c.isAtSameMomentAs(base)) {
      c = c.add(const Duration(days: 1));
    }
    return c;
  }

  Map<String, Duration> calculateSplitDeepSleep({
    required DateTime oldBedtime,
    required DateTime oldWakeTime,
    required DateTime phonePickupTime,
    required DateTime newBedtime,
  }) {
    DateTime seg1Start = oldBedtime;
    DateTime seg1End = phonePickupTime;
    if (seg1End.isBefore(seg1Start) || seg1End.isAtSameMomentAs(seg1Start)) {
      seg1End = seg1End.add(const Duration(days: 1));
    }

    DateTime seg2Start = newBedtime;
    DateTime seg2End = oldWakeTime;
    if (seg2End.isBefore(seg2Start) || seg2End.isAtSameMomentAs(seg2Start)) {
      seg2End = seg2End.add(const Duration(days: 1));
    }

    Duration beforePhone = seg1End.difference(seg1Start);
    Duration afterPhone = seg2End.difference(seg2Start);

    if (beforePhone.isNegative) beforePhone = Duration.zero;
    if (afterPhone.isNegative) afterPhone = Duration.zero;

    return {
      'beforePhone': beforePhone,
      'afterPhone': afterPhone,
      'total': beforePhone + afterPhone,
    };
  }

  DateTime _parseTime(int year, int month, int day, String time) {
    final parts = time.split(':');
    return DateTime(year, month, day, int.parse(parts[0]), int.parse(parts[1]));
  }

  Future<void> savesleepToLocalStorage() async {
    final prefs = await SharedPreferences.getInstance();
    if (bedtime.value != null) {
      prefs.setInt(BEDTIME_KEY, timeOfDayToMinutes(bedtime.value!));
    }
    if (waketime.value != null) {
      prefs.setInt(WAKETIME_KEY, timeOfDayToMinutes(waketime.value!));
    }
    await prefs.setBool('sleepGoalbool', true);
  }

  Future<void> updateSleepTimestoServer(
    TimeOfDay bedTime,
    TimeOfDay wakeTime,
  ) async {
    try {
      debugPrint("🟢 updateSleepTimestoServer called");

      final payload = {
        'Day': DateTime.now().day,
        'Month': DateTime.now().month,
        'Year': DateTime.now().year,
        'Time': TimeOfDay.now().format(Get.context!),
        'SleepingFrom': timeOfDayToString(bedTime),
        'SleepingTo': timeOfDayToString(wakeTime),
      };

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
          message: 'Failed to update sleep times to server.',
        );
      } else {
        debugPrint("✅ Sleep times updated to server successfully");
      }
    } catch (e, stack) {
      debugPrint("🔥 Exception while updating sleep times: $e");
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
      DateTime wake = wakeDateTime;
      if (wake.isBefore(bedDateTime) || wake.isAtSameMomentAs(bedDateTime)) {
        wake = wake.add(const Duration(days: 1));
      }

      final duration = wake.difference(bedDateTime);
      if (duration.inMinutes < 10) {
        debugPrint("⛔ Sleep too short, skipping upload");
        return;
      }

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
    final box = HiveService().sleepLog;
    debugPrint("📥 [loadDeepSleepData] START");

    weeklyDeepSleepHistory.clear();
    final prefs = await SharedPreferences.getInstance();

    debugPrint("📦 Hive entries count: ${box.length}");

    for (final log in box.values) {
      final key = dateKey(log.date);
      final correctedMins = prefs.getInt(_correctedPrefKeyForDateKey(key));
      final duration = Duration(minutes: correctedMins ?? log.durationMinutes);

      weeklyDeepSleepHistory[key] = duration;
      debugPrint("   💤 Weekly ← Hive: $key → ${duration.inMinutes} min");
    }

    final todayKey = getCurrentDayKey();
    final yesterdayKey = dateKey(
      DateTime.now().subtract(const Duration(days: 1)),
    );

    if ((weeklyDeepSleepHistory[todayKey]?.inMinutes ?? 0) > 0) {
      deepSleepDuration.value = weeklyDeepSleepHistory[todayKey]!;
    } else if ((weeklyDeepSleepHistory[yesterdayKey]?.inMinutes ?? 0) > 0) {
      deepSleepDuration.value = weeklyDeepSleepHistory[yesterdayKey]!;
    } else {
      deepSleepDuration.value = Duration.zero;
    }

    AgentDebugLogger.log(
      runId: 'sleep-ui',
      hypothesisId: 'UI',
      location: 'sleep_controller.dart:loadDeepSleepData:today_value',
      message: 'Loaded sleep durations and set today deepSleepDuration',
      data: {
        'todayKey': todayKey,
        'todayMinutes': deepSleepDuration.value.inMinutes,
        'entries': box.length,
      },
    );

    weeklyDeepSleepHistory.refresh();
    updateDeepSleepSpots();
  }

  Duration? get idealWakeupDuration => const Duration(minutes: 720);

  List<FlSpot> getMonthlyDeepSleepSpots(DateTime month) {
    final int totalDays =
        (month.year == DateTime.now().year &&
                month.month == DateTime.now().month)
            ? DateTime.now().day
            : daysInMonth(month.year, month.month);

    List<FlSpot> spots = [];

    for (int day = 1; day <= totalDays; day++) {
      final date = DateTime(month.year, month.month, day);
      final key = dateKey(date);

      if (monthlyDeepSleepHistory.containsKey(key)) {
        final duration = monthlyDeepSleepHistory[key]!;
        spots.add(FlSpot((day - 1).toDouble(), duration.inMinutes / 60.0));
      } else {
        spots.add(FlSpot((day - 1).toDouble(), 0.0));
      }
    }

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
      final sleepData = decoded['data']?['SleepData'] ?? [];

      monthlyDeepSleepHistory.clear();

      for (final item in sleepData) {
        final int day = int.tryParse(item['Day'].toString()) ?? 0;
        final int itemMonth = int.tryParse(item['Month'].toString()) ?? 0;
        final int itemYear = int.tryParse(item['Year'].toString()) ?? 0;

        final String from = item['SleepingFrom'];
        final String to = item['SleepingTo'];

        DateTime bedTime = _parseTime(itemYear, itemMonth, day, from);
        DateTime wakeTime = _parseTime(itemYear, itemMonth, day, to);

        if (wakeTime.isBefore(bedTime)) {
          wakeTime = wakeTime.add(const Duration(days: 1));
        }

        final duration = wakeTime.difference(bedTime);
        final key = dateKey(DateTime(itemYear, itemMonth, day));
        monthlyDeepSleepHistory[key] = duration;

        await prefs.setInt(
          _correctedPrefKeyForDateKey(key),
          duration.inMinutes,
        );

        final currentWeekStart = DateTime.now().subtract(
          Duration(days: DateTime.now().weekday - 1),
        );
        final currentWeekEnd = currentWeekStart.add(const Duration(days: 6));
        final itemDate = DateTime(itemYear, itemMonth, day);

        if (itemDate.isAfter(
              currentWeekStart.subtract(const Duration(days: 1)),
            ) &&
            itemDate.isBefore(currentWeekEnd.add(const Duration(days: 1)))) {
          weeklyDeepSleepHistory[key] = duration;
        }
      }

      if (sleepData.isNotEmpty) {
        final latestSleep = sleepData.first;
        final int latestDay = int.tryParse(latestSleep['Day'].toString()) ?? 0;
        final int latestMonth =
            int.tryParse(latestSleep['Month'].toString()) ?? 0;
        final int latestYear =
            int.tryParse(latestSleep['Year'].toString()) ?? 0;

        bedtime.value = TimeOfDay.fromDateTime(
          _parseTime(
            latestYear,
            latestMonth,
            latestDay,
            latestSleep['SleepingFrom'],
          ),
        );
        waketime.value = TimeOfDay.fromDateTime(
          _parseTime(
            latestYear,
            latestMonth,
            latestDay,
            latestSleep['SleepingTo'],
          ),
        );
      }

      updateDeepSleepSpots();
      savesleepToLocalStorage();

      final int totalDays =
          (year == DateTime.now().year && month == DateTime.now().month)
              ? DateTime.now().day
              : daysInMonth(year, month);

      List<FlSpot> spots = [];
      for (int day = 1; day <= totalDays; day++) {
        final key = dateKey(DateTime(year, month, day));
        if (monthlyDeepSleepHistory.containsKey(key)) {
          spots.add(
            FlSpot(
              (day - 1).toDouble(),
              monthlyDeepSleepHistory[key]!.inMinutes / 60.0,
            ),
          );
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
    final box = HiveService().sleepLog;
    final key = dateKey(bedDate);

    debugPrint(
      "💾 [saveDeepSleepData] Key: $key, Duration: ${duration.inMinutes} min",
    );

    if (!overwrite && box.containsKey(key)) {
      debugPrint("⛔ Already exists for $key and overwrite == false");
      return;
    }

    await box.put(
      key,
      SleepLog(
        date: DateTime(bedDate.year, bedDate.month, bedDate.day),
        durationMinutes: duration.inMinutes,
      ),
    );

    print("✅ HIVE SAVED: $key → ${duration.inMinutes} min");

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_correctedPrefKeyForDateKey(key), duration.inMinutes);

    AgentDebugLogger.log(
      runId: 'sleep-ui',
      hypothesisId: 'PREF',
      location: 'sleep_controller.dart:saveDeepSleepData:persist_corrected',
      message: 'Saved corrected sleep minutes to prefs',
      data: {'key': key, 'minutes': duration.inMinutes},
    );

    weeklyDeepSleepHistory[key] = duration;
    deepSleepDuration.value = weeklyDeepSleepHistory[key] ?? Duration.zero;
    weeklyDeepSleepHistory.refresh();
    updateDeepSleepSpots();
  }

  String getCurrentDayKey() {
    final date = DateTime.now();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void updateDeepSleepSpots() {
    final weekStart = DateTime.now().subtract(
      Duration(days: DateTime.now().weekday - 1),
    );
    final List<FlSpot> spots = [];

    for (int i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      final key = dateKey(date);
      final minutes = weeklyDeepSleepHistory[key]?.inMinutes ?? 0;
      spots.add(FlSpot(i.toDouble(), minutes / 60.0));
    }

    deepSleepSpots
      ..value = spots
      ..refresh();
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
    if (wake.isBefore(now)) wake = wake.add(const Duration(days: 1));
    return wake;
  }

  Future<void> clearSleepData() async {
    final box = HiveService().sleepLog;
    await box.clear();
    weeklyDeepSleepHistory.clear();
    deepSleepSpots.clear();
    debugPrint("🗑️ All sleep data cleared from Hive and controller.");
  }

  DateTime resolveSleepStart(DateTime now) {
    final bt = bedtime.value!;
    DateTime start = buildDateTime(now, bt);
    if (start.isAfter(now.add(const Duration(minutes: 5)))) {
      start = start.subtract(const Duration(days: 1));
    }
    return start;
  }

  DateTime resolveSleepEnd(DateTime sleepStart) {
    final wt = waketime.value!;
    DateTime end = buildDateTime(sleepStart, wt);
    if (!end.isAfter(sleepStart)) end = end.add(const Duration(days: 1));
    return end;
  }
}
