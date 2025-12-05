// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:snevva/env/env.dart';
// import 'package:snevva/services/api_service.dart';
// import 'package:http/http.dart' as http;
//
// class SleepController extends GetxController with WidgetsBindingObserver {
//   Rx<TimeOfDay> bedTime = TimeOfDay(hour: 22, minute: 0).obs;
//   Rx<TimeOfDay> wakeupTime = TimeOfDay(hour: 6, minute: 30).obs;
//
//   // Monitoring state
//   RxBool isMonitoring = false.obs;
//   Rxn<DateTime> sleepCandidateStart = Rxn<DateTime>();
//   Rxn<DateTime> adjustedBedtime = Rxn<DateTime>();
//   Rxn<Duration> actualSleepDuration = Rxn<Duration>();
//   RxList<String> activityLog = <String>[].obs;
//
//   bool _wakeHandled = false;
//   bool hasWokenUp = false;
//   @override
//   void onInit() {
//     super.onInit();
//     WidgetsBinding.instance.addObserver(this);
//   }
//
//   @override
//   void onClose() {
//     WidgetsBinding.instance.removeObserver(this);
//     super.onClose();
//   }
//
//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     if (!isMonitoring.value) return;
//
//     final now = DateTime.now();
//     final bedtimeToday = DateTime(
//       now.year,
//       now.month,
//       now.day,
//       bedTime.value.hour,
//       bedTime.value.minute,
//     );
//
//     // Check if current time is after bedtime
//     if (now.isAfter(bedtimeToday)) {
//       if (state == AppLifecycleState.paused ||
//           state == AppLifecycleState.inactive) {
//         _onScreenOff();
//       } else if (state == AppLifecycleState.resumed) {
//         _onScreenOn();
//       }
//     }
//   }
//
//   void _onScreenOff() {
//     sleepCandidateStart.value = DateTime.now();
//     _addLog('📴 Screen off at ${_formatTime(sleepCandidateStart.value!)}');
//     print('Screen off at: ${sleepCandidateStart.value}');
//   }
//
//   //For Testing
//   // Add fields
//   DateTime? _lastWakeTriggerDate;
//
// // helper
//   bool _isSameDate(DateTime a, DateTime b) => a.year==b.year && a.month==b.month && a.day==b.day;
//
// // _onScreenOn - replace existing implementation
//   void _onScreenOn() {
//     if (_wakeHandled) return;
//     _wakeHandled = true;
//
//     if (hasWokenUp) {
//       _log('⛔ Wake ignored — already marked woke up');
//       sleepCandidateStart.value = null;
//       return;
//     }
//
//     if (sleepCandidateStart.value == null) return;
//
//     final now = DateTime.now();
//     final awayDuration = now.difference(sleepCandidateStart.value!);
//
//     if (awayDuration.inSeconds < 30) {
//       _log('⏭️ Returned <30 sec — ignored');
//       sleepCandidateStart.value = null;
//       return;
//     }
//
//     // Use the date of the candidate start (avoid crossing-midnight bug)
//     final candidate = sleepCandidateStart.value!;
//     var bedtimeBase = DateTime(
//       candidate.year,
//       candidate.month,
//       candidate.day,
//       bedTime.value.hour,
//       bedTime.value.minute,
//     );
//
//     // If bedtimeBase is more than 12 hours after candidate, shift it back a day (guard)
//     if (bedtimeBase.difference(candidate).inHours.abs() > 12 && bedtimeBase.isAfter(candidate)) {
//       bedtimeBase = bedtimeBase.subtract(Duration(days: 1));
//     }
//
//     adjustedBedtime.value = bedtimeBase.add(awayDuration).add(const Duration(minutes: 1));
//
//     _log('✅ Bedtime adjusted → ${_ts(adjustedBedtime.value!)}');
//     _log('➕ Added ${awayDuration.inMinutes + 1} minutes');
//
//     sleepCandidateStart.value = null;
//   }
//
// // _startWakeChecker replacement (reset logic)
//   void _startWakeChecker() {
//     _wakeUpChecker?.cancel();
//
//     _wakeUpChecker = Timer.periodic(const Duration(seconds: 30), (_) {
//       if (!isMonitoring.value) return;
//
//       final now = DateTime.now();
//       final targetWake = DateTime(now.year, now.month, now.day,
//           wakeupTime.value.hour, wakeupTime.value.minute);
//
//       // reset trigger if last trigger wasn't today
//       if (_lastWakeTriggerDate == null || !_isSameDate(_lastWakeTriggerDate!, now)) {
//         _wakeUpTriggeredToday = false;
//       }
//
//       if (_wakeUpTriggeredToday) return;
//
//       if (now.isAfter(targetWake) || now.isAtSameMomentAs(targetWake)) {
//         hasWokenUp = true;
//         _log('⏰ Auto wake triggered');
//         calculateActualSleep();
//         _wakeUpTriggeredToday = true;
//         _lastWakeTriggerDate = DateTime(now.year, now.month, now.day);
//       }
//     });
//
//     _log('⏱️ Wake watcher started');
//   }
//
// // calculateActualSleep guard for negative durations
//   void calculateActualSleep() {
//     if (adjustedBedtime.value == null) {
//       _log('⚠️ No adjusted bedtime set');
//       return;
//     }
//
//     final now = DateTime.now();
//     final diff = now.difference(adjustedBedtime.value!);
//     if (diff.isNegative) {
//       _log('⚠️ Computed negative sleep duration — set to zero');
//       actualSleepDuration.value = Duration.zero;
//       sleepHoursHistory.add(0.0);
//     } else {
//       actualSleepDuration.value = diff;
//       final hours = actualSleepDuration.value!.inMinutes / 60.0;
//       sleepHoursHistory.add(hours);
//       _log('⏰ Woke at ${_ts(now)}');
//       _log('😴 Slept: ${_fmt(actualSleepDuration.value!)}');
//     }
//
//     hasWokenUp = true;
//   }
//
//
//   // For Production
//   // void _onScreenOn() {
//   //   if (sleepCandidateStart.value == null) return;
//   //
//   //   final now = DateTime.now();
//   //   final awayDuration = now.difference(sleepCandidateStart.value!);
//   //
//   //   _addLog('📱 Screen on at ${_formatTime(now)}');
//   //   _addLog('⏱️ Away for ${awayDuration.inMinutes} minutes');
//   //
//   //   // Check if away time is >= 15 minutes
//   //   if (awayDuration.inMinutes >= 15) {
//   //     final originalBedtime = DateTime(
//   //       sleepCandidateStart.value!.year,
//   //       sleepCandidateStart.value!.month,
//   //       sleepCandidateStart.value!.day,
//   //       bedTime.value.hour,
//   //       bedTime.value.minute,
//   //     );
//   //
//   //
//   //     // Add away duration + 1 minute buffer
//   //     adjustedBedtime.value = originalBedtime
//   //         .add(awayDuration)
//   //         .add(const Duration(minutes: 1));
//   //
//   //     _addLog('✅ Bedtime adjusted to ${_formatTime(adjustedBedtime.value!)}');
//   //     _addLog('➕ Added ${awayDuration.inMinutes + 1} minutes to bedtime');
//   //
//   //     Get.snackbar(
//   //       'Bedtime Adjusted',
//   //       'New bedtime: ${TimeOfDay.fromDateTime(adjustedBedtime.value!).format(Get.context!)}',
//   //       snackPosition: SnackPosition.TOP,
//   //       backgroundColor: Colors.green.withOpacity(0.8),
//   //       colorText: Colors.white,
//   //       duration: Duration(seconds: 3),
//   //     );
//   //
//   //   }
//   //
//   //   // if (awayDuration.inSeconds >= 10) {
//   //   //   final originalBedtime = DateTime.now();
//   //   //
//   //   //   // Add away duration + 1 minute buffer
//   //   //   adjustedBedtime.value = originalBedtime
//   //   //       .add(awayDuration)
//   //   //       .add(const Duration(minutes: 1));
//   //   //
//   //   //   _addLog('✅ Bedtime adjusted to ${_formatTime(adjustedBedtime.value!)}');
//   //   //   _addLog('➕ Added ${awayDuration.inMinutes + 1} minutes to bedtime');
//   //   //
//   //   //   Get.snackbar(
//   //   //     'Bedtime Adjusted',
//   //   //     'New bedtime: ${TimeOfDay.fromDateTime(adjustedBedtime.value!).format(Get.context!)}',
//   //   //     snackPosition: SnackPosition.TOP,
//   //   //     backgroundColor: Colors.green.withOpacity(0.8),
//   //   //     colorText: Colors.white,
//   //   //     duration: Duration(seconds: 3),
//   //   //   );
//   //   //
//   //   // }
//   //
//   //   else {
//   //     _addLog('⏭️ Away time < 15 min, ignoring');
//   //   }
//   //
//   //   // Reset sleep candidate
//   //   sleepCandidateStart.value = null;
//   // }
//
//   void startMonitoring() {
//     isMonitoring.value = true;
//     sleepCandidateStart.value = null;
//     adjustedBedtime.value = null;
//     actualSleepDuration.value = null;
//     activityLog.clear();
//
//     _addLog('🚀 Monitoring started');
//     _addLog('🌙 Target bedtime: ${bedTime.value.format(Get.context!)}');
//
//     Get.snackbar(
//       'Monitoring Started',
//       'Keep app running in background',
//       snackPosition: SnackPosition.BOTTOM,
//       backgroundColor: Colors.blue.withOpacity(0.8),
//       colorText: Colors.white,
//     );
//   }
//
//   void stopMonitoring() {
//     isMonitoring.value = false;
//     _addLog('🛑 Monitoring stopped');
//
//     Get.snackbar(
//       'Monitoring Stopped',
//       'You can review your sleep data',
//       snackPosition: SnackPosition.BOTTOM,
//     );
//   }
//
//   void calculateActualSleep() {
//     if (adjustedBedtime.value == null) {
//       Get.snackbar(
//         'No Data',
//         'No adjusted bedtime recorded yet',
//         snackPosition: SnackPosition.BOTTOM,
//         backgroundColor: Colors.orange.withOpacity(0.8),
//         colorText: Colors.white,
//       );
//       return;
//     }
//
//     final wakeUpTime = DateTime.now();
//     actualSleepDuration.value = wakeUpTime.difference(adjustedBedtime.value!);
//
//     _addLog('⏰ Wake up at ${_formatTime(wakeUpTime)}');
//     _addLog('😴 Total sleep: ${formatDuration(actualSleepDuration.value!)}');
//
//     Get.snackbar(
//       'Sleep Calculated',
//       'You slept for ${formatDuration(actualSleepDuration.value!)}',
//       snackPosition: SnackPosition.TOP,
//       backgroundColor: Colors.purple.withOpacity(0.8),
//       colorText: Colors.white,
//       duration: Duration(seconds: 4),
//     );
//   }
//
//   void _addLog(String message) {
//     activityLog.insert(0, '${_formatTime(DateTime.now())} - $message');
//     if (activityLog.length > 20) {
//       activityLog.removeLast();
//     }
//   }
//
//   String _formatTime(DateTime time) {
//     return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
//   }
//
//   /// Computes sleep duration from bedtime and wakeup time
//   Duration get sleepDuration {
//     // If we have actual calculated sleep, use that
//     if (actualSleepDuration.value != null) {
//       return actualSleepDuration.value!;
//     }
//
//     // Otherwise, use the default calculation
//     final now = DateTime.now();
//
//     final bedDateTime = DateTime(
//       now.year,
//       now.month,
//       now.day,
//       bedTime.value.hour,
//       bedTime.value.minute,
//     );
//
//     var wakeDateTime = DateTime(
//       now.year,
//       now.month,
//       now.day,
//       wakeupTime.value.hour,
//       wakeupTime.value.minute,
//     );
//
//     if (wakeDateTime.isBefore(bedDateTime)) {
//       wakeDateTime = wakeDateTime.add(const Duration(days: 1));
//     }
//
//     return wakeDateTime.difference(bedDateTime);
//   }
//
//   Future<void> updateBedTimeFromTimestamp(DateTime sleepStart, DateTime wakeUp) async {
//     bedTime.value = TimeOfDay(hour: sleepStart.hour, minute: sleepStart.minute);
//     wakeupTime.value = TimeOfDay(hour: wakeUp.hour, minute: wakeUp.minute);
//   }
//
//   String formatDuration(Duration duration) {
//     final h = duration.inHours;
//     final m = duration.inMinutes % 60;
//     return "${h}h ${m}min";
//   }
//
//   /// Call this after changing bedtime or wake time
//   Future<void> updateSleepTimes(TimeOfDay newBedTime, TimeOfDay newWakeTime) async {
//     bedTime.value = newBedTime;
//     wakeupTime.value = newWakeTime;
//
//     print("Updated bedtime: ${bedTime.value.format(Get.context!)}");
//     print("Updated wake time: ${wakeupTime.value.format(Get.context!)}");
//     print("Sleep duration: ${sleepDuration.inHours}h ${sleepDuration.inMinutes % 60}m");
//
//     await _syncSleepToServer();
//   }
//
//   Future<void> _syncSleepToServer() async {
//     try {
//       await Future.delayed(Duration(milliseconds: 500));
//       final now = DateTime.now();
//
//       final payload = {
//         "Day": now.day,
//         "Month": now.month,
//         "Year": now.year,
//         "Time": TimeOfDay.now().format(Get.context!),
//         "SleepingFrom": bedTime.value.format(Get.context!),
//         "SleepingTo": wakeupTime.value.format(Get.context!),
//         "AdjustedBedtime": adjustedBedtime.value != null
//             ? TimeOfDay.fromDateTime(adjustedBedtime.value!).format(Get.context!)
//             : null,
//         "ActualSleepDuration": actualSleepDuration.value?.inMinutes,
//       };
//
//       final response = await ApiService.post(
//         sleepGoal,
//         payload,
//         withAuth: true,
//         encryptionRequired: true,
//       );
//
//       if (response is http.Response && response.statusCode >= 400) {
//         Get.snackbar('Error', '❌ Failed to save Sleep record: ${response.statusCode}');
//       }
//
//       print("✅ Synced sleep data to backend");
//     } catch (e) {
//       Get.snackbar("Error", "Failed to sync sleep data");
//     }
//   }
// }
//

