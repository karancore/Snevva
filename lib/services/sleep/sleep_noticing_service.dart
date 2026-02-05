import 'dart:async';
import 'package:flutter/material.dart';
import 'package:screen_state/screen_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SleepNoticingService
///
/// Purpose:
/// - Listen to screen ON/OFF events and persist all screen-OFF intervals to
///   SharedPreferences using per-night keys.
/// - Intervals are stored only within the user's configured [bedtime, waketime]
///   window and keyed by the bed date (yyyy-mm-dd).
/// - Format:
///   - last_screen_off_yyyy-mm-dd: ISO8601 string
///   - sleep_intervals_yyyy-mm-dd: comma-separated list of "startISO|endISO"
///
/// The SleepController later reads these intervals and computes the total sleep
/// duration by summing/merging them. If the screen stays OFF until wake, the
/// controller closes any open interval at wake time.
class SleepNoticingService {
  static const Duration minSleepGap = Duration(minutes: 3);

  // Keys mirrored by SleepController into SharedPreferences so the service can
  // run independently of GetX availability.
  static const String _bedtimeKey = 'user_bedtime_ms';
  static const String _waketimeKey = 'user_waketime_ms';

  StreamSubscription<ScreenStateEvent>? _subscription;
  final Screen _screen = Screen();

  // ──────────────────────────────────────────────────────────────────────────
  // Public API
  // ──────────────────────────────────────────────────────────────────────────

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
      // Avoid crashing the app due to plugin errors
      // ignore: avoid_print
      print("Screen state error: $e");
    }
  }

  void stopMonitoring() {
    _subscription?.cancel();
    _subscription = null;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Event handlers (persist OFF intervals)
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _onScreenTurnedOff() async {
    final window = await _computeActiveSleepWindow();
    if (window == null) return; // Bed/wake not set

    final now = DateTime.now();
    if (!_isWithinWindow(now, window.start, window.end)) return; // outside window

    final prefs = await SharedPreferences.getInstance();
    final lastOffKey = 'last_screen_off_${window.dateKey}';
    await prefs.setString(lastOffKey, now.toIso8601String());
    // ignore: avoid_print
    print('🔒 SCREEN_OFF recorded for ${window.dateKey} at $now');
  }

  Future<void> _onScreenTurnedOn() async {
    final window = await _computeActiveSleepWindow();
    if (window == null) return;

    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();

    final lastOffKey = 'last_screen_off_${window.dateKey}';
    final intervalsKey = 'sleep_intervals_${window.dateKey}';

    final lastOffIso = prefs.getString(lastOffKey);
    if (lastOffIso == null) return; // no open OFF segment

    DateTime lastOff;
    try {
      lastOff = DateTime.parse(lastOffIso);
    } catch (_) {
      // corrupt value; clear and ignore
      await prefs.remove(lastOffKey);
      return;
    }

    // Clamp interval to [window.start, window.end]
    DateTime start = lastOff.isBefore(window.start) ? window.start : lastOff;
    DateTime end = now.isAfter(window.end) ? window.end : now;

    if (!end.isAfter(start)) {
      // Non-positive duration or outside window; clear and ignore
      await prefs.remove(lastOffKey);
      return;
    }

    final duration = end.difference(start);
    if (duration < minSleepGap) {
      // Too short; ignore noise
      await prefs.remove(lastOffKey);
      return;
    }

    // Append interval to existing list
    final existing = prefs.getString(intervalsKey);
    final newEntry = '${start.toIso8601String()}|${end.toIso8601String()}';
    final updated = (existing == null || existing.isEmpty)
        ? newEntry
        : '$existing,$newEntry';

    await prefs.setString(intervalsKey, updated);
    await prefs.remove(lastOffKey); // close the open OFF segment

    // ignore: avoid_print
    print('💾 Saved OFF interval to $intervalsKey: $newEntry');
  }

  // ───────────────────────────────────────────────────────────────────��──────
  // Helpers
  // ──────────────────────────────────────────────────────────────────────────

  bool _isWithinWindow(DateTime t, DateTime start, DateTime end) {
    // inclusive start, exclusive end
    final afterStart = !t.isBefore(start);
    final beforeEnd = t.isBefore(end) || t.isAtSameMomentAs(end);
    return afterStart && beforeEnd;
  }

  Future<_SleepWindow?> _computeActiveSleepWindow() async {
    final prefs = await SharedPreferences.getInstance();

    int? bedMin = prefs.getInt(_bedtimeKey);
    int? wakeMin = prefs.getInt(_waketimeKey);

    // Fallback: no stored values
    if (bedMin == null || wakeMin == null) {
      return null;
    }

    final TimeOfDay bedTod = TimeOfDay(hour: bedMin ~/ 60, minute: bedMin % 60);
    final TimeOfDay wakeTod =
        TimeOfDay(hour: wakeMin ~/ 60, minute: wakeMin % 60);

    final now = DateTime.now();
    final start = _resolveSleepStart(now, bedTod);
    final end = _resolveSleepEnd(start, wakeTod);

    final key = _dateKey(start);
    return _SleepWindow(start: start, end: end, dateKey: key);
  }

  DateTime _buildDateTime(DateTime base, TimeOfDay tod) {
    return DateTime(base.year, base.month, base.day, tod.hour, tod.minute);
  }

  DateTime _resolveSleepStart(DateTime now, TimeOfDay bedtime) {
    DateTime start = _buildDateTime(now, bedtime);
    // If bedtime is in the future relative to now (with small grace), the start
    // belongs to yesterday.
    if (start.isAfter(now.add(const Duration(minutes: 5)))) {
      start = start.subtract(const Duration(days: 1));
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
    if (!end.isAfter(sleepStart)) {
      end = end.add(const Duration(days: 1));
    }
    return end;
  }

  String _dateKey(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

class _SleepWindow {
  final DateTime start;
  final DateTime end;
  final String dateKey;
  _SleepWindow({required this.start, required this.end, required this.dateKey});
}
