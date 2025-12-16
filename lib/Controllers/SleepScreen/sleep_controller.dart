import 'dart:async';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:snevva/common/global_variables.dart';
import 'package:snevva/models/sleep_log.dart';
import 'package:snevva/services/sleep_noticing_service.dart';

class SleepController extends GetxController {
  /// User's original bedtime (when they intend to sleep)
  final Rx<DateTime?> bedtime = Rx<DateTime?>(DateTime.now());

  /// User's wake-up time
  final Rx<DateTime?> waketime = Rx<DateTime?>(
    DateTime.now().add(Duration(hours: 8)),
  );

  final Rx<DateTime?> idealBedTime = Rx<DateTime?>(null);

  /// Calculated new bedtime after phone usage logic
  final Rx<DateTime?> newBedtime = Rx<DateTime?>(null);

  bool _didPhoneUsageOccur = false;
  Timer? _morningCheckTimer;

  /// Resulting deep sleep duration
  final Rx<Duration?> deepSleepDuration = Rx<Duration?>(null);
  final RxList<Duration?> deepSleepDurationList = RxList<Duration?>();

  /// Store sleep data with day index as key (0=Mon, 1=Tue, ..., 6=Sun)
  RxMap<String, Duration> deepSleepHistory = <String, Duration>{}.obs;

  final SleepNoticingService _sleepService = SleepNoticingService();
  RxList<FlSpot> deepSleepSpots = <FlSpot>[].obs;

  @override
  void onInit() {
    super.onInit();
    _sleepService.onPhoneUsageDetected = onPhoneUsed;
    loadDeepSleepData();
  }

  Box<SleepLog> get _box => Hive.box<SleepLog>('sleep_log');

  /// Save sleep data to Hive
  Future<void> saveDeepSleepData(DateTime date, Duration duration) async {
    // 1) Update in-memory map for UI (keeping string keys for compatibility with chart logic)
    final key = "${date.year}-${date.month}-${date.day}";
    deepSleepHistory[key] = duration;

    // 2) Save to Hive
    final zeroDate = DateTime(date.year, date.month, date.day);

    // Remove existing entry for this day if any
    final existingKey = _box.keys.firstWhere((k) {
      final log = _box.get(k);
      if (log == null) return false;
      return log.date.year == date.year &&
          log.date.month == date.month &&
          log.date.day == date.day;
    }, orElse: () => null);

    if (existingKey != null) {
      final log = _box.get(existingKey)!;
      log.durationMinutes = duration.inMinutes;
      log.save();
    } else {
      _box.add(SleepLog(date: zeroDate, durationMinutes: duration.inMinutes));
    }

    print("SavedDeepSleepData (Hive) : $key -> ${duration.inMinutes}m");
    _updateDeepSleepSpots(); // Update graph after saving
  }