// import 'dart:async';
//
// import 'package:fl_chart/fl_chart.dart';
// import 'package:get/get.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:snevva/services/sleep_noticing_service.dart';
//
// class SleepController extends GetxController {
//   /// User's original bedtime (when they intend to sleep)
//   final Rx<DateTime?> bedtime = Rx<DateTime?>(DateTime.now());
//
//   /// User's wake-up time
//   final  Rx<DateTime?> waketime = Rx<DateTime?>(DateTime.now().add(Duration(hours: 8)));
//
//   final  Rx<DateTime?> idealBedTime = Rx<DateTime?>(null);
//
//   /// Calculated new bedtime after phone usage logic
//   final Rx<DateTime?> newBedtime = Rx<DateTime?>(null);
//
//   bool _didPhoneUsageOccur = false;
//   Timer? _morningCheckTimer;
//
//
//
//   /// Resulting deep sleep duration
//   final Rx<Duration?> deepSleepDuration = Rx<Duration?>(null);
//   final RxList<Duration?> deepSleepHistory = <Duration?>[].obs;
//
//   final SleepNoticingService _sleepService = SleepNoticingService();
//
//   RxList<FlSpot> deepSleepSpots = <FlSpot>[].obs;
//
//   // For hours
//   void _updateDeepSleepSpots() {
//     final int todayIndex = DateTime.now().weekday - 1; // 0 = Monday, 6 = Sunday
//
//     // Build fixed 7-day list
//     List<double> weeklyHours = List.generate(7, (i) {
//       if (i < deepSleepHistory.length) {
//         // History exists
//         final duration = deepSleepHistory[i];
//         return duration == null ? 0.0 : duration.inMinutes / 60.0;
//       }
//
//       // Missing history
//       if (i < todayIndex) {
//         // Past day but user did not use tracker → show 0 hours
//         return 0.0;
//       }
//
//       // For today or future days → keep default
//       return 0.0;
//     });
//     List<double> weeklyMinutes = List.generate(7, (i) {
//       if (i < deepSleepHistory.length) {
//         final duration = deepSleepHistory[i];
//         return duration?.inMinutes.toDouble() ?? 0.0;   // <-- minutes
//       }
//
//       // Missing history
//       if (i < todayIndex) {
//         return 0.0; // past day no tracking
//       }
//
//       // Today or future days
//       return 0.0;
//     });
//
//
//     // Convert to FL spots
//     deepSleepSpots.value = List.generate(
//       7,
//           (i) => FlSpot(i.toDouble(), weeklyHours[i]),
//     );
//
//     // Debug print
//     for (var s in deepSleepSpots) {
//       print("x=${s.x}, y=${s.y}");
//     }
//   }
//
//
//
//
//   // // For Minutes
//   // void _updateDeepSleepSpots() {
//   //   deepSleepSpots.value = deepSleepHistory.asMap().entries.map((e) {
//   //     final index = e.key;
//   //     final minutes = e.value?.inMinutes ?? 0;
//   //
//   //     return FlSpot(index.toDouble(), minutes.toDouble());
//   //   }).toList();
//   // }
//
//
//   @override
//   void onInit() {
//     super.onInit();
//     _sleepService.onPhoneUsageDetected = onPhoneUsed;
//     loadDeepSleepList();
//   }
//   Future<void> saveDeepSleepList(List<Duration?> list) async {
//     final prefs = await SharedPreferences.getInstance();
//
//     // Convert Duration? → int? → String
//     List<String> stringList = list.map((d) => d?.inHours.toString() ?? "null").toList();
//
//     prefs.setStringList("deepSleepHistory", stringList);
//   }
//   Future<void> loadDeepSleepList() async {
//     final prefs = await SharedPreferences.getInstance();
//     final stored = prefs.getStringList("deepSleepHistory");
//
//     if (stored == null) return;
//
//     deepSleepHistory.clear();
//
//     for (var s in stored) {
//       if (s == "null") {
//         deepSleepHistory.add(null);
//       } else {
//         deepSleepHistory.add(Duration(minutes: int.parse(s)));
//       }
//     }
//
//     _updateDeepSleepSpots();
//   }
//
//
//
//   @override
//   void onClose() {
//     _sleepService.stopMonitoring();
//     super.onClose();
//   }
//
//   void startMonitoring() {
//     _didPhoneUsageOccur = false; // reset
//
//     _startMorningAutoCheck();  // 🌟 NEW
//
//     _sleepService.startMonitoring();
//   }
//   void _startMorningAutoCheck() {
//     _morningCheckTimer?.cancel();
//
//     // Check every 1 minute
//     _morningCheckTimer = Timer.periodic(Duration(minutes: 1), (timer) {
//       final now = DateTime.now();
//
//       // Condition: it's morning AND no phone usage happened
//       if (!_didPhoneUsageOccur &&
//           waketime.value != null &&
//           now.isAfter(waketime.value!)) {
//
//         _handleSleepWithoutPhoneUsage();
//
//         timer.cancel();
//       }
//     });
//   }
//
//   void _handleSleepWithoutPhoneUsage() {
//     DateTime bt = bedtime.value!;
//     DateTime wt = waketime.value!;
//     if (wt.isBefore(bt)) {
//       wt = wt.add(Duration(days: 1));
//     }
//
//
//     // Deep sleep = wake - bedtime
//     final deep = wt.difference(bt);
//
//
//     deepSleepDuration.value = deep;
//     newBedtime.value = bt;
//
//     // Add to history
//     deepSleepHistory.add(deep);
//     if (deepSleepHistory.length > 7) {
//       deepSleepHistory.removeAt(0);
//     }
//
//     _updateDeepSleepSpots();
//     saveDeepSleepList(deepSleepHistory.toList());
//
//     print("🌙 AUTO SLEEP GENERATED — No phone usage detected");
//   }
//
//
//
//
//   void stopMonitoring() {
//     _morningCheckTimer?.cancel();
//     _sleepService.stopMonitoring();
//   }
//
//   /// Sets initial bedtime
//   void setBedtime(DateTime time) {
//     bedtime.value = time;
//   }
//
//   /// Sets wake time
//   void setWakeTime(DateTime time) {
//     waketime.value = time;
//   }
//
//   Duration? get idealWakeupDuration {
//     final wake = waketime.value;
//     final bed = bedtime.value;
//
//     if (wake == null || bed == null) return null;
//
//     return wake.difference(bed);
//   }
//
//
//   /// Main logic method → call this when the user uses the phone
//   /// phoneUsageStart = timestamp when user started using the phone
//   /// phoneUsageEnd   = timestamp when they stopped using the phone
//   void onPhoneUsed(DateTime phoneUsageStart, DateTime phoneUsageEnd) async {
//     _didPhoneUsageOccur = true;
//     if (bedtime.value == null) return;
//     if (waketime.value == null) return;
//
//     final Duration usageDuration = phoneUsageEnd.difference(phoneUsageStart);
//
//     final DateTime computedBedtime = _sleepService.calculateNewBedtime(
//       bedtime: bedtime.value!,
//       phoneUsageStart: phoneUsageStart,
//       phoneUsageDuration: usageDuration,
//     );
//
//     newBedtime.value = computedBedtime;
//
//     // calculate deep sleep
//     deepSleepDuration.value = _sleepService.calculateDeepSleep(
//       computedBedtime,
//       waketime.value!,
//     );
//     if (deepSleepDuration.value != null) {
//       deepSleepHistory.add(deepSleepDuration.value!);
//
//
//       if (deepSleepHistory.length > 7) {
//         deepSleepHistory.removeAt(0);
//       }
//
//       _updateDeepSleepSpots();
//
//       await saveDeepSleepList(deepSleepHistory.toList());
//
//     }
//
//   }
// }

