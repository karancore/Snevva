import 'dart:async';
import 'package:flutter/material.dart';
import 'package:screen_state/screen_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SleepNoticingService
///
/// Automatically tracks screen off/on events within the user's sleep window
/// and aggregates sleep intervals for total sleep time calculation.
class SleepNoticingService {
  static const Duration minSleepGap = Duration(minutes: 3);

  // ✅ FIX: Use the same plain keys as SharedPreferences everywhere — no 'flutter.' prefix
  static const String _bedtimeKey = 'user_bedtime_ms';
  static const String _waketimeKey = 'user_waketime_ms';

  StreamSubscription<ScreenStateEvent>? _subscription;
  final Screen _screen = Screen();

  // Add this: Track current screen state (assume 'on' initially; first event will correct it)
  bool _screenIsOn = true;

  // ─────────────────────────────────────────────
  // PUBLIC API
  // ─────────────────────────────────────────────

  void startMonitoring() {
    if (_subscription != null) {
      debugPrint('ℹ️ SleepNoticingService already monitoring');
      return;
    }

    debugPrint('🚀 SleepNoticingService.startMonitoring');

    try {
      _subscription = _screen.screenStateStream.listen((event) {
        debugPrint('📱 Screen event received: $event');

        if (event == ScreenStateEvent.SCREEN_OFF) {
          _onScreenTurnedOff();
        } else if (event == ScreenStateEvent.SCREEN_ON) {
          _onScreenTurnedOn();
        }
      });

      debugPrint('✅ Screen state monitoring started');
    } catch (e) {
      debugPrint('❌ Screen state stream error: $e');
    }
  }

  void stopMonitoring() {
    debugPrint('🛑 SleepNoticingService.stopMonitoring');
    _subscription?.cancel();
    _subscription = null;
  }

  // Add this new method: Call this when sleep starts (after window is set in the background service)
  Future<void> initializeForSleepWindow() async {
    final prefs = await SharedPreferences.getInstance();
    final window = await _computeActiveSleepWindow(prefs);
    if (window == null) return;

    final now = DateTime.now();
    if (_isWithinWindow(now, window.start, window.end) && !_screenIsOn) {
      final lastOffKey = 'last_screen_off_${window.dateKey}';
      // Initialize open interval from window start
      await prefs.setString(lastOffKey, window.start.toIso8601String());
      debugPrint(
        '🔒 Initialized open interval from window start: ${window.start}',
      );
    }
  }

  // ─────────────────────────────────────────────
  // SCREEN OFF → POSSIBLE SLEEP START
  // ─────────────────────────────────────────────

  Future<void> _onScreenTurnedOff() async {
    debugPrint('🌙 SCREEN_OFF detected');
    _screenIsOn = false; // Add this: Update state

    final prefs = await SharedPreferences.getInstance();

    // Check if sleep tracking is active
    final isSleeping = prefs.getBool("is_sleeping") ?? false;
    if (!isSleeping) {
      debugPrint('⛔ Sleep tracking not active, ignoring SCREEN_OFF');
      return;
    }

    final window = await _computeActiveSleepWindow(prefs);
    if (window == null) {
      debugPrint('⛔ Sleep window not available');
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

    final lastOffKey = 'last_screen_off_${window.dateKey}';
    await prefs.setString(lastOffKey, now.toIso8601String());

    debugPrint('🔒 SCREEN_OFF saved → $lastOffKey = $now');
  }

  // ─────────────────────────────────────────────
  // SCREEN ON → AWAKE SEGMENT, SAVE INTERVAL
  // ─────────────────────────────────────────────

  Future<void> _onScreenTurnedOn() async {
    debugPrint('🌞 SCREEN_ON detected');
    _screenIsOn = true; // Add this: Update state

    final prefs = await SharedPreferences.getInstance();

    // Check if sleep tracking is active
    final isSleeping = prefs.getBool("is_sleeping") ?? false;
    if (!isSleeping) {
      debugPrint('⛔ Sleep tracking not active, ignoring SCREEN_ON');
      return;
    }

    final window = await _computeActiveSleepWindow(prefs);
    if (window == null) {
      debugPrint('⛔ Sleep window not available');
      return;
    }

    final now = DateTime.now();
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
    final intervals = _parseIntervals(existing);
    intervals.add(_TimeInterval(start: start, end: end));
    final merged = _mergeIntervals(intervals);
    final serialized = _serializeIntervals(merged);

    await prefs.setString(intervalsKey, serialized);
    await prefs.remove(lastOffKey);

    debugPrint('💾 Interval saved → $intervalsKey');
    debugPrint('   merged intervals: ${merged.length}');
  }

  // ─────────────────────────────────────────────
  // PUBLIC UTILITY: Get total sleep time
  // ─────────────────────────────────────────────

  // ... existing code ...

  Future<int> getTotalSleepMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    final window = await _computeActiveSleepWindow(prefs);

    if (window == null) return 0;

    final intervalsKey = 'sleep_intervals_${window.dateKey}';
    final intervalsStr = prefs.getString(intervalsKey);

    int totalMinutes = 0;

    // Count saved intervals (merged to avoid duplicate/overlapping entries)
    if (intervalsStr != null && intervalsStr.isNotEmpty) {
      final merged = _mergeIntervals(_parseIntervals(intervalsStr));
      for (final interval in merged) {
        totalMinutes += interval.end.difference(interval.start).inMinutes;
      }
    }

    // Check for open interval (screen currently off)
    final lastOffKey = 'last_screen_off_${window.dateKey}';
    final lastOffStr = prefs.getString(lastOffKey);
    if (lastOffStr != null) {
      try {
        final lastOff = DateTime.parse(lastOffStr);
        final now = DateTime.now();

        // Clamp to window
        DateTime start =
            lastOff.isBefore(window.start) ? window.start : lastOff;
        DateTime end = now.isAfter(window.end) ? window.end : now;

        if (end.isAfter(start)) {
          final openIntervalMinutes = end.difference(start).inMinutes;
          if (openIntervalMinutes >= minSleepGap.inMinutes) {
            totalMinutes += openIntervalMinutes;
            debugPrint(
              '📱 Open interval (screen still off): $openIntervalMinutes mins',
            );
          }
        }
      } catch (e) {
        debugPrint('⚠️ Failed to parse open interval: $e');
      }
    }

    debugPrint('📊 Total sleep from intervals + open: $totalMinutes mins');
    return totalMinutes;
  }

