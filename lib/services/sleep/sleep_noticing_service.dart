import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:screen_state/screen_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/Controllers/SleepScreen/sleep_controller.dart';
import 'package:snevva/services/file_storage_service.dart';

/// SleepNoticingService
///
/// Tracks screen off/on events within the user's sleep window and aggregates
/// sleep intervals. Intervals are written to FileStorageService (append-only
/// sleep buffer) instead of SharedPreferences, eliminating unbounded XML growth.
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

  /// Seeds the open-interval anchor so we never lose sleep time after a
  /// service restart. Uses SharedPrefs only for the transient "screen is off
  /// since X" anchor key — this is a single small write, not a growing list.
  Future<void> initializeForSleepWindow() async {
    final prefs = await SharedPreferences.getInstance();
    final window = await _computeActiveSleepWindow(prefs);
    if (window == null) return;

    final now = DateTime.now();
    if (!_isWithinWindow(now, window.start, window.end)) return;

    final lastOffKey = 'last_screen_off_${window.dateKey}';

    final existing = prefs.getString(lastOffKey);
    if (existing == null) {
      // Assume screen is off (conservative). If it's actually on, the next
      // SCREEN_ON event will close the interval correctly.
      await prefs.setString(lastOffKey, window.start.toIso8601String());
      debugPrint(
        '🔒 initializeForSleepWindow: seeded open interval from window.start (${window.start})',
      );
    } else {
      debugPrint(
        'ℹ️ initializeForSleepWindow: existing open interval found ($existing), keeping it.',
      );
    }
  }

  // ─────────────────────────────────────────────
  // SCREEN OFF → POSSIBLE SLEEP START
  // ─────────────────────────────────────────────

  Future<void> _onScreenTurnedOff() async {
    debugPrint('🌙 SCREEN_OFF detected');

    final prefs = await SharedPreferences.getInstance();

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

    // Record the screen-off anchor in SharedPrefs (tiny, single write).
    final lastOffKey = 'last_screen_off_${window.dateKey}';
    await prefs.setString(lastOffKey, now.toIso8601String());

    debugPrint('🔒 SCREEN_OFF saved → $lastOffKey = $now');
  }

  // ─────────────────────────────────────────────
  // SCREEN ON → CLOSE INTERVAL, APPEND TO FILE BUFFER
  // ─────────────────────────────────────────────

  Future<void> _onScreenTurnedOn() async {
    debugPrint('🌞 SCREEN_ON detected');

    final prefs = await SharedPreferences.getInstance();

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
    if (!now.isBefore(window.end) &&
        Get.context != null &&
        Get.isRegistered<SleepController>()) {
      final bedMin = prefs.getInt(_bedtimeKey);
      final wakeMin = prefs.getInt(_waketimeKey);

      if (bedMin != null && wakeMin != null) {
        final bedTime = TimeOfDay(hour: bedMin ~/ 60, minute: bedMin % 60);
        final wakeTime = TimeOfDay(hour: wakeMin ~/ 60, minute: wakeMin % 60);

        await Get.find<SleepController>().updateSleepTimestoServer(
          bedTime,
          wakeTime,
        );
      }
    }

    final lastOffKey = 'last_screen_off_${window.dateKey}';

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

    // ── Write to file buffer instead of SharedPreferences ──────────
    await FileStorageService().appendSleepInterval(window.dateKey, start, end);

    // Clear the open-interval anchor
    await prefs.remove(lastOffKey);

    debugPrint('💾 Sleep interval appended to file buffer: ${window.dateKey}');
  }

  // ─────────────────────────────────────────────
  // PUBLIC UTILITY: Get total sleep time
  // ─────────────────────────────────────────────

  Future<int> getTotalSleepMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    final window = await _computeActiveSleepWindow(prefs);

    if (window == null) return 0;

    // Read total from daily file (already accumulated from previous intervals).
    final fromFile = await FileStorageService().readDailySleepMinutes(window.dateKey);

    // Also account for any open interval (screen currently off) that hasn't
    // been flushed yet.
    int openIntervalMinutes = 0;
    final lastOffKey = 'last_screen_off_${window.dateKey}';
    final lastOffStr = prefs.getString(lastOffKey);
    if (lastOffStr != null) {
      try {
        final lastOff = DateTime.parse(lastOffStr);
        final now = DateTime.now();
        DateTime start =
            lastOff.isBefore(window.start) ? window.start : lastOff;
        DateTime end = now.isAfter(window.end) ? window.end : now;

        if (end.isAfter(start)) {
          final mins = end.difference(start).inMinutes;
          if (mins >= minSleepGap.inMinutes) {
            openIntervalMinutes = mins;
            debugPrint('📱 Open interval (screen still off): ${mins} mins');
          }
        }
      } catch (e) {
        debugPrint('⚠️ Failed to parse open interval: $e');
      }
    }

    final total = fromFile + openIntervalMinutes;
    debugPrint('📊 Total sleep: $total mins (file=$fromFile, open=$openIntervalMinutes)');
    return total;
  }

  // ─────────────────────────────────────────────
  // PUBLIC UTILITY: Clear sleep data
  // ─────────────────────────────────────────────

  Future<void> clearSleepData(String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_screen_off_$dateKey');
    debugPrint('🗑️ Cleared sleep anchor for $dateKey');
  }

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────

  bool _isWithinWindow(DateTime t, DateTime start, DateTime end) {
    return (!t.isBefore(start)) && (t.isBefore(end) || t.isAtSameMomentAs(end));
  }

  Future<_SleepWindow?> _computeActiveSleepWindow(
    SharedPreferences prefs,
  ) async {
    debugPrint('🧠 Computing active sleep window');

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
      if (now.isBefore(_buildDateTime(now, wakeTod))) {
        sleepStart = sleepStartToday.subtract(const Duration(days: 1));
      } else if (now.isBefore(sleepStartToday)) {
        sleepStart = sleepStartToday.subtract(const Duration(days: 1));
      } else {
        sleepStart = sleepStartToday;
      }
    } else {
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

// ─────────────────────────────────────────────

class _SleepWindow {
  final DateTime start;
  final DateTime end;
  final String dateKey;

  _SleepWindow({required this.start, required this.end, required this.dateKey});
}