import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/common/global_variables.dart';
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
  final RxMap<int, Duration> deepSleepHistory = <int, Duration>{}.obs;

  final SleepNoticingService _sleepService = SleepNoticingService();

  RxList<FlSpot> deepSleepSpots = <FlSpot>[].obs;

  /// Clean method to update graph spots
  void _updateDeepSleepSpots() {
    final int todayIndex = DateTime.now().weekday - 1; // 0=Mon, 6=Sun

    List<FlSpot> spots = [];

    // Only add spots for days that have actual data AND are not in the future
    for (int dayIndex = 0; dayIndex <= todayIndex; dayIndex++) {
      if (deepSleepHistory.containsKey(dayIndex)) {
        final hours = deepSleepHistory[dayIndex]!.inMinutes / 60.0;
        spots.add(FlSpot(dayIndex.toDouble(), hours));
      }
    }

    deepSleepSpots.value = spots;

    // Debug output
    print("📊 Graph data updated:");
    for (var spot in spots) {
      final day =
          ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][spot.x.toInt()];
      print("   $day: ${spot.y.toStringAsFixed(1)}h");
    }
  }

  @override
  void onInit() {
    super.onInit();
    _sleepService.onPhoneUsageDetected = onPhoneUsed;
    loadDeepSleepData();
  }

  /// Save sleep data to SharedPreferences
  Future<void> saveDeepSleepData() async {
    print("savedDeepSleepData getting called");
    final prefs = await SharedPreferences.getInstance();

    // Save as JSON-like string: "dayIndex:minutes,dayIndex:minutes,..."
    final dataString = deepSleepHistory.entries
        .map((e) => "${e.key}:${e.value.inMinutes}")
        .join(",");
    print("saveDeepSleepData $dataString");

    await prefs.setString("deepSleepData", dataString);
    print("💾 Saved sleep data: $dataString");
  }

  /// Load sleep data from SharedPreferences
  Future<void> loadDeepSleepData() async {
    print("Sleep Controller LoadSleepData");
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString("deepSleepData");
    print('Sleep Controller stored : $stored');

    if (stored == null || stored.isEmpty) {
      print("📭 No previous sleep data found");
      return;
    }

    deepSleepHistory.clear();

    // Parse: "dayIndex:minutes,dayIndex:minutes,..."
    final entries = stored.split(",");
    for (var entry in entries) {
      final parts = entry.split(":");
      if (parts.length == 2) {
        final dayIndex = int.tryParse(parts[0]);
        final minutes = int.tryParse(parts[1]);

        if (dayIndex != null &&
            minutes != null &&
            dayIndex >= 0 &&
            dayIndex < 7) {
          deepSleepHistory[dayIndex] = Duration(minutes: minutes);
        }
      }
    }

    _updateDeepSleepSpots();
    print("📂 Loaded sleep data for ${deepSleepHistory.length} days");
  }

  /// Clear data for new week (call this on Monday if needed)
  Future<void> clearWeekData() async {
    deepSleepHistory.clear();
    deepSleepSpots.clear();
    await saveDeepSleepData();
    print("🗑️ Cleared week data");
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

    final todayIndex = DateTime.now().weekday - 1;

    // Store today's sleep data
    deepSleepHistory[todayIndex] = deep;

    _updateDeepSleepSpots();
    saveDeepSleepData();

    final dayName =
        ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][todayIndex];
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

  Future<void> saveCurrentDayDeepSleepData(Duration sleep) async {
    print("saveCurrentDayDeepSleepData");
    final prefs = await SharedPreferences.getInstance();
    final deepSleepString = fmtDuration(sleep);
    print("saveCurrentDayDeepSleepData $deepSleepString");
    prefs.setString("currentDaySleep", deepSleepString);
  }

  Future<void> loadCurrentDayDeepSleepData() async {
    print("loadCurrentDayDeepSleepData");
    final prefs = await SharedPreferences.getInstance();
    final deepSleepString = prefs.getString("currentDaySleep");

    if (deepSleepString != null) {
      deepSleepDuration.value = parseDuration(deepSleepString);
    } else {
      deepSleepDuration.value = Duration.zero;
    }
  }

  Duration? get idealWakeupDuration {
    final wake = waketime.value;
    final bed = bedtime.value;

    if (wake == null || bed == null) return null;

    return wake.difference(bed);
  }

  /// Called when phone usage is detected
  void onPhoneUsed(DateTime phoneUsageStart, DateTime phoneUsageEnd) async {
    _didPhoneUsageOccur = true;

    if (bedtime.value == null || waketime.value == null) return;

    final Duration usageDuration = phoneUsageEnd.difference(phoneUsageStart);

    final DateTime computedBedtime = _sleepService.calculateNewBedtime(
      bedtime: bedtime.value!,
      phoneUsageStart: phoneUsageStart,
      phoneUsageDuration: usageDuration,
    );

    newBedtime.value = computedBedtime;

    // --- FIX NEGATIVE DEEP SLEEP ---
    DateTime correctedWake = waketime.value!;

    if (correctedWake.isBefore(computedBedtime)) {
      correctedWake = correctedWake.add(Duration(days: 1));
    }
    // -------------------------------

    deepSleepDuration.value = _sleepService.calculateDeepSleep(
      computedBedtime,
      correctedWake,
    );
    saveCurrentDayDeepSleepData(
      _sleepService.calculateDeepSleep(computedBedtime, correctedWake),
    );

    deepSleepDurationList.add(deepSleepDuration.value);

    if (deepSleepDuration.value != null) {
      final todayIndex = DateTime.now().weekday - 1;

      deepSleepHistory[todayIndex] = deepSleepDuration.value!;
      _updateDeepSleepSpots();
      await saveDeepSleepData();

      final day = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][todayIndex];
      final d = deepSleepDuration.value!;
      print("✅ SLEEP DATA - $day: ${d.inHours}h ${d.inMinutes % 60}m");
    }
  }
}