  // ... rest of existing code ...
  // ─────────────────────────────────────────────
  // PUBLIC UTILITY: Clear sleep data
  // ─────────────────────────────────────────────

  Future<void> clearSleepData(String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sleep_intervals_$dateKey');
    await prefs.remove('last_screen_off_$dateKey');
    debugPrint('🗑️ Cleared sleep data for $dateKey');
  }

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────

  bool _isWithinWindow(DateTime t, DateTime start, DateTime end) {
    final inside =
        (!t.isBefore(start)) && (t.isBefore(end) || t.isAtSameMomentAs(end));
    return inside;
  }

  Future<_SleepWindow?> _computeActiveSleepWindow(
    SharedPreferences prefs,
  ) async {
    debugPrint('🧠 Computing active sleep window');

    // First try to get from current sleep session
    final currentWindowStart = prefs.getString("current_sleep_window_start");
    final currentWindowEnd = prefs.getString("current_sleep_window_end");
    final currentWindowKey = prefs.getString("current_sleep_window_key");

    if (currentWindowStart != null &&
        currentWindowEnd != null &&
        currentWindowKey != null) {
      debugPrint('✅ Using current sleep session window');
      return _SleepWindow(
        start: DateTime.parse(currentWindowStart),
        end: DateTime.parse(currentWindowEnd),
        dateKey: currentWindowKey,
      );
    }

    // Fallback to calculating from bedtime/waketime
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
    return key;
  }

  List<_TimeInterval> _parseIntervals(String? intervals) {
    if (intervals == null || intervals.isEmpty) {
      return <_TimeInterval>[];
    }

    final parsed = <_TimeInterval>[];
    for (final raw in intervals.split(',')) {
      final parts = raw.split('|');
      if (parts.length != 2) continue;
      try {
        final start = DateTime.parse(parts[0]);
        final end = DateTime.parse(parts[1]);
        if (end.isAfter(start)) {
          parsed.add(_TimeInterval(start: start, end: end));
        }
      } catch (_) {}
    }
    return parsed;
  }

  List<_TimeInterval> _mergeIntervals(List<_TimeInterval> intervals) {
    if (intervals.isEmpty) return <_TimeInterval>[];

    final sorted = [...intervals]
      ..sort((a, b) => a.start.compareTo(b.start));

    final merged = <_TimeInterval>[sorted.first];
    for (var i = 1; i < sorted.length; i++) {
      final current = sorted[i];
      final last = merged.last;

      if (!current.start.isAfter(last.end)) {
        final end = current.end.isAfter(last.end) ? current.end : last.end;
        merged[merged.length - 1] = _TimeInterval(start: last.start, end: end);
      } else {
        merged.add(current);
      }
    }

    return merged;
  }

  String _serializeIntervals(List<_TimeInterval> intervals) {
    return intervals
        .map((i) => '${i.start.toIso8601String()}|${i.end.toIso8601String()}')
        .join(',');
  }
}

// ─────────────────────────────────────────────

class _SleepWindow {
  final DateTime start;
  final DateTime end;
  final String dateKey;

  _SleepWindow({required this.start, required this.end, required this.dateKey});
}

class _TimeInterval {
  final DateTime start;
  final DateTime end;

  const _TimeInterval({required this.start, required this.end});
}
