import 'dart:async';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hive/hive.dart';
import 'package:fl_chart/fl_chart.dart';

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

    final bedMs = box.read("bedtime");
    final wakeMs = box.read("waketime");

    if (bedMs != null && bedMs is int) {
      bedtime.value = DateTime.fromMillisecondsSinceEpoch(bedMs);
    }

    if (wakeMs != null && wakeMs is int) {
      waketime.value = DateTime.fromMillisecondsSinceEpoch(wakeMs);
    }

    /// 🔥 LOAD DATA ONCE
    loadDeepSleepData();
  }

  @override
  void onClose() {
    _morningCheckTimer?.cancel();
    _sleepService.stopMonitoring();
    super.onClose();
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

  void loadDeepSleepData() {
    deepSleepHistory.clear();

    if (_box.isEmpty) return;

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
