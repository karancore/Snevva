import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_connect/http/src/response/response.dart' as http;
import 'package:get_storage/get_storage.dart';
import 'package:hive/hive.dart';
import 'package:fl_chart/fl_chart.dart';
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

  String _dateKey(DateTime d) => "${d.year}-${d.month}-${d.day}";

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
      final List<dynamic> sleepData = decoded['data']?['SleepData'] ?? [];

      // 🔥 CLEAR OLD DATA BEFORE LOADING NEW MONTH
      deepSleepHistory.clear();

      for (final item in sleepData) {
        final int day = item['Day'];
        final int month = item['Month'];
        final int year = item['Year'];

        final String from = item['SleepingFrom'];
        final String to = item['SleepingTo'];

        DateTime bedTime = _parseTime(year, month, day, from);
        DateTime wakeTime = _parseTime(year, month, day, to);

        // 🌙 If wake time is next day
        if (wakeTime.isBefore(bedTime)) {
          wakeTime = wakeTime.add(const Duration(days: 1));
        }

        final duration = wakeTime.difference(bedTime);

        final key = "$year-$month-$day";
        deepSleepHistory[key] = duration;
      }

      // 🔁 Refresh weekly graph too
      _updateDeepSleepSpots();

      print("✅ Sleep history loaded: $deepSleepHistory");
    } catch (e) {
      print("❌ Error loading sleep data: $e");
    }
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
    int totalDays = daysInMonth(month.year, month.month);
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

      final hours = deepSleepHistory[key]?.inMinutes.toDouble() ?? 0;

      spots.add(FlSpot(i.toDouble(), hours / 60));
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

      if (!_didPhoneUsageOccur &&
          waketime.value != null &&
          now.isAfter(waketime.value!)) {
        _handleSleepWithoutPhoneUsage();
        timer.cancel();
      }
    });
  }

  // ─────────────────────────────────────────────
  // AUTO SLEEP (NO PHONE)
  // ─────────────────────────────────────────────

  void _handleSleepWithoutPhoneUsage() {
    final today = DateTime.now();

    if (hasSleepDataForDate(today)) {
      print("⛔ Sleep already saved today");
      return;
    }

    DateTime bt = bedtime.value!;
    DateTime wt = waketime.value!;

    if (wt.isBefore(bt)) {
      wt = wt.add(const Duration(days: 1));
    }

    final deep = wt.difference(bt);

    deepSleepDuration.value = deep;
    newBedtime.value = bt;

    saveDeepSleepData(today, deep);
  }

  // ─────────────────────────────────────────────
  // PHONE USAGE
  // ─────────────────────────────────────────────

  void onPhoneUsed(DateTime phoneUsageStart, DateTime phoneUsageEnd) async {
    final today = DateTime.now();

    if (hasSleepDataForDate(today)) {
      print("⛔ Sleep already saved today (phone)");
      return;
    }

    _didPhoneUsageOccur = true;

    if (bedtime.value == null || waketime.value == null) return;

    final usageDuration = phoneUsageEnd.difference(phoneUsageStart);

    final computedBedtime = _sleepService.calculateNewBedtime(
      bedtime: bedtime.value!,
      phoneUsageStart: phoneUsageStart,
      phoneUsageDuration: usageDuration,
    );

    newBedtime.value = computedBedtime;

    DateTime correctedWake = waketime.value!;
    if (correctedWake.isBefore(computedBedtime)) {
      correctedWake = correctedWake.add(const Duration(days: 1));
    }

    //Calculating deep sleep
    final deep = correctedWake.difference(computedBedtime);

    deepSleepDuration.value = deep;

    await saveDeepSleepData(today, deep);
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
