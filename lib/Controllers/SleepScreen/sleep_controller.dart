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
import 'package:snevva/services/api_service.dart';

import '../../common/global_variables.dart';
import '../../models/sleep_log.dart';
import '../../services/sleep_noticing_service.dart';

class SleepController extends GetxController {
  /// User bedtime & waketime
  final Rxn<DateTime> bedtime = Rxn<DateTime>();
  final Rxn<DateTime> waketime = Rxn<DateTime>();

  final Rx<DateTime?> newBedtime = Rx<DateTime?>(null);
  final Rx<Duration?> deepSleepDuration = Rx<Duration?>(null);

  /// In-memory sleep history (yyyy-mm-dd → Duration)
  final RxMap<String, Duration> deepSleepHistory = <String, Duration>{}.obs;

  /// Chart data
  final RxList<FlSpot> deepSleepSpots = <FlSpot>[].obs;

  final SleepNoticingService _sleepService = SleepNoticingService();
  Timer? _morningCheckTimer;
  bool _didPhoneUsageOccur = false;

  static const String _lastUploadedSleepDateKey =
      "last_uploaded_sleep_bed_date";

  /// Hive box
  Box<SleepLog> get _box => Hive.box<SleepLog>('sleep_log');
  final box = GetStorage();

  // ─────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    _sleepService.onPhoneUsageDetected = onPhoneUsed;

    loadDeepSleepData();
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

