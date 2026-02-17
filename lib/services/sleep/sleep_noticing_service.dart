import 'dart:async';
import 'package:flutter/material.dart';
import 'package:screen_state/screen_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SleepNoticingService
///
/// DEBUG VERSION
/// - Logs EVERYTHING related to:
///   • sleep window calculation
///   • sleep segment detection (SCREEN_OFF)
///   • awake detection (SCREEN_ON)
///   • interval persistence & rejection reasons
class SleepNoticingService {
  static const Duration minSleepGap = Duration(minutes: 3);

  static const String _bedtimeKey = 'user_bedtime_ms';
  static const String _waketimeKey = 'user_waketime_ms';

  StreamSubscription<ScreenStateEvent>? _subscription;
  final Screen _screen = Screen();

  // ─────────────────────────────────────────────
  // PUBLIC API
  // ─────────────────────────────────────────────

  void startMonitoring() {
    debugPrint('🚀 SleepNoticingService.startMonitoring');

    try {
      _subscription = _screen.screenStateStream?.listen((event) {
        debugPrint('📱 Screen event received: $event');

        if (event == ScreenStateEvent.SCREEN_OFF) {
          print("SCREEN_OFF");
          _onScreenTurnedOff();
        } else if (event == ScreenStateEvent.SCREEN_ON) {
          print("SCREEN_OFF");
          _onScreenTurnedOn();
        }
      });
    } catch (e) {
      debugPrint('❌ Screen state stream error: $e');
    }
  }

  void stopMonitoring() {
    debugPrint('🛑 SleepNoticingService.stopMonitoring');
    _subscription?.cancel();
    _subscription = null;
  }

  // ─────────────────────────────────────────────
  // SCREEN OFF → POSSIBLE SLEEP START
  // ─────────────────────────────────────────────

