import 'dart:async';
import 'package:screen_state/screen_state.dart';

class SleepNoticingService {
  static const Duration minSleepGap = Duration(minutes: 3);

  StreamSubscription<ScreenStateEvent>? _subscription;


  final Screen _screen = Screen();

  DateTime? _screenOnTime;
  bool _screenIsOn = false;


  // Sleep interval callback
  Function(DateTime start, DateTime end)? onAwakeSegmentDetected;
  Function(DateTime sleepAgainTime)? onSleepResumed;



  void startMonitoring() {
    try {
      _subscription = _screen.screenStateStream?.listen((event) {
        if (event == ScreenStateEvent.SCREEN_OFF) {
          _onScreenTurnedOff();
        } else if (event == ScreenStateEvent.SCREEN_ON) {
          _onScreenTurnedOn();
        }
      });
    } catch (e) {
      print("Screen state error: $e");
    }
  }
  // ✅ FIX: Only record FIRST SCREEN_OFF
  void _onScreenTurnedOn() {
    if (_screenIsOn) return;

    _screenIsOn = true;
    _screenOnTime = DateTime.now();
  }

  void _onScreenTurnedOff() {
    if (!_screenIsOn || _screenOnTime == null) return;

    final now = DateTime.now();
    final onDuration = now.difference(_screenOnTime!);

    if (onDuration < minSleepGap) {
      _reset();
      return;
    }

    // ✅ TRUE awake segment
    onAwakeSegmentDetected?.call(_screenOnTime!, now);
    onSleepResumed?.call(now);;
    _reset();
  }



  void stopMonitoring() {
    _subscription?.cancel();
    _subscription = null;
    _reset();
  }
  void _reset() {
    _screenOnTime = null;
    _screenIsOn = false;
  }

  DateTime calculateNewBedtime({
    required DateTime bedtime,
    required DateTime phoneUsageStart,
    required Duration phoneUsageDuration,
  }) {
    // Use a 15-minute grace period
    const Duration gracePeriod = Duration(minutes: 15);

    final DateTime safeLimit = bedtime.add(gracePeriod);

    // CONDITION 1: Phone used within first 15 minutes → Ignore
    if (phoneUsageStart.isBefore(safeLimit)) {
      print(
        '⏭️ [SleepService] Usage within ${gracePeriod
            .inMinutes}min grace period - IGNORED',
      );
      return bedtime;
    }

    // CONDITION 2: Phone used after safe window
    // New Bedtime = (Usage End Time - 15 mins)
    // Usage End Time = Start + Duration
    final DateTime usageEnd =
    phoneUsageStart.add(phoneUsageDuration);

    final DateTime adjustedBedtime =
    usageEnd.subtract(const Duration(minutes: 15));

    print('✅ [SleepService] Bedtime ADJUSTED!');
    print(' Original: ${bedtime.hour}:${bedtime.minute}');
    print(' New: ${adjustedBedtime.hour}:${adjustedBedtime.minute}');
    print(' Usage duration: ${phoneUsageDuration.inSeconds}s');

    return adjustedBedtime;
  }

  Duration calculateDeepSleep(DateTime newBedtime, DateTime wakeTime) {
    Duration deepSleep = wakeTime.difference(newBedtime);
    print("DeepSleep : $deepSleep");
    return deepSleep;
  }
}



