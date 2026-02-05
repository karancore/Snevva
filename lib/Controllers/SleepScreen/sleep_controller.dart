import 'dart:async';
import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
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
import 'package:snevva/services/notification_service.dart';
import 'package:snevva/common/agent_debug_logger.dart';

import '../../common/global_variables.dart';

import '../../consts/images.dart';
import '../../models/hive_models/sleep_log.dart';
import '../../services/sleep/sleep_noticing_service.dart';

enum SleepState { sleeping, awake }

class SleepController extends GetxService {
  String BEDTIME_KEY = 'user_bedtime_ms';
  String WAKETIME_KEY = 'user_waketime_ms';
  static const _sleepCandidateStartKey = "sleep_candidate_start";
  static const _sleepCandidateHadPhoneUsageKey = "sleep_candidate_had_phone";
  static const _correctedSleepMinutesPrefix = "sleep_corrected_minutes_";

  /// User bedtime & waketime
  final Rxn<TimeOfDay> bedtime = Rxn<TimeOfDay>();
  final Rxn<TimeOfDay> waketime = Rxn<TimeOfDay>();
  DateTime? _activeSleepStart;



  SleepState _sleepState = SleepState.sleeping;
  DateTime? _currentSleepSegmentStart;




  // accumulated deep sleep for this night
  Duration _accumulatedDeepSleep = Duration.zero;

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

  final SleepNoticingService _sleepService = SleepNoticingService();
  Timer? _morningCheckTimer;
  bool _wasPhoneUsedDuringSleep = false;

  static const String _lastUploadedSleepDateKey =
      "last_uploaded_sleep_bed_date";

  var getStorage = GetStorage();

  // ─────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    _sleepService.onAwakeSegmentDetected = _onSleepDetected;
    _sleepService.onSleepResumed = (DateTime time) {
      _currentSleepSegmentStart = time;
      _sleepState = SleepState.sleeping;
    };


    loadDeepSleepData();
    loadUserSleepTimes();

