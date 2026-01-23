import 'dart:async';
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

import '../../common/global_variables.dart';

import '../../models/hive_models/sleep_log.dart';
import '../../services/sleep_noticing_service.dart';

class SleepController extends GetxController {
  String BEDTIME_KEY = 'user_bedtime_ms';
  String WAKETIME_KEY = 'user_waketime_ms';
  static const _sleepCandidateStartKey = "sleep_candidate_start";
  static const _sleepCandidateHadPhoneUsageKey = "sleep_candidate_had_phone";

  /// User bedtime & waketime
  final Rxn<TimeOfDay> bedtime = Rxn<TimeOfDay>();
  final Rxn<TimeOfDay> waketime = Rxn<TimeOfDay>();

  RxBool isMonthlyView = false.obs;

  final RxList<FlSpot> monthlySleepSpots = <FlSpot>[].obs;

  final Rx<DateTime?> newBedtime = Rx<DateTime?>(null);
  final Rx<Duration?> deepSleepDuration = Rx<Duration?>(null);

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
    _sleepService.onSleepDetected = _onSleepDetected;

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



  @override
  void onClose() {
    _morningCheckTimer?.cancel();
    _sleepService.stopMonitoring();
    super.onClose();
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

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────

  String dateKey(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

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

    await prefs.setBool('is_first_time_sleep', false);
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

    debugPrint("📦 Hive entries count: ${_box.length}");

    for (final log in _box.values) {
      final key = dateKey(log.date);
      final duration = Duration(minutes: log.durationMinutes);

      weeklyDeepSleepHistory[key] = duration;

      print("loadDeepSleepData ${deepSleepDuration.value}");

      debugPrint("   💤 Weekly ← Hive: $key → ${duration.inMinutes} min");
    }
    deepSleepDuration.value = weeklyDeepSleepHistory[getCurrentDayKey()];

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
        final currentWeekStart = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
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
    debugPrint("🌙 Sleep detected: $sleepStart → $wakeUp");

    if (_wasPhoneUsedDuringSleep) {
      await finalizeSleepCycle();
    } else {
      await _handleSleepWithoutPhoneUsageCustom(sleepStart, wakeUp);
    }
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

    final weekStart = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
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

      await prefs.setString(_sleepCandidateStartKey, bt.toIso8601String());
      await prefs.setBool(_sleepCandidateHadPhoneUsageKey, false);
    }
    _startMorningAutoCheck();
    _sleepService.startMonitoring();
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

      final sleepStart = resolveSleepStart(now);
      final sleepEnd = resolveSleepEnd(sleepStart);

      if (now.isAfter(sleepEnd)) {
        if (_wasPhoneUsedDuringSleep) {
          await finalizeSleepCycle();
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

  Future<void> _handleSleepWithoutPhoneUsage() async {
    // Compute a robust duration using tonight's configured bed/wake, normalize across midnight.
    if (bedtime.value == null || waketime.value == null) {
      debugPrint('⚠️ Bed/Wake not set, skipping autosave');
      return;
    }

    // Build the bed/wake for the intended cycle relative to bed date
    final bt = resolveSleepStart(DateTime.now());
    final wt = resolveSleepEnd(bt);

    final deep = wt.difference(bt);
    if (deep.inMinutes < 10) {
      debugPrint(
        '⛔ Skipping save: calculated duration too small (${deep.inMinutes}m)',
      );
      return;
    }

    //deepSleepDuration.value = deep;
    newBedtime.value = bt;

    // Save against bed date for consistent history keys
    await saveDeepSleepData(bt, deep);

    // Push correct normalized times to server
    await uploadsleepdatatoServer(bt, wt);
    debugPrint('✅ Auto-saved sleep without phone usage: $deep');
  }

  // ─────────────────────────────────────────────
  // PHONE USAGE
  // ─────────────────────────────────────────────

  Future<void> onPhoneUsed(DateTime start, DateTime end) async {
    if (bedtime.value == null || waketime.value == null) return;

    final sleepStart = resolveSleepStart(DateTime.now());
    final sleepEnd = resolveSleepEnd(sleepStart);

    // Clamp usage inside sleep window
    final clampedStart = start.isBefore(sleepStart) ? sleepStart : start;
    final clampedEnd = end.isAfter(sleepEnd) ? sleepEnd : end;

    if (clampedEnd.difference(clampedStart).inSeconds < 30) return;

    _wasPhoneUsedDuringSleep = true;
    phoneUsageIntervals.add(AwakeInterval(clampedStart, clampedEnd));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sleepCandidateHadPhoneUsageKey, true);
  }

  List<AwakeInterval> mergeAwakeIntervals(List<AwakeInterval> intervals) {
    if (intervals.isEmpty) return [];

    // Sort by start time
    intervals.sort((a, b) => a.start.compareTo(b.start));

    final List<AwakeInterval> merged = [];
    AwakeInterval current = intervals.first;

    for (int i = 1; i < intervals.length; i++) {
      final next = intervals[i];

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

    final sleepStart = resolveSleepStart(DateTime.now());
    final sleepEnd = resolveSleepEnd(sleepStart);
    final totalWindow = sleepEnd.difference(sleepStart);

    final mergedAwake = mergeAwakeIntervals(phoneUsageIntervals);
    Duration awakeTotal = mergedAwake.fold(
      Duration.zero,
      (prev, interval) => prev + interval.end.difference(interval.start),
    );

    final deepSleep = totalWindow - awakeTotal;

    if (deepSleep.isNegative || deepSleep.inMinutes < 10) return;

    await saveDeepSleepData(sleepStart, deepSleep);
    await uploadsleepdatatoServer(sleepStart, sleepEnd);

    phoneUsageIntervals.clear();
    _wasPhoneUsedDuringSleep = false;

    debugPrint("😴 Final sleep calculated: $deepSleep");
  }

  // ─────────────────────────────────────────────
  // SETTERS
  // ─────────────────────────────────────────────

  void setBedtime(TimeOfDay time) {
    bedtime.value = time;
    getStorage.write(BEDTIME_KEY, timeOfDayToMinutes(time));
  }

  void setWakeTime(TimeOfDay time) {
    waketime.value = time;
    getStorage.write(WAKETIME_KEY, timeOfDayToMinutes(time));
  }
}
