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
      _subscription = _screen.screenStateStream?.listen((event) {
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
    DateTime now = DateTime.now();

    // CASE 1: If waking from sleep
    if (_usageStartTime != null && !_isUserUsingPhone) {
      print("☀️ [SleepService] Woke up at ${now.hour}:${now.minute}");

      onPhoneUsageDetected?.call(_usageStartTime!, now);

      _usageStartTime = null;
      _isUserUsingPhone = true;
      return;
    }

    // CASE 2: Normal phone usage start
    _usageStartTime = now;
    _isUserUsingPhone = true;

    print(
      "📱 [SleepService] Screen ON. Usage START at ${now.hour}:${now.minute}",
    );
  }

  void _onScreenTurnedOff() {
    DateTime usageEndTime = DateTime.now();

    // CASE 1: No start time yet → treat this as sleep start
    if (_usageStartTime == null) {
      _usageStartTime = usageEndTime;
      _isUserUsingPhone = false;

      print(
        '🌙 [SleepService] Sleep START at ${usageEndTime.hour}:${usageEndTime.minute}',
      );
      return;
    }

    // CASE 2: Has valid start time → calculate duration
    if (_isUserUsingPhone) {
      final duration = usageEndTime.difference(_usageStartTime!);
      print(
        '😴 [SleepService] Sleep/Usage End. Duration: ${duration.inMinutes} mins',
      );

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
    // Use a 15-minute grace period (was incorrectly 5 seconds before)
    final Duration gracePeriod = const Duration(minutes: 15);
    final DateTime safeLimit = bedtime.add(gracePeriod);

    // CONDITION 1: Phone used within first 15 minutes -> Ignore
    if (phoneUsageStart.isBefore(safeLimit)) {
      print(
        '⏭️ [SleepService] Usage within ${gracePeriod.inMinutes}min grace period - IGNORED',
      );
      return bedtime;
    }

    // CONDITION 2: Phone used after safe window
    // New Bedtime = (Usage End Time - 15 mins)
    // Usage End Time = Start + Duration
    final DateTime usageEnd = phoneUsageStart.add(phoneUsageDuration);
    final DateTime adjustedBedtime = usageEnd.subtract(
      const Duration(minutes: 15),
    );

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
