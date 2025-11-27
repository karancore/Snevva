import 'dart:async';
import 'package:screen_state/screen_state.dart';

class SleepNoticingService {
  StreamSubscription<ScreenStateEvent>? _subscription;
  late Screen _screen;
  
  DateTime? _usageStartTime;
  bool _isUserUsingPhone = false;

  // Callback to notify when phone usage is finished and logic runs
  Function(DateTime start, DateTime end)? onPhoneUsageDetected;

  SleepNoticingService() {
    _screen = Screen();
  }

  void startMonitoring() {
    try {
      _subscription = _screen.screenStateStream!.listen((event) {
        if (event == ScreenStateEvent.SCREEN_ON) {
          _onScreenTurnedOn();
        } else if (event == ScreenStateEvent.SCREEN_OFF) {
          _onScreenTurnedOff();
        }
      });
    } catch (e) {
      print("Screen state error: $e");
    }
  }

  void stopMonitoring() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _onScreenTurnedOn() {
    _usageStartTime = DateTime.now();
    _isUserUsingPhone = true;
    print('🟢 [SleepService] Screen turned ON at $_usageStartTime');
  }

  void _onScreenTurnedOff() {
    if (_isUserUsingPhone && _usageStartTime != null) {
      DateTime usageEndTime = DateTime.now();
      final duration = usageEndTime.difference(_usageStartTime!);
      print('🔴 [SleepService] Screen turned OFF. Usage duration: ${duration.inSeconds}s');
      onPhoneUsageDetected?.call(_usageStartTime!, usageEndTime);
    } else {
      DateTime usageEndTime = DateTime.now();
      print('🔴 [SleepService] Screen turned OFF . Used end time : ${usageEndTime.minute}');

      onPhoneUsageDetected?.call(_usageStartTime!, usageEndTime);
    }
    _isUserUsingPhone = false;
    _usageStartTime = null;
  }

  /// Calculates the new bedtime based on phone usage logic.
  /// 
  /// [bedtime]: The original scheduled bedtime.
  /// [phoneUsageStart]: When the user started using the phone.
  /// [phoneUsageDuration]: How long they used the phone.
  DateTime calculateNewBedtime({
    required DateTime bedtime,
    required DateTime phoneUsageStart,
    required Duration phoneUsageDuration,
  }) {
    final DateTime safeLimit = bedtime.add(const Duration(minutes: 15));

    // CONDITION 1: Phone used within first 15 minutes -> Ignore
    if (phoneUsageStart.isBefore(safeLimit)) {
      print('⏭️ [SleepService] Usage within 15min grace period - IGNORED');
      return bedtime;
    }

    // CONDITION 2: Phone used after safe window
    // New Bedtime = (Usage End Time - 15 mins)
    // Usage End Time = Start + Duration
    final DateTime sleepAfterUsage = phoneUsageStart.add(phoneUsageDuration);
    final DateTime adjustedBedtime = sleepAfterUsage.subtract(const Duration(minutes: 15));
    
    print('✅ [SleepService] Bedtime ADJUSTED!');
    print('   Original: ${bedtime.hour}:${bedtime.minute}');
    print('   New: ${adjustedBedtime.hour}:${adjustedBedtime.minute}');
    print('   Usage duration: ${phoneUsageDuration.inSeconds}s');

    return adjustedBedtime;
  }

  /// Calculates deep sleep duration.
  /// 
  /// [newBedtime]: The adjusted bedtime.
  /// [wakeTime]: The scheduled wake up time.
  Duration calculateDeepSleep(DateTime newBedtime, DateTime wakeTime) {
    Duration deepSleep = wakeTime.difference(newBedtime);
    print("DeepSleep : $deepSleep");
    return deepSleep;
  }
}