  Future<void> _onScreenTurnedOff() async {
    debugPrint('🌙 SCREEN_OFF detected');

    final window = await _computeActiveSleepWindow();
    if (window == null) {
      debugPrint('⛔ Sleep window not available (bed/wake missing)');
      return;
    }

    final now = DateTime.now();
    debugPrint('   now: $now');
    debugPrint('   sleep window: ${window.start} → ${window.end}');
    debugPrint('   dateKey: ${window.dateKey}');

    if (!_isWithinWindow(now, window.start, window.end)) {
      debugPrint('⛔ SCREEN_OFF ignored (outside sleep window)');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final lastOffKey = 'last_screen_off_${window.dateKey}';

    await prefs.setString(lastOffKey, now.toIso8601String());

    debugPrint('🔒 SCREEN_OFF saved → $lastOffKey = $now');
  }

  // ─────────────────────────────────────────────
  // SCREEN ON → AWAKE SEGMENT
  // ─────────────────────────────────────────────

  Future<void> _onScreenTurnedOn() async {
    debugPrint('🌞 SCREEN_ON detected');

    final window = await _computeActiveSleepWindow();
    if (window == null) {
      debugPrint('⛔ Sleep window not available');
      return;
    }

    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();

    final lastOffKey = 'last_screen_off_${window.dateKey}';
    final intervalsKey = 'sleep_intervals_${window.dateKey}';

    final lastOffIso = prefs.getString(lastOffKey);
    if (lastOffIso == null) {
      debugPrint('ℹ️ No open sleep segment (no SCREEN_OFF before)');
      return;
    }

    DateTime lastOff;
    try {
      lastOff = DateTime.parse(lastOffIso);
    } catch (e) {
      debugPrint('❌ Failed to parse last SCREEN_OFF: $e');
      await prefs.remove(lastOffKey);
      return;
    }

    debugPrint('🕰️ Raw OFF interval: $lastOff → $now');

    // Clamp interval to sleep window
    DateTime start = lastOff.isBefore(window.start) ? window.start : lastOff;
    DateTime end = now.isAfter(window.end) ? window.end : now;

    debugPrint('✂️ Clamped interval: $start → $end');

    if (!end.isAfter(start)) {
      debugPrint('⛔ Ignored (non-positive interval)');
      await prefs.remove(lastOffKey);
      return;
    }

    final duration = end.difference(start);
    debugPrint('⏱️ Interval duration: ${duration.inMinutes} min');

    if (duration < minSleepGap) {
      debugPrint('⛔ Ignored (below minSleepGap ${minSleepGap.inMinutes} min)');
      await prefs.remove(lastOffKey);
      return;
    }

    // Append interval
    final existing = prefs.getString(intervalsKey);
    final newEntry = '${start.toIso8601String()}|${end.toIso8601String()}';

    final updated =
        (existing == null || existing.isEmpty)
            ? newEntry
            : '$existing,$newEntry';

    await prefs.setString(intervalsKey, updated);
    await prefs.remove(lastOffKey);

    debugPrint('💾 Interval saved → $intervalsKey');
    debugPrint('   entry: $newEntry');
    debugPrint('   all intervals: $updated');
  }

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────

  bool _isWithinWindow(DateTime t, DateTime start, DateTime end) {
    final inside =
        (!t.isBefore(start)) && (t.isBefore(end) || t.isAtSameMomentAs(end));

    debugPrint('🧪 isWithinWindow($t) → $inside');

    return inside;
  }

  Future<_SleepWindow?> _computeActiveSleepWindow() async {
    debugPrint('🧠 Computing active sleep window');

    final prefs = await SharedPreferences.getInstance();
    final bedMin = prefs.getInt(_bedtimeKey);
    final wakeMin = prefs.getInt(_waketimeKey);

    debugPrint('   stored bedMin: $bedMin');
    debugPrint('   stored wakeMin: $wakeMin');

    if (bedMin == null || wakeMin == null) {
      debugPrint('⛔ Missing bedtime or waketime');
      return null;
    }

    final bedTod = TimeOfDay(hour: bedMin ~/ 60, minute: bedMin % 60);
    final wakeTod = TimeOfDay(hour: wakeMin ~/ 60, minute: wakeMin % 60);

    final now = DateTime.now();

DateTime sleepStartToday = _buildDateTime(now, bedTod);
DateTime sleepStart;

if (bedMin > wakeMin) {
  // CROSS MIDNIGHT CASE (e.g., 23:00 → 06:00)

  if (now.isBefore(_buildDateTime(now, wakeTod))) {
    // After midnight but before wake time → belongs to yesterday's sleep
    sleepStart = sleepStartToday.subtract(const Duration(days: 1));
  } else if (now.isBefore(sleepStartToday)) {
    // Before bedtime tonight → still yesterday's sleep window
    sleepStart = sleepStartToday.subtract(const Duration(days: 1));
  } else {
    // After bedtime tonight
    sleepStart = sleepStartToday;
  }

} else {
  // NORMAL SAME-DAY SLEEP (e.g., 22:00 → 23:00)
  sleepStart = sleepStartToday;
}

final sleepEnd = _resolveSleepEnd(sleepStart, wakeTod);
final key = _dateKey(sleepStart);


    debugPrint('🛏️ BedTime TOD: $bedTod');
    debugPrint('⏰ WakeTime TOD: $wakeTod');
    debugPrint('🌙 Sleep window resolved: $sleepStart → $sleepEnd');
    debugPrint('🗓️ dateKey: $key');

    return _SleepWindow(start: sleepStart, end: sleepEnd, dateKey: key);
  }

  DateTime _buildDateTime(DateTime base, TimeOfDay tod) {
    return DateTime(base.year, base.month, base.day, tod.hour, tod.minute);
  }

  DateTime _resolveSleepStart(DateTime now, TimeOfDay bedtime) {
    DateTime start = _buildDateTime(now, bedtime);

    debugPrint('🛠️ resolveSleepStart');
    debugPrint('   now: $now');
    debugPrint('   raw start: $start');

    if (start.isAfter(now.add(const Duration(minutes: 5)))) {
      start = start.subtract(const Duration(days: 1));
      debugPrint('   ⏪ shifted to yesterday: $start');
    }

    return start;
  }

  DateTime _resolveSleepEnd(DateTime sleepStart, TimeOfDay waketime) {
    DateTime end = DateTime(
      sleepStart.year,
      sleepStart.month,
      sleepStart.day,
      waketime.hour,
      waketime.minute,
    );

    debugPrint('🛠️ resolveSleepEnd');
    debugPrint('   raw end: $end');

    if (!end.isAfter(sleepStart)) {
      end = end.add(const Duration(days: 1));
      debugPrint('   ➕ shifted to next day: $end');
    }

    return end;
  }

  String _dateKey(DateTime d) {
    final key =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    debugPrint('🗓️ dateKey computed: $key');
    return key;
  }
}

// ─────────────────────────────────────────────

class _SleepWindow {
  final DateTime start;
  final DateTime end;
  final String dateKey;

  _SleepWindow({required this.start, required this.end, required this.dateKey});
}