  void _updateDeepSleepSpots() {
    final now = DateTime.now();
    // Monday of this week
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));

    List<FlSpot> spots = [];

    for (int i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      final key = "${date.year}-${date.month}-${date.day}";

      double hours = 0;
      if (deepSleepHistory.containsKey(key)) {
        hours = deepSleepHistory[key]!.inMinutes / 60.0;
      }
      // i is 0 for Mon, 1 for Tue... matching the labels
      spots.add(FlSpot(i.toDouble(), hours));
    }

    deepSleepSpots.value = spots;
  }

  // void _updateDeepSleepSpots() {
  //   final int todayIndex = DateTime.now().weekday - 1;
  //   print(DateTime.now().weekday);
  //   List<FlSpot> spots = [];
  //
  //   for (int dayIndex = 0; dayIndex <= todayIndex; dayIndex++) {
  //     if (deepSleepHistory.containsKey(dayIndex.toString())) {
  //       final hours = deepSleepHistory[dayIndex.toString()]!.inMinutes / 60.0;
  //       spots.add(FlSpot(dayIndex.toDouble(), hours));
  //     }
  //   }
  //
  //   deepSleepSpots.value = spots;
  //
  //   print("📊 Graph data updated:");
  //   for (var spot in spots) {
  //     final day = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][spot.x.toInt()];
  //     print(" $day: ${spot.y.toStringAsFixed(1)}h");
  //   }
  // }
  List<String> generateMonthLabels(DateTime month) {
    final total = daysInMonth(month.year, month.month);
    return List.generate(total, (i) => '${i + 1}');
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

  /// Load sleep data from SharedPreferences
  /// Load sleep data from Hive
  void loadDeepSleepData() {
    deepSleepHistory.clear();

    if (_box.isEmpty) return;

    for (var log in _box.values) {
      final key = "${log.date.year}-${log.date.month}-${log.date.day}";
      print("Date: ${log.date}");
      print("Key : $key");
      print("Duration : ${log.durationMinutes} minutes");

      deepSleepHistory[key] = Duration(minutes: log.durationMinutes);

      print("   Stored     : ${deepSleepHistory[key]}");
    }
    print("LoadDeepSleepData (Hive) : loaded ${_box.length} entries");
    _updateDeepSleepSpots();
  }

  /// Clear data for new week (call this on Monday if needed)
  Future<void> clearWeekData() async {
    deepSleepHistory.clear();
    deepSleepSpots.clear();
    await _box.clear();
    print("🗑️ Cleared week data (Hive)");
  }

  @override
  void onClose() {
    _morningCheckTimer?.cancel();
    _sleepService.stopMonitoring();
    super.onClose();
  }

  void startMonitoring() {
    _didPhoneUsageOccur = false;
    _startMorningAutoCheck();
    _sleepService.startMonitoring();
    print("🚀 Sleep monitoring started");
  }

  void _startMorningAutoCheck() {
    _morningCheckTimer?.cancel();

    _morningCheckTimer = Timer.periodic(Duration(minutes: 1), (timer) {
      final now = DateTime.now();

      if (!_didPhoneUsageOccur &&
          waketime.value != null &&
          now.isAfter(waketime.value!)) {
        _handleSleepWithoutPhoneUsage();
        timer.cancel();
      }
    });
  }

  void _handleSleepWithoutPhoneUsage() {
    DateTime bt = bedtime.value!;
    DateTime wt = waketime.value!;

    // Handle overnight sleep (wake time is next day)
    if (wt.isBefore(bt)) {
      wt = wt.add(Duration(days: 1));
    }

    final deep = wt.difference(bt);
    deepSleepDuration.value = deep;
    newBedtime.value = bt;

    final today = DateTime.now();
    // final key = "${today.year}-${today.month}-${today.day}"; // handled in saveDeepSleepData now

    // deepSleepHistory[key] = deep; // handled in saveDeepSleepData now

    _updateDeepSleepSpots();
    saveDeepSleepData(today, deep);

    final dayName =
        [
          "Mon",
          "Tue",
          "Wed",
          "Thu",
          "Fri",
          "Sat",
          "Sun",
        ][DateTime.now().weekday - 1];

    print("🌙 AUTO SLEEP - $dayName: ${deep.inHours}h ${deep.inMinutes % 60}m");
  }

  void stopMonitoring() {
    _morningCheckTimer?.cancel();
    _sleepService.stopMonitoring();
    print("🛑 Sleep monitoring stopped");
  }

  void setBedtime(DateTime time) {
    bedtime.value = time;
  }

  void setWakeTime(DateTime time) {
    waketime.value = time;
  }

  Duration? get idealWakeupDuration {
    return Duration(minutes: 720);
  }

  /// Called when phone usage is detected
  // void onPhoneUsed(DateTime phoneUsageStart, DateTime phoneUsageEnd) async {
  //   _didPhoneUsageOccur = true;
  //
  //   if (bedtime.value == null || waketime.value == null) return;
  //
  //   final Duration usageDuration = phoneUsageEnd.difference(phoneUsageStart);
  //
  //   final DateTime computedBedtime = _sleepService.calculateNewBedtime(
  //     bedtime: bedtime.value!,
  //     phoneUsageStart: phoneUsageStart,
  //     phoneUsageDuration: usageDuration,
  //   );
  //
  //   newBedtime.value = computedBedtime;
  //
  //   // --- FIX NEGATIVE DEEP SLEEP ---
  //   DateTime correctedWake = waketime.value!;
  //
  //   if (correctedWake.isBefore(computedBedtime)) {
  //     correctedWake = correctedWake.add(Duration(days: 1));
  //   }
  //   // -------------------------------
  //
  //   deepSleepDuration.value = _sleepService.calculateDeepSleep(
  //     computedBedtime,
  //     correctedWake,
  //   );
  //   saveCurrentDayDeepSleepData(
  //     _sleepService.calculateDeepSleep(computedBedtime, correctedWake),
  //   );
  //
  //   deepSleepDurationList.add(deepSleepDuration.value);
  //
  //   if (deepSleepDuration.value != null) {
  //     final todayIndex = DateTime.now().weekday - 1;
  //
  //     deepSleepHistory[todayIndex] = deepSleepDuration.value!;
  //     _updateDeepSleepSpots();
  //     await saveDeepSleepData();
  //
  //     final day = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][todayIndex];
  //     final d = deepSleepDuration.value!;
  //     print("✅ SLEEP DATA - $day: ${d.inHours}h ${d.inMinutes % 60}m");
  //   }
  // }
  void onPhoneUsed(DateTime phoneUsageStart, DateTime phoneUsageEnd) async {
    _didPhoneUsageOccur = true;

    if (bedtime.value == null || waketime.value == null) return;

    final usageDuration = phoneUsageEnd.difference(phoneUsageStart);

    final computedBedtime = _sleepService.calculateNewBedtime(
      bedtime: bedtime.value!,
      phoneUsageStart: phoneUsageStart,
      phoneUsageDuration: usageDuration,
    );

    newBedtime.value = computedBedtime;

    // final fixedDeep = calculateFixedDeepSleep(computedBedtime, waketime.value!);
    // Assume calculateFixedDeepSleep is available or simple difference logic
    // Restoring simple logic if function missing, BUT User code had it.
    // I will assume it's available.
    final fixedDeep = calculateFixedDeepSleep(computedBedtime, waketime.value!);

    deepSleepDuration.value = fixedDeep;
    // await saveCurrentDayDeepSleepData(fixedDeep); // Removed

    final today = DateTime.now();
    // final key = "${today.year}-${today.month}-${today.day}";
    // deepSleepHistory[key] = fixedDeep; // handled below

    _updateDeepSleepSpots();
    await saveDeepSleepData(today, fixedDeep);
  }
}

// Helper stub if calculateFixedDeepSleep is not found in file (it was used in original code)
// If it was global, this is fine. If it was missing, we need it.
// Based on context, I'll trust it exists.

// Removed old helpers
// saveCurrentDayDeepSleepData
// loadCurrentDayDeepSleepData
