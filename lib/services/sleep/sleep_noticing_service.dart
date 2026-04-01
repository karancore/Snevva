import 'dart:async';

import 'package:flutter/material.dart';
import 'package:screen_state/screen_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SleepNoticingService
//
// Architecture: ALWAYS-ON screen monitoring, window-clipped calculation.
//
// The service runs 24/7. Screen-off/on events are written to a rolling
// 24-hour buffer keyed by calendar date, WITHOUT any is_sleeping check.
// Sleep duration is calculated from those raw intervals by clipping them
// to the user's sleep window at save-time (inside _stopSleepAndSave).
//
// This guarantees that no sleep data is lost even if the bedtime heartbeat
// fires late, the app is never opened, or the service restarts mid-night.
// ─────────────────────────────────────────────────────────────────────────────

class SleepNoticingService {
  static const Duration minSleepGap = Duration(minutes: 3);

  // SharedPrefs key prefixes used by the rolling 24h buffer.
  // All keys are date-scoped so old data cannot pollute a fresh night.
  //
  //   rolling_screen_off_<YYYY-MM-DD>   → ISO timestamp of last SCREEN_OFF
  //                                        (open interval anchor, null when
  //                                         screen is on / interval closed)
  //   raw_intervals_<YYYY-MM-DD>        → comma-separated "start|end" pairs
  //                                        of closed screen-off intervals
  //
  // Sleep-window keys (written by unified_background_service, read here):
  //   current_sleep_window_start        → ISO DateTime window start
  //   current_sleep_window_end          → ISO DateTime window end
  //   current_sleep_window_key          → YYYY-MM-DD date key for the window
  //   user_bedtime_ms                   → bedtime minutes-of-day
  //   user_waketime_ms                  → waketime minutes-of-day

  static const String _bedtimeKey = 'user_bedtime_ms';
  static const String _waketimeKey = 'user_waketime_ms';

  StreamSubscription<ScreenStateEvent>? _subscription;
  final Screen _screen = Screen();

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC API
  // ─────────────────────────────────────────────────────────────────────────

  /// Start listening to screen events.  Call once at service boot and leave
  /// running forever (24/7).  Idempotent — safe to call again after restart.
  void startMonitoring() {
    if (_subscription != null) {
      debugPrint('ℹ️ SleepNoticingService already monitoring');
      return;
    }

    debugPrint('🚀 SleepNoticingService.startMonitoring (always-on)');

    try {
      _subscription = _screen.screenStateStream.listen((event) {
        debugPrint('📱 Screen event: $event');

        if (event == ScreenStateEvent.SCREEN_OFF) {
          _onScreenTurnedOff();
        } else if (event == ScreenStateEvent.SCREEN_ON) {
          _onScreenTurnedOn();
        }
      });

      debugPrint('✅ Always-on screen monitoring started');
    } catch (e) {
      debugPrint('❌ Screen state stream error: $e');
    }
  }