  String _dateKey(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  bool hasSleepDataForDate(DateTime date) {
    return deepSleepHistory.containsKey(_dateKey(date));
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

  Future<void> loadSleepfromAPI({required int month, required int year}) async {
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
        return;
      }

      final decoded = response as Map<String, dynamic>;
      print('decoded response: $decoded');

      final sleepData = decoded['data']?['SleepData'] ?? [];

      print("🛌 Fetched sleep data for $month/$year: $sleepData");

      // 🔥 CLEAR OLD DATA BEFORE LOADING NEW MONTH
      deepSleepHistory.clear();

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

        final key = _dateKey(DateTime(year, month, day));
        deepSleepHistory[key] = duration;
      }

      if (sleepData.isNotEmpty && sleepData[0]['SleepData'] != null) {
        final latestSleep = sleepData[0]['SleepData'];
        bedtime.value =
            latestSleep['SleepingFrom'] != null
                ? _parseTime(
                  year,
                  month,
                  latestSleep['Day'],
                  latestSleep['SleepingFrom'],
                )
                : null;
        waketime.value =
            latestSleep['SleepingTo'] != null
                ? _parseTime(
                  year,
                  month,
                  latestSleep['Day'],
                  latestSleep['SleepingTo'],
                )
                : null;
      }

      // 🔁 Refresh weekly graph too
      _updateDeepSleepSpots();
      saveVitalsToLocalStorage();

      print("✅ Sleep history loaded: $deepSleepHistory");
    } catch (e) {
      print("❌ Error loading sleep data: $e");
    }
  }

  Future<void> saveVitalsToLocalStorage() async {
    final prefs = await SharedPreferences.getInstance();

    final int bedMs = bedtime.value?.millisecondsSinceEpoch ?? 0;
    final int wakeMs = waketime.value?.millisecondsSinceEpoch ?? 0;

    debugPrint("💾 Saving vitals to local storage:");
    debugPrint("   Bedtime (ms since epoch): $bedMs");
    debugPrint("   Waketime (ms since epoch): $wakeMs");
    debugPrint("   is_first_time_sleep: false");

    await prefs.setInt('bedtime', bedMs);
    await prefs.setInt('waketime', wakeMs);
    await prefs.setBool('is_first_time_sleep', false);

    debugPrint("✅ Vitals saved successfully to SharedPreferences");
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
      final bedKey = _dateKey(bedDateTime);
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

  void loadDeepSleepData() {
    deepSleepHistory.clear();

    if (_box.isEmpty) return;

    final bedMs = box.read("bedtime");
    print("bedtime loaded from hive : $bedMs");
    final wakeMs = box.read("waketime");
    print("waketime loaded from hive : $wakeMs");

    if (bedMs != null && bedMs is int) {
      bedtime.value = DateTime.fromMillisecondsSinceEpoch(bedMs);
      print("bedtime epoch loaded from hive : ${bedtime.value}");
    }

    if (wakeMs != null && wakeMs is int) {
      waketime.value = DateTime.fromMillisecondsSinceEpoch(wakeMs);
      print("waketime epoch loaded from hive : ${waketime.value}");
    }

    DateTime? latestDate;
    Duration? latestDuration;

    for (final log in _box.values) {
      final key = _dateKey(log.date);
      final duration = Duration(minutes: log.durationMinutes);

      deepSleepHistory[key] = duration;

      if (latestDate == null || log.date.isAfter(latestDate)) {
        latestDate = log.date;
        latestDuration = duration;
      }
    }

    if (latestDuration != null) {
      deepSleepDuration.value = latestDuration;
    }

    _updateDeepSleepSpots();
  }

  Duration? get idealWakeupDuration {
    return Duration(minutes: 720);
  }

  List<FlSpot> getMonthlyDeepSleepSpots(DateTime month) {
    final now = DateTime.now();

    final int totalDays =
        (month.year == now.year && month.month == now.month)
            ? now
                .day // 🔥 only till today
            : daysInMonth(month.year, month.month);
    List<FlSpot> spots = [];

    for (int day = 1; day <= totalDays; day++) {
      final key = "${month.year}-${month.month}-$day";

      if (deepSleepHistory.containsKey(key)) {
        final hours = deepSleepHistory[key]!.inMinutes / 60.0;
        spots.add(FlSpot((day - 1).toDouble(), hours));
      } else {
        spots.add(FlSpot((day - 1).toDouble(), 0.0)); // missing day
      }
    }

    return spots;
  }

  // ─────────────────────────────────────────────
  // SAVE (NO OVERWRITE)
  // ─────────────────────────────────────────────

  Future<void> saveDeepSleepData(DateTime date, Duration duration) async {
    final key = _dateKey(date);

    if (deepSleepHistory.containsKey(key)) {
      print("⛔ Already saved for $key — skipping");
      return;
    }

    deepSleepHistory[key] = duration;

    await _box.add(
      SleepLog(
        date: DateTime(date.year, date.month, date.day),
        durationMinutes: duration.inMinutes,
      ),
    );

    _updateDeepSleepSpots();

    print("✅ Saved sleep for $key (${duration.inMinutes} min)");
  }

  // ─────────────────────────────────────────────
  // GRAPH
  // ─────────────────────────────────────────────

  void _updateDeepSleepSpots() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));

    List<FlSpot> spots = [];

    for (int i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      final key = _dateKey(date);

      // ✅ Convert minutes to hours correctly
      final minutes = deepSleepHistory[key]?.inMinutes ?? 0;
      final hours = minutes / 60.0;

      spots.add(FlSpot(i.toDouble(), hours));
    }

    deepSleepSpots.value = spots;
  }

  // ─────────────────────────────────────────────
  // MONITORING
  // ─────────────────────────────────────────────

  void startMonitoring() {
    _didPhoneUsageOccur = false;
    _startMorningAutoCheck();
    _sleepService.startMonitoring();
  }

  void stopMonitoring() {
    _morningCheckTimer?.cancel();
    _sleepService.stopMonitoring();
  }

  void _startMorningAutoCheck() {
    _morningCheckTimer?.cancel();

    _morningCheckTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      final now = DateTime.now();

      if (!_didPhoneUsageOccur && waketime.value != null) {
        // ✅ Compare within today's context (not full DateTime comparison)
        final wakeToday = DateTime(
          now.year,
          now.month,
          now.day,
          waketime.value!.hour,
          waketime.value!.minute,
        );
        if (now.isAfter(wakeToday)) {
          _handleSleepWithoutPhoneUsage();
          timer.cancel();
        }
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
    DateTime bt = bedtime.value!;
    DateTime wt = DateTime(
      bt.year,
      bt.month,
      bt.day,
      waketime.value!.hour,
      waketime.value!.minute,
    );
    if (wt.isBefore(bt) || wt.isAtSameMomentAs(bt)) {
      wt = wt.add(const Duration(days: 1));
    }

    final deep = wt.difference(bt);
    if (deep.inMinutes < 10) {
      debugPrint(
        '⛔ Skipping save: calculated duration too small (${deep.inMinutes}m)',
      );
      return;
    }

    deepSleepDuration.value = deep;
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

  Future<void> onPhoneUsed(
    DateTime phoneUsageStart,
    DateTime phoneUsageEnd,
  ) async {
    final DateTime now = DateTime.now();
    _didPhoneUsageOccur = true;

    debugPrint("📱 Phone used detected");
    debugPrint("   Start: $phoneUsageStart");
    debugPrint("   End  : $phoneUsageEnd");
    debugPrint("   Now  : $now");

    if (bedtime.value == null || waketime.value == null) {
      debugPrint("⚠️ Bedtime or Waketime is null, returning...");
      return;
    }

    // Ignore morning phone usage (after wake time)
    if (phoneUsageStart.isAfter(waketime.value!)) {
      debugPrint("ℹ️ Morning phone check - ignoring");
      return;
    }

    final usageDuration = phoneUsageEnd.difference(phoneUsageStart);
    debugPrint("⏱ Phone usage duration: ${usageDuration.inMinutes} min");

    final computedBedtime = _sleepService.calculateNewBedtime(
      bedtime: bedtime.value!,
      phoneUsageStart: phoneUsageStart,
      phoneUsageDuration: usageDuration,
    );
    final split = calculateSplitDeepSleep(
      oldBedtime: bedtime.value!, // original configured bedtime
      oldWakeTime: waketime.value!, // original configured waketime
      phonePickupTime: phoneUsageStart, // when the user picked up the phone
      newBedtime: computedBedtime, // adjusted bedtime (usageEnd - 15min)
    );

    debugPrint(
      "💤 Split deep sleep -> beforePhone: ${split['beforePhone']}, afterPhone: ${split['afterPhone']}, total: ${split['total']}",
    );

    // decide what to save/upload: use `split['total']` as the "deep" duration if you want the sum
    final Duration deep = split['total']!;

    if (deep.inMinutes < 10) {
      debugPrint(
        '⛔ Skipping save/upload (phone usage): duration too small (${deep.inMinutes}m)',
      );
      return;
    }

    // optionally set deepSleepDuration to the total (or one of the halves if you prefer)
    deepSleepDuration.value = deep;

    // Save using computedBedtime as bed date (as you already do)
    await saveDeepSleepData(computedBedtime, deep);

    debugPrint(
      "🛏 Computed bedtime after phone usage adjustment: $computedBedtime",
    );
    newBedtime.value = computedBedtime;

    // Normalize wake to the bed date of computedBedtime
    DateTime correctedWake = DateTime(
      computedBedtime.year,
      computedBedtime.month,
      computedBedtime.day,
      waketime.value!.hour,
      waketime.value!.minute,
    );
    if (correctedWake.isBefore(computedBedtime) ||
        correctedWake.isAtSameMomentAs(computedBedtime)) {
      correctedWake = correctedWake.add(const Duration(days: 1));
    }
    debugPrint("⏰ Corrected Wake: $correctedWake");

    //Calculating deep sleep
    debugPrint("💤 Calculated deep sleep duration: ${deep.inMinutes} min");

    if (deep.inMinutes < 10) {
      debugPrint(
        '⛔ Skipping save/upload (phone usage): duration too small (${deep.inMinutes}m)',
      );
      return;
    }

    if (now.isAfter(correctedWake)) {
      debugPrint("✅ Now is after corrected wake, updating deepSleepDuration");
      deepSleepDuration.value = deep;
    } else {
      debugPrint(
        "ℹ️ Now is before corrected wake, not updating deepSleepDuration yet",
      );
    }

    // Save against bed date of the cycle
    debugPrint("💾 Saving sleep data for date: $computedBedtime");
    await saveDeepSleepData(computedBedtime, deep);

    // Upload normalized values
    debugPrint("🌍 Uploading sleep data to server...");
    await uploadsleepdatatoServer(computedBedtime, correctedWake);
  }

  // ─────────────────────────────────────────────
  // SETTERS
  // ─────────────────────────────────────────────

  void setBedtime(DateTime time) {
    bedtime.value = time;
    box.write("bedtime", time.millisecondsSinceEpoch);
  }

  void setWakeTime(DateTime time) {
    waketime.value = time;
    box.write("waketime", time.millisecondsSinceEpoch);
  }
}