    recoverMissedSleepIfNeeded();

  }





  Future<void> recoverMissedSleepIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();

    final startIso = prefs.getString(_sleepCandidateStartKey);
    if (startIso == null) return;

    if (bedtime.value == null || waketime.value == null) return;

    final sleepStart = DateTime.parse(startIso);
    final sleepEnd = resolveSleepEnd(sleepStart);
    final now = DateTime.now();

    // Wake time not reached yet
    if (now.isBefore(sleepEnd)) return;

    // Prevent duplicate upload
    final bedKey = dateKey(sleepStart);
    final lastUploaded = prefs.getString(_lastUploadedSleepDateKey);
    if (lastUploaded == bedKey) {
      await _clearSleepCandidate(prefs);
      return;
    }

    final hadPhoneUsage =
        prefs.getBool(_sleepCandidateHadPhoneUsageKey) ?? false;

    if (hadPhoneUsage) {
      await finalizeSleepCycleRetroactive(sleepStart, sleepEnd);
    } else {
      await _finalizeSleepWithoutPhoneRetroactive(sleepStart, sleepEnd);
    }

    await _clearSleepCandidate(prefs);
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
    if (deep.inSeconds < 10) return;

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
    if (deep.inSeconds < 10) return;

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

  // @override
  // void onClose() {
  //   _morningCheckTimer?.cancel();
  //   _sleepService.stopMonitoring();
  //   super.onClose();
  // }

  String getSleepStatus(Duration? duration) {
    if (duration == null || duration.inMinutes <= 0) return '';

    final hours = duration.inMinutes / 60;

    if (hours < 4) return 'Very Poor';
    if (hours < 5.5) return 'Poor';
    if (hours < 7) return 'Okay';
    if (hours < 8.5) return 'Good';
    return 'Excellent';
  }

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────

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

  bool hasSleepDataForDate(DateTime date) {
    return weeklyDeepSleepHistory.containsKey(dateKey(date));
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
    final bedMin = getStorage.read(BEDTIME_KEY);
    final wakeMin = getStorage.read(WAKETIME_KEY);

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
        sleepGoal,
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
      if (duration.inSeconds < 10) {
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
        sleepGoal,
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
        await prefs.setInt(_correctedPrefKeyForDateKey(key), duration.inMinutes);
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


  void _onSleepDetected(DateTime sleepStart, DateTime wakeUp) async {
    debugPrint("🌙  Sleep detected: $sleepStart → $wakeUp");
    // Do NOT finalize here. This event is triggered for screen-based awake segments.
    // Only process segment-specific logic. Finalization is handled by morning auto-check / alarm.
    if (_wasPhoneUsedDuringSleep) {
      // handle phone-usage based saving path when necessary (e.g., record segment)
      await _handleSleepSegmentDuringPhoneUsage(); // implement as needed
    } else {
      // you already have this helper — keep using it
      await _handleSleepWithoutPhoneUsageCustom(sleepStart, wakeUp);
    }
  }

  Future<void> _handleSleepSegmentDuringPhoneUsage() async {
    if (_activeSleepStart == null) return;
    if (phoneUsageIntervals.isEmpty) return;

    // 1️⃣ Merge overlapping awake intervals
    final mergedAwakeIntervals = mergeAwakeIntervals(phoneUsageIntervals);

    // 2️⃣ Latest awake end
    final lastAwakeEnd = mergedAwakeIntervals.last.end;

    // 3️⃣ Close current sleep segment
    if (_sleepState == SleepState.sleeping &&
        _currentSleepSegmentStart != null &&
        lastAwakeEnd.isAfter(_currentSleepSegmentStart!)) {
      final segmentDuration =
      lastAwakeEnd.difference(_currentSleepSegmentStart!);

      deepSleepDuration.value += segmentDuration;
    }

    // 4️⃣ Resume sleep after phone usage
    _currentSleepSegmentStart = lastAwakeEnd;
    _sleepState = SleepState.sleeping;

    debugPrint(
      "📵 Phone wake handled → segment added, deepSleepDuration=$deepSleepDuration",
    );
  }

  // Helper that allows custom sleep times
  Future<void> _handleSleepWithoutPhoneUsageCustom(
    DateTime sleepStart,
    DateTime sleepEnd,
  ) async {
    final deep = sleepEnd.difference(sleepStart);
    if (deep.inMinutes < 10) return;

    newBedtime.value = sleepStart;

    await saveDeepSleepData(sleepStart, deep);
    await uploadsleepdatatoServer(sleepStart, sleepEnd);

    debugPrint('✅ Auto-saved sleep without phone usage: $deep');
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

  Future<void> startMonitoring() async {
    phoneUsageIntervals.clear();
    _wasPhoneUsedDuringSleep = false;
    final prefs = await SharedPreferences.getInstance();

    if (bedtime.value != null) {
      final now = DateTime.now();
      final bt = resolveSleepStart(now);
      _activeSleepStart = bt;                      // <-- important
      _currentSleepSegmentStart = bt;              // start accumulating deep sleep from bed start
      _sleepState = SleepState.sleeping;
      await prefs.setString(_sleepCandidateStartKey, bt.toIso8601String());
      await prefs.setBool(_sleepCandidateHadPhoneUsageKey, false);
      
      // Clear any old sleep intervals for this sleep date
      final sleepDateKey = dateKey(bt);
      await prefs.remove('sleep_intervals_$sleepDateKey');
      await prefs.remove('last_screen_off_$sleepDateKey');
      debugPrint('🧹 Cleared old sleep intervals for $sleepDateKey');
    }

    await _scheduleWakeStop();
    _startMorningAutoCheck();
    _sleepService.startMonitoring();
  }
  Future<void> _scheduleWakeStop() async {
    if (waketime.value == null) return;

    final wakeDateTime = resolveNextWakeDateTime();

    debugPrint("⏰ Wake stop scheduled at $wakeDateTime");
  }

  void stopMonitoring() {
    _morningCheckTimer?.cancel();
    _sleepService.stopMonitoring();
  }

  void _startMorningAutoCheck() {
    _morningCheckTimer?.cancel();

    _morningCheckTimer = Timer.periodic(const Duration(minutes: 1), (
      timer,
    ) async {
      final now = DateTime.now();
      if (bedtime.value == null || waketime.value == null) return;

      final sleepStart = _activeSleepStart!;
      final sleepEnd = resolveSleepEnd(sleepStart);


      if (now.isAfter(sleepEnd)) {
        if (_wasPhoneUsedDuringSleep) {
          await finalizeSleepCycle();
          phoneUsageIntervals.clear();
          _wasPhoneUsedDuringSleep = false;

        } else {
          await _handleSleepWithoutPhoneUsage();
        }
        timer.cancel();
      }
    });
  }

  // ─────────────────────────────────────────────
  // AUTO SLEEP (NO PHONE)
  // ─────────────────────────────────────────────

  /// Calculate total sleep duration from screen OFF intervals stored in SharedPreferences
  /// Also handles the case where screen is still OFF at wakeup time
  Future<Duration> _calculateSleepDurationFromIntervals(DateTime sleepStart) async {
    final prefs = await SharedPreferences.getInstance();
    final sleepDateKey = dateKey(sleepStart);
    final intervalsKey = 'sleep_intervals_$sleepDateKey';
    
    final sleepEnd = resolveSleepEnd(sleepStart);
    
    // Check if there's an open interval (screen still OFF)
    // We'll check the background service state by looking for a recent screen OFF event
    // For now, we'll close any open interval at wakeup time
    final now = DateTime.now();
    if (now.isAfter(sleepEnd) || now.isAtSameMomentAs(sleepEnd)) {
      // Wakeup time reached, close any open interval
      final lastScreenOffKey = 'last_screen_off_$sleepDateKey';
      final lastScreenOffString = prefs.getString(lastScreenOffKey);
      
      if (lastScreenOffString != null) {
        try {
          final lastScreenOff = DateTime.parse(lastScreenOffString);
          // If screen was OFF before wakeup and we're past wakeup, close the interval
          if (lastScreenOff.isBefore(sleepEnd) || lastScreenOff.isAtSameMomentAs(sleepEnd)) {
            // Load existing intervals
            final existingIntervals = prefs.getString(intervalsKey);
            List<String> intervalStrings = [];
            if (existingIntervals != null && existingIntervals.isNotEmpty) {
              intervalStrings = existingIntervals.split(',');
            }
            
            // Check if last interval is still open (no end time or end is before wakeup)
            bool hasOpenInterval = false;
            if (intervalStrings.isNotEmpty) {
              final lastInterval = intervalStrings.last.split('|');
              if (lastInterval.length == 2) {
                try {
                  final lastEnd = DateTime.parse(lastInterval[1]);
                  if (lastEnd.isBefore(sleepEnd)) {
                    hasOpenInterval = true;
                  }
                } catch (e) {
                  // Invalid format, treat as open
                  hasOpenInterval = true;
                }
              } else {
                hasOpenInterval = true;
              }
            } else {
              // No intervals yet, create one from last screen off to wakeup
              hasOpenInterval = true;
            }
            
            if (hasOpenInterval) {
              // Close the interval at wakeup time
              final clampedStart = lastScreenOff.isBefore(sleepStart) ? sleepStart : lastScreenOff;
              final clampedEnd = sleepEnd;
              
              if (clampedStart.isBefore(clampedEnd)) {
                intervalStrings.add('${clampedStart.toIso8601String()}|${clampedEnd.toIso8601String()}');
                await prefs.setString(intervalsKey, intervalStrings.join(','));
                debugPrint('📊 Closed open interval at wakeup: ${clampedStart.hour}:${clampedStart.minute} - ${clampedEnd.hour}:${clampedEnd.minute}');
              }
            }
          }
        } catch (e) {
          debugPrint('⚠️ Failed to parse last screen off time: $e');
        }
      }
    }
    
    final intervalsString = prefs.getString(intervalsKey);
    if (intervalsString == null || intervalsString.isEmpty) {
      debugPrint('📊 No sleep intervals found for $sleepDateKey');
      return Duration.zero;
    }

    // Parse intervals: format is "start1|end1,start2|end2,..."
    final intervalStrings = intervalsString.split(',');
    final List<MapEntry<DateTime, DateTime>> intervals = [];
    
    for (final intervalStr in intervalStrings) {
      final parts = intervalStr.split('|');
      if (parts.length == 2) {
        try {
          final start = DateTime.parse(parts[0]);
          final end = DateTime.parse(parts[1]);
          intervals.add(MapEntry(start, end));
        } catch (e) {
          debugPrint('⚠️ Failed to parse interval: $intervalStr');
        }
      }
    }

    if (intervals.isEmpty) {
      debugPrint('📊 No valid sleep intervals found');
      return Duration.zero;
    }

    // Sort intervals by start time
    intervals.sort((a, b) => a.key.compareTo(b.key));

    // Merge overlapping intervals and calculate total duration
    Duration totalDuration = Duration.zero;
    DateTime? currentStart;
    DateTime? currentEnd;

    for (final interval in intervals) {
      if (currentStart == null) {
        // First interval
        currentStart = interval.key;
        currentEnd = interval.value;
      } else {
        // Check if intervals overlap or are adjacent (within 5 minutes)
        if (interval.key.isBefore(currentEnd!.add(const Duration(minutes: 5)))) {
          // Merge intervals
          if (interval.value.isAfter(currentEnd)) {
            currentEnd = interval.value;
          }
        } else {
          // Add previous interval to total
          totalDuration += currentEnd.difference(currentStart);
          // Start new interval
          currentStart = interval.key;
          currentEnd = interval.value;
        }
      }
    }

    // Add the last interval
    if (currentStart != null && currentEnd != null) {
      totalDuration += currentEnd.difference(currentStart);
    }

    debugPrint('📊 Calculated sleep duration from intervals: ${totalDuration.inMinutes} minutes');
    return totalDuration;
  }

  Future<void> _handleSleepWithoutPhoneUsage() async {
    // Compute a robust duration using tonight's configured bed/wake, normalize across midnight.
    if (bedtime.value == null || waketime.value == null) {
      debugPrint('⚠️ Bed/Wake not set, skipping autosave');
      return;
    }

    // Build the bed/wake for the intended cycle relative to bed date
    final bt = resolveSleepStart(DateTime.now());
    final wt = resolveSleepEnd(bt);

    // Calculate sleep duration from screen OFF intervals
    Duration deep = await _calculateSleepDurationFromIntervals(bt);
    
    // If no intervals found, fall back to full window duration
    if (deep == Duration.zero) {
      deep = wt.difference(bt);
      debugPrint('📊 Using full window duration as fallback: ${deep.inMinutes} minutes');
    }

    if (deep.inMinutes < 10) {
      debugPrint(
        '⛔ Skipping save: calculated duration too small (${deep.inMinutes}m)',
      );
      return;
    }

    newBedtime.value = bt;
    deepSleepDuration.value = deep;

    // Save against bed date for consistent history keys
    await saveDeepSleepData(bt, deep);

    // Push correct normalized times to server
    await uploadsleepdatatoServer(bt, wt);
    
    // Clear sleep intervals after saving
    final prefs = await SharedPreferences.getInstance();
    final sleepDateKey = dateKey(bt);
    await prefs.remove('sleep_intervals_$sleepDateKey');
    
    debugPrint('✅ Auto-saved sleep without phone usage: $deep');
  }

  // ─────────────────────────────────────────────
  // PHONE USAGE
  // ─────────────────────────────────────────────

  Future<void> onPhoneUsed(DateTime start, DateTime end) async {
    if (bedtime.value == null || waketime.value == null) return;

    // Prefer the active sleepStart (set when monitoring started). Fallback to resolveSleepStart(now).
    final sleepStart = _activeSleepStart ?? resolveSleepStart(DateTime.now());
    final sleepEnd = resolveSleepEnd(sleepStart);

    // Clamp usage inside sleep window
    final clampedStart = start.isBefore(sleepStart) ? sleepStart : start;
    final clampedEnd = end.isAfter(sleepEnd) ? sleepEnd : end;

    const int minUsageSeconds = 300; // 5 minutes – adjust to taste
    if (clampedEnd.difference(clampedStart).inSeconds < minUsageSeconds) return;

    // If we were sleeping and had an open sleep segment, close it at clampedStart
    if (_sleepState == SleepState.sleeping && _currentSleepSegmentStart != null) {
      // Crucial: use the clampedStart here to avoid overcounting deep sleep
      _accumulatedDeepSleep += clampedStart.difference(_currentSleepSegmentStart!);
      _sleepState = SleepState.awake;
    }

    _wasPhoneUsedDuringSleep = true;
    phoneUsageIntervals.add(AwakeInterval(clampedStart, clampedEnd));

    _currentSleepSegmentStart = clampedEnd;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sleepCandidateHadPhoneUsageKey, true);
  }

  List<AwakeInterval> mergeAwakeIntervals(List<AwakeInterval> intervals) {
    if (intervals.isEmpty) return [];

    // Use a sorted copy so original list isn't mutated elsewhere
    final sorted = [...intervals]..sort((a, b) => a.start.compareTo(b.start));
    final List<AwakeInterval> merged = [];

    AwakeInterval current = sorted.first;
    for (int i = 1; i < sorted.length; i++) {
      final next = sorted[i];

      // Overlap OR touching intervals → merge
      if (!next.start.isAfter(current.end)) {
        current = AwakeInterval(
          current.start,
          next.end.isAfter(current.end) ? next.end : current.end,
        );
      } else {
        merged.add(current);
        current = next;
      }
    }

    merged.add(current);
    return merged;
  }


  Future<void> finalizeSleepCycle() async {
    if (bedtime.value == null || waketime.value == null) return;
    if (_activeSleepStart == null) return; // safety

    final sleepStart = _activeSleepStart!;
    final sleepEnd = resolveSleepEnd(sleepStart);

    // Calculate sleep duration from screen OFF intervals
    Duration deepSleep = await _calculateSleepDurationFromIntervals(sleepStart);
    
    // If intervals exist, use them; otherwise use accumulated deep sleep
    if (deepSleep == Duration.zero) {
      // Fall back to accumulated deep sleep logic
      if (_sleepState == SleepState.sleeping && _currentSleepSegmentStart != null) {
        _accumulatedDeepSleep += sleepEnd.difference(_currentSleepSegmentStart!);
      }
      deepSleep = _accumulatedDeepSleep;
    }

    deepSleepDuration.value = deepSleep;

    // guard: too short or negative
    if (deepSleep.isNegative || deepSleep.inMinutes < 10) {
      // ensure we clear state to avoid leaking into next cycle
      phoneUsageIntervals.clear();
      _wasPhoneUsedDuringSleep = false;
      _accumulatedDeepSleep = Duration.zero;
      _currentSleepSegmentStart = null;
      _sleepState = SleepState.awake;
      return;
    }

    // persist
    await saveDeepSleepData(sleepStart, deepSleep);
    deepSleepDuration.value = deepSleep;
    await uploadsleepdatatoServer(sleepStart, sleepEnd);

    // Clear sleep intervals after saving
    final prefs = await SharedPreferences.getInstance();
    final sleepDateKey = dateKey(sleepStart);
    await prefs.remove('sleep_intervals_$sleepDateKey');

    // clear runtime state for next cycle
    phoneUsageIntervals.clear();
    _wasPhoneUsedDuringSleep = false;
    _accumulatedDeepSleep = Duration.zero;
    _currentSleepSegmentStart = null;
    _sleepState = SleepState.awake;

    debugPrint("😴  Final sleep calculated: $deepSleep");
  }
  // void onAwakeDetected(DateTime start, DateTime end) {
  //   if (_sleepState == SleepState.sleeping) {
  //     _accumulatedDeepSleep += start.difference(_currentSleepSegmentStart!);
  //     _sleepState = SleepState.awake;
  //   }
  // }


  // ─────────────────────────────────────────────
  // SETTERS
  // ─────────────────────────────────────────────

  void setBedtime(TimeOfDay time) {
    bedtime.value = time;
    final minutes = timeOfDayToMinutes(time);
    getStorage.write(BEDTIME_KEY, minutes);

    // Mirror into SharedPreferences so background isolate can read it.
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt(BEDTIME_KEY, minutes);
    });

    debugPrint('🛏️ Bedtime set → $time ($minutes min since midnight)');
  }

  void setWakeTime(TimeOfDay time) {
    waketime.value = time;
    final minutes = timeOfDayToMinutes(time);
    getStorage.write(WAKETIME_KEY, minutes);

    // Mirror into SharedPreferences so background isolate can read it.
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt(WAKETIME_KEY, minutes);
    });

    debugPrint('⏰ Waketime set → $time ($minutes min since midnight)');
  }
}