  /// Stop listening.  Only called when the entire service is stopping.
  void stopMonitoring() {
    debugPrint('🛑 SleepNoticingService.stopMonitoring');
    _subscription?.cancel();
    _subscription = null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // initializeForSleepWindow
  //
  // Seeds the rolling anchor from window.start when:
  //   • the service just booted inside an active window AND
  //   • we don't already know the real screen state (no anchor in prefs).
  //
  // This is conservative: if the screen was actually ON when the service
  // started the next SCREEN_ON event will close a tiny interval (which may
  // be filtered by minSleepGap).  If it was OFF we accumulate correctly.
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> initializeForSleepWindow() async {
    final prefs = await SharedPreferences.getInstance();
    final window = _computeActiveSleepWindowFromPrefs(prefs);
    if (window == null) return;

    final now = DateTime.now();
    if (!_isWithinWindow(now, window.start, window.end)) return;

    final todayKey = _todayDateKey();
    final rollingOffKey = 'rolling_screen_off_$todayKey';

    final existing = prefs.getString(rollingOffKey);
    if (existing == null) {
      // Seed anchor at window.start — conservative assumption: screen was off.
      await prefs.setString(rollingOffKey, window.start.toIso8601String());
      debugPrint(
        '🔒 initializeForSleepWindow: seeded rolling anchor at ${window.start}',
      );
    } else {
      debugPrint(
        'ℹ️ initializeForSleepWindow: rolling anchor already exists ($existing)',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // getTotalSleepMinutes
  //
  // Computes sleep minutes by:
  //   1. Reading raw_intervals_<dateKey> (all closed screen-off periods today)
  //   2. Adding the open interval (rolling_screen_off still set → screen is off)
  //   3. Clipping every interval to [window.start, window.end]
  //   4. Merging overlaps and summing
  //
  // If window is null (no sleep window configured) returns 0.
  // ─────────────────────────────────────────────────────────────────────────

  /// Computes total sleep minutes, clipped to the given sleep window.
  ///
  /// Callers may pass [windowStart], [windowEnd], and [windowDateKey] to
  /// explicitly pin the window (from the unified_background_service's
  /// current_sleep_window_* prefs). If omitted the window is resolved from
  /// prefs (bedtime / pinned window keys).
  Future<int> getTotalSleepMinutes({
    DateTime? windowStart,
    DateTime? windowEnd,
    String? windowDateKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    _SleepWindow? resolvedWindow;

    if (windowStart != null && windowEnd != null && windowDateKey != null) {
      resolvedWindow = _SleepWindow(
        start: windowStart,
        end: windowEnd,
        dateKey: windowDateKey,
      );
    } else {
      resolvedWindow = _computeActiveSleepWindowFromPrefs(prefs);
    }

    if (resolvedWindow == null) return 0;
    return _calculateSleepMinutesForWindow(prefs, resolvedWindow);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // clearSleepData
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> clearSleepData(String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('raw_intervals_$dateKey');
    await prefs.remove('rolling_screen_off_$dateKey');

    // Legacy keys — remove so old data doesn't pollute fresh runs.
    await prefs.remove('sleep_intervals_$dateKey');
    await prefs.remove('last_screen_off_$dateKey');

    debugPrint('🗑️ Cleared sleep data for $dateKey');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SCREEN OFF — always record, no is_sleeping check
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _onScreenTurnedOff() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayKey = _dateKey(now);
    final rollingOffKey = 'rolling_screen_off_$todayKey';

    // Always write the screen-off timestamp. If there is already an open
    // interval from a previous SCREEN_OFF that was never closed (e.g. service
    // restarted while screen was off), we keep the earlier timestamp so we
    // don't lose that sleep time.
    final existing = prefs.getString(rollingOffKey);
    if (existing == null) {
      await prefs.setString(rollingOffKey, now.toIso8601String());
      debugPrint('🔒 SCREEN_OFF → rolling anchor set at $now ($todayKey)');
    } else {
      debugPrint(
        '🔒 SCREEN_OFF → anchor already open ($existing), keeping earlier',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SCREEN ON — close open interval, record to raw buffer, no is_sleeping check
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _onScreenTurnedOn() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    // The screen-off could have started on the previous calendar day
    // (e.g. went to sleep at 23:00, woke at 07:00 — SCREEN_OFF was on day-1).
    // We handle this by checking today's key first, then yesterday's.
    final todayKey = _dateKey(now);
    final yesterdayKey = _dateKey(now.subtract(const Duration(days: 1)));

    String? offKey;
    String? lastOffIso;

    for (final dayKey in [todayKey, yesterdayKey]) {
      final candidate = prefs.getString('rolling_screen_off_$dayKey');
      if (candidate != null) {
        offKey = dayKey;
        lastOffIso = candidate;
        break;
      }
    }

    if (offKey == null || lastOffIso == null) {
      debugPrint('ℹ️ SCREEN_ON → no open screen-off anchor found, ignoring');
      return;
    }

    DateTime lastOff;
    try {
      lastOff = DateTime.parse(lastOffIso);
    } catch (e) {
      debugPrint('❌ Failed to parse rolling screen-off anchor: $e');
      await prefs.remove('rolling_screen_off_$offKey');
      return;
    }

    debugPrint('🌞 SCREEN_ON → closing interval $lastOff → $now');

    // Store the raw (unclipped) interval under the day the SCREEN_OFF started.
    // Clipping to the sleep window happens in getTotalSleepMinutes.
    final rawKey = 'raw_intervals_$offKey';
    final existing = prefs.getString(rawKey);
    final intervals = _parseIntervals(existing);

    final duration = now.difference(lastOff);
    if (duration >= minSleepGap) {
      intervals.add(_TimeInterval(start: lastOff, end: now));
      final merged = _mergeIntervals(intervals);
      await prefs.setString(rawKey, _serializeIntervals(merged));
      debugPrint(
        '💾 Raw interval saved → $rawKey  (${duration.inMinutes} min)',
      );
    } else {
      debugPrint(
        '⛔ Interval too short (${duration.inMinutes} min < ${minSleepGap.inMinutes} min), discarded',
      );
    }

    // Clear the open anchor — interval is now closed.
    await prefs.remove('rolling_screen_off_$offKey');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CALCULATION — clip raw intervals to sleep window, sum minutes
  // ─────────────────────────────────────────────────────────────────────────

  int _calculateSleepMinutesForWindow(
    SharedPreferences prefs,
    _SleepWindow window,
  ) {
    final allIntervals = <_TimeInterval>[];

    // Collect raw intervals for the window's day AND the previous day
    // (handles cross-midnight windows like 23:00 → 07:00).
    for (final rawKey in [
      'raw_intervals_${window.dateKey}',
      'raw_intervals_${_dateKey(window.start.subtract(const Duration(days: 1)))}',
      // Also check legacy keys written by the old architecture.
      'sleep_intervals_${window.dateKey}',
    ]) {
      final str = prefs.getString(rawKey);
      if (str != null && str.isNotEmpty) {
        allIntervals.addAll(_parseIntervals(str));
      }
    }

    // Add open interval if screen is currently off (rolling anchor still set).
    for (final dayKey in [
      window.dateKey,
      _dateKey(window.start.subtract(const Duration(days: 1))),
    ]) {
      final offStr = prefs.getString('rolling_screen_off_$dayKey');
      // Also check legacy key name used by old implementation.
      final legacyOffStr = prefs.getString('last_screen_off_${window.dateKey}');

      final anchorStr = offStr ?? legacyOffStr;
      if (anchorStr != null) {
        try {
          final lastOff = DateTime.parse(anchorStr);
          final now = DateTime.now();
          final end = now.isAfter(window.end) ? window.end : now;
          if (end.difference(lastOff) >= minSleepGap) {
            allIntervals.add(_TimeInterval(start: lastOff, end: end));
            debugPrint(
              '📱 Open interval included (screen still off): ${end.difference(lastOff).inMinutes} min',
            );
          }
        } catch (_) {}
        break; // Only add the open anchor once.
      }
    }

    if (allIntervals.isEmpty) return 0;

    // Clip every interval to [window.start, window.end].
    final clipped = <_TimeInterval>[];
    for (final iv in allIntervals) {
      final start = iv.start.isBefore(window.start) ? window.start : iv.start;
      final end = iv.end.isAfter(window.end) ? window.end : iv.end;
      if (end.isAfter(start) &&
          end.difference(start) >= minSleepGap) {
        clipped.add(_TimeInterval(start: start, end: end));
      }
    }

    final merged = _mergeIntervals(clipped);
    final totalMinutes = merged.fold<int>(
      0,
      (sum, iv) => sum + iv.end.difference(iv.start).inMinutes,
    );

    debugPrint(
      '📊 Sleep minutes for window ${window.dateKey}: $totalMinutes min '
      '(${merged.length} clipped intervals)',
    );
    return totalMinutes;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SLEEP WINDOW HELPERS  (kept self-contained — no dependency on UBS)
  // ─────────────────────────────────────────────────────────────────────────

  /// Build the active sleep window purely from SharedPrefs.
  /// Priority: current_sleep_window_* keys (set by UBS when session is live)
  ///           → fall back to computing from bedtime/waketime prefs.
  _SleepWindow? _computeActiveSleepWindowFromPrefs(SharedPreferences prefs) {
    // 1. Use the pinned window keys if available (session already started).
    final startStr = prefs.getString('current_sleep_window_start');
    final endStr = prefs.getString('current_sleep_window_end');
    final keyStr = prefs.getString('current_sleep_window_key');

    if (startStr != null && endStr != null && keyStr != null) {
      try {
        return _SleepWindow(
          start: DateTime.parse(startStr),
          end: DateTime.parse(endStr),
          dateKey: keyStr,
        );
      } catch (_) {}
    }

    // 2. Compute from user's bedtime/waketime preferences.
    final bedMin = prefs.getInt(_bedtimeKey);
    final wakeMin = prefs.getInt(_waketimeKey);

    if (bedMin == null || wakeMin == null) return null;
    if (!_isValidMinutesOfDay(bedMin) || !_isValidMinutesOfDay(wakeMin)) {
      return null;
    }

    return _buildWindowFromMinutes(bedMin, wakeMin, DateTime.now());
  }

  _SleepWindow _buildWindowFromMinutes(
    int bedMin,
    int wakeMin,
    DateTime now,
  ) {
    final bedHour = bedMin ~/ 60;
    final bedMinute = bedMin % 60;
    final wakeHour = wakeMin ~/ 60;
    final wakeMinute = wakeMin % 60;

    DateTime start = DateTime(now.year, now.month, now.day, bedHour, bedMinute);

    // If bedtime is more than 5 min in the future, this is yesterday's bedtime.
    if (start.isAfter(now.add(const Duration(minutes: 5)))) {
      start = start.subtract(const Duration(days: 1));
    }

    DateTime end = DateTime(
      start.year,
      start.month,
      start.day,
      wakeHour,
      wakeMinute,
    );

    if (!end.isAfter(start)) {
      end = end.add(const Duration(days: 1));
    }

    final key =
        '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';

    return _SleepWindow(start: start, end: end, dateKey: key);
  }

  bool _isWithinWindow(DateTime t, DateTime start, DateTime end) {
    return !t.isBefore(start) && (t.isBefore(end) || t.isAtSameMomentAs(end));
  }

  bool _isValidMinutesOfDay(int? v) => v != null && v >= 0 && v < 24 * 60;

  // ─────────────────────────────────────────────────────────────────────────
  // DATE KEY HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  String _todayDateKey() => _dateKey(DateTime.now());

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ─────────────────────────────────────────────────────────────────────────
  // INTERVAL SERIALISATION
  // ─────────────────────────────────────────────────────────────────────────

  List<_TimeInterval> _parseIntervals(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    final result = <_TimeInterval>[];
    for (final entry in raw.split(',')) {
      final parts = entry.split('|');
      if (parts.length != 2) continue;
      try {
        final start = DateTime.parse(parts[0]);
        final end = DateTime.parse(parts[1]);
        if (end.isAfter(start)) result.add(_TimeInterval(start: start, end: end));
      } catch (_) {}
    }
    return result;
  }

  List<_TimeInterval> _mergeIntervals(List<_TimeInterval> intervals) {
    if (intervals.isEmpty) return [];
    final sorted = [...intervals]..sort((a, b) => a.start.compareTo(b.start));
    final merged = <_TimeInterval>[sorted.first];
    for (var i = 1; i < sorted.length; i++) {
      final cur = sorted[i];
      final last = merged.last;
      if (!cur.start.isAfter(last.end)) {
        final end = cur.end.isAfter(last.end) ? cur.end : last.end;
        merged[merged.length - 1] = _TimeInterval(start: last.start, end: end);
      } else {
        merged.add(cur);
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

// ─────────────────────────────────────────────────────────────────────────────
// Data classes
// ─────────────────────────────────────────────────────────────────────────────

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
