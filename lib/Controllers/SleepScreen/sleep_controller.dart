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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SleepController extends GetxController with WidgetsBindingObserver {
  // --------------------------------------------------
  // USER SETTINGS
  // --------------------------------------------------
  Rx<TimeOfDay> bedTime = TimeOfDay(hour: 22, minute: 0).obs;
  Rx<TimeOfDay> wakeupTime = TimeOfDay(hour: 6, minute: 30).obs;

  // --------------------------------------------------
  // MONITORING FLAGS
  // --------------------------------------------------
  RxBool isMonitoring = false.obs;

  bool hasWokenUp = false;
  bool _wakeHandled = false;
  bool _wakeUpTriggeredToday = false;

  Timer? _wakeUpChecker;

  // --------------------------------------------------
  // STATE TRACKING
  // --------------------------------------------------
  Rxn<DateTime> sleepCandidateStart = Rxn<DateTime>();
  Rxn<DateTime> adjustedBedtime = Rxn<DateTime>();
  Rxn<Duration> actualSleepDuration = Rxn<Duration>();

  RxList<double> sleepHoursHistory = <double>[].obs;
  RxList<String> activityLog = <String>[].obs;

  // --------------------------------------------------
  // LIFECYCLE
  // --------------------------------------------------
  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _wakeUpChecker?.cancel();
    super.onClose();
  }

  // --------------------------------------------------
  // APP LIFECYCLE HANDLING
  // --------------------------------------------------
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!isMonitoring.value) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      _onScreenOff();
    }

    if (state == AppLifecycleState.resumed) {
      _onScreenOn();
    }
  }

  // --------------------------------------------------
  // SCREEN OFF → Possible Sleep Start
  // --------------------------------------------------
  void _onScreenOff() {
    if (sleepCandidateStart.value != null) return;

    _wakeHandled = false;
    sleepCandidateStart.value = DateTime.now();
    _log('📴 Screen OFF – start candidate: ${_ts(sleepCandidateStart.value!)}');
  }

  // --------------------------------------------------
  // SCREEN ON → User Woke Up or Returned
  // --------------------------------------------------
  void _onScreenOn() {
    if (_wakeHandled) return;
    _wakeHandled = true;

    // Already woke up earlier
    if (hasWokenUp) {
      _log('⛔ Wake ignored — already marked woke up');
      sleepCandidateStart.value = null;
      return;
    }

    if (sleepCandidateStart.value == null) return;

    final now = DateTime.now();
    final awayDuration = now.difference(sleepCandidateStart.value!);

    // Ignore short returns (<30s)
    if (awayDuration.inSeconds < 30) {
      _log('⏭️ Returned <30 sec — ignored');
      sleepCandidateStart.value = null;
      return;
    }

    // Adjust bedtime
    final bedtimeToday = DateTime(
      now.year,
      now.month,
      now.day,
      bedTime.value.hour,
      bedTime.value.minute,
    );

    adjustedBedtime.value = bedtimeToday
        .add(awayDuration)
        .add(const Duration(minutes: 1));

    _log('✅ Bedtime adjusted → ${_ts(adjustedBedtime.value!)}');
    _log('➕ Added ${awayDuration.inMinutes + 1} minutes');

    sleepCandidateStart.value = null;
  }

  // --------------------------------------------------
  // MONITORING CONTROL
  // --------------------------------------------------
  void startMonitoring() {
    isMonitoring.value = true;

    sleepCandidateStart.value = null;
    adjustedBedtime.value = null;
    actualSleepDuration.value = null;

    sleepHoursHistory.clear();
    activityLog.clear();

    hasWokenUp = false;
    _wakeUpTriggeredToday = false;

    _startWakeChecker();

    _log('🚀 Monitoring started');
    _log('🌙 Target bedtime: ${bedTime.value.format(Get.context!)}');
  }

  void stopMonitoring() {
    isMonitoring.value = false;
    _wakeUpChecker?.cancel();
    _log('🛑 Monitoring stopped');
  }

  // --------------------------------------------------
  // WAKE-UP CHECKER
  // --------------------------------------------------
  void _startWakeChecker() {
    _wakeUpChecker?.cancel();

    _wakeUpChecker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!isMonitoring.value) return;

      final now = DateTime.now();

      final targetWake = DateTime(
        now.year,
        now.month,
        now.day,
        wakeupTime.value.hour,
        wakeupTime.value.minute,
      );

      if (_wakeUpTriggeredToday) return;

      if (now.isAfter(targetWake) || now.isAtSameMomentAs(targetWake)) {
        hasWokenUp = true;

        _log('⏰ Auto wake triggered');
        calculateActualSleep();

        _wakeUpTriggeredToday = true;
      }
    });

    _log('⏱️ Wake watcher started');
  }

  Future<void> updateBedTimeFromTimestamp(
      DateTime sleepStart,
      DateTime wakeUp,
      ) async {
    bedTime.value = TimeOfDay(
      hour: sleepStart.hour,
      minute: sleepStart.minute,
    );

    wakeupTime.value = TimeOfDay(
      hour: wakeUp.hour,
      minute: wakeUp.minute,
    );
  }

  // --------------------------------------------------
  // SLEEP CALCULATION
  // --------------------------------------------------
  void calculateActualSleep() {
    if (adjustedBedtime.value == null) {
      _log('⚠️ No adjusted bedtime set');
      return;
    }

    final now = DateTime.now();
    actualSleepDuration.value = now.difference(adjustedBedtime.value!);

    final hours = actualSleepDuration.value!.inMinutes / 60.0;
    sleepHoursHistory.add(hours);

    hasWokenUp = true;

    _log('⏰ Woke at ${_ts(now)}');
    _log('😴 Slept: ${_fmt(actualSleepDuration.value!)}');
  }

  // --------------------------------------------------
  // HELPERS
  // --------------------------------------------------
  void _log(String m) {
    activityLog.insert(0, '${_ts(DateTime.now())} - $m');
    if (activityLog.length > 30) activityLog.removeLast();
  }

  Duration get sleepDuration {
    if (actualSleepDuration.value != null) {
      return actualSleepDuration.value!;
    }

    if (adjustedBedtime.value != null && hasWokenUp) {
      final wakeTime = DateTime.now();
      return wakeTime.difference(adjustedBedtime.value!);
    }

    // Default fallback using static bedtime/wake
    final now = DateTime.now();

    final bed = DateTime(
      now.year,
      now.month,
      now.day,
      bedTime.value.hour,
      bedTime.value.minute,
    );

    var wake = DateTime(
      now.year,
      now.month,
      now.day,
      wakeupTime.value.hour,
      wakeupTime.value.minute,
    );

    if (wake.isBefore(bed)) {
      wake = wake.add(const Duration(days: 1));
    }

    return wake.difference(bed);
  }

  Future<void> updateSleepTimes(
      TimeOfDay newBedTime,
      TimeOfDay newWakeTime,
      ) async {
    bedTime.value = newBedTime;
    wakeupTime.value = newWakeTime;

    print("Updated bedtime: ${bedTime.value.format(Get.context!)}");
    print("Updated wake time: ${wakeupTime.value.format(Get.context!)}");

    print(
      "Sleep duration: ${sleepDuration.inHours}h ${sleepDuration.inMinutes % 60}m",
    );
  }

  String _ts(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

  String _fmt(Duration d) =>
      '${d.inHours}h ${d.inMinutes % 60}m';
}
