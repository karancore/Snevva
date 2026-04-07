import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screen_state/screen_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SleepNoticingService
//
// Architecture: ALWAYS-ON screen monitoring, window-clipped calculation.
//
// The service runs 24/7. Screen-off/on events are written to append-only
// JSONL files keyed by calendar date, WITHOUT any is_sleeping check.
// Sleep duration is calculated from those raw intervals by clipping them
// to the user's sleep window at save-time (inside _stopSleepAndSave).
//
// This guarantees that no sleep data is lost even if the bedtime heartbeat
// fires late, the app is never opened, or the service restarts mid-night.
// ─────────────────────────────────────────────────────────────────────────────

class SleepNoticingService {
  static Duration minSleepGap = Duration(minutes: 3);
  static Duration sleepWindowSeedLeadTime = Duration(minutes: 5);

  static final Duration _previousDayOffset = Duration(days: 1);
  static final Duration _flushDelay = Duration(milliseconds: 750);
  static final Duration _screenStateRestoreRange = Duration(days: 1);
  static const int _flushThresholdBytes = 4096;
  static const String _storageDirectoryName = 'sleep_screen_events';
  static const String _screenOffEventType = 'SCREEN_OFF';
  static const String _screenOnEventType = 'SCREEN_ON';

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
  final Map<String, StringBuffer> _pendingWriteBuffers =
  <String, StringBuffer>{};
  final Map<String, int> _pendingWriteSizes = <String, int>{};
  Timer? _flushTimer;
  Future<void> _pendingFlush = Future<void>.value();
  DateTime? _openScreenOffAt;
  bool _hasRestoredScreenState = false;

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
          unawaited(_onScreenTurnedOff());
        } else if (event == ScreenStateEvent.SCREEN_ON) {
          unawaited(_onScreenTurnedOn());
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
    unawaited(_flushPendingWrites());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // initializeForSleepWindow
  //
  // Seeds the open anchor from window.start when:
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
    await _restoreOpenScreenStateIfNeeded();

    final now = DateTime.now();
    if (!_isWithinWindow(now, window.start, window.end)) return;

    if (_openScreenOffAt == null) {
      _openScreenOffAt = window.start;
      await _appendEvent(
        type: _screenOffEventType,
        timestamp: window.start,
        synthetic: true,
      );
      debugPrint(
        '🔒 initializeForSleepWindow: seeded rolling anchor at ${window.start}',
      );
      return;
    }

    debugPrint(
      'ℹ️ initializeForSleepWindow: rolling anchor already exists ($_openScreenOffAt)',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // getTotalSleepMinutes
  //
  // Computes sleep minutes by:
  //   1. Reading append-only screen event JSON for the window dates
  //   2. Rebuilding closed screen-off intervals from SCREEN_OFF/SCREEN_ON pairs
  //   3. Adding the open interval if the screen is still off
  //   4. Clipping every interval to [window.start, window.end]
  //   5. Merging overlaps and summing
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
    await _restoreOpenScreenStateIfNeeded();
    return _calculateSleepMinutesForWindow(resolvedWindow);
  }

  Future<ScreenSleepSummary?> readResolvedSleepSummary({
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

    if (resolvedWindow == null) {
      return null;
    }

    await _restoreOpenScreenStateIfNeeded();
    final minutes = await _calculateSleepMinutesForWindow(resolvedWindow);
    return ScreenSleepSummary(
      dateKey: resolvedWindow.dateKey,
      start: resolvedWindow.start,
      end: resolvedWindow.end,
      duration: Duration(minutes: minutes),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // clearSleepData
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> clearSleepData(String dateKey) async {
    await _flushPendingWrites();

    try {
      final file = await _eventFileForDay(dateKey);
      if (await file.exists()) {
        await file.delete();
      }
      if (_openScreenOffAt != null && _dateKey(_openScreenOffAt!) == dateKey) {
        _openScreenOffAt = null;
      }
      debugPrint('🗑️ Cleared sleep data for $dateKey');
    } catch (e) {
      debugPrint('❌ Failed to clear sleep data for $dateKey: $e');
    }
  }

  Future<List<ScreenEventLogEntry>> readLoggedEvents({int? limit}) async {
    await _flushPendingWrites();

    try {
      final directory = await _sleepEventsDirectory();
      if (!await directory.exists()) return [];

      final files = <File>[];
      await for (final entity in directory.list()) {
        if (entity is File && entity.path.endsWith('.jsonl')) {
          files.add(entity);
        }
      }

      final records = <_ScreenEventRecord>[];
      for (final file in files) {
        final fileName = file.uri.pathSegments.isNotEmpty
            ? file.uri.pathSegments.last
            : file.path
            .split(Platform.pathSeparator)
            .last;
        final match = RegExp(r'screen_events_(\d{4}-\d{2}-\d{2})\.jsonl$')
            .firstMatch(fileName);
        if (match == null) continue;

        records.addAll(await _readEventsForDay(match.group(1)!));
      }

      records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final entries = records
          .map(
            (record) =>
            ScreenEventLogEntry(
              type: record.type,
              timestamp: record.timestamp,
              synthetic: record.synthetic,
              dateKey: _dateKey(record.timestamp),
            ),
      )
          .toList();

      if (limit != null && entries.length > limit) {
        return entries.take(limit).toList();
      }

      return entries;
    } catch (e) {
      debugPrint('❌ Failed to read logged screen events: $e');
      return [];
    }
  }

  Future<void> clearLoggedEvents() async {
    await _flushPendingWrites();

    try {
      final directory = await _sleepEventsDirectory();
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('❌ Failed to clear logged screen events: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SCREEN OFF — always record, no is_sleeping check
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _onScreenTurnedOff() async {
    await _restoreOpenScreenStateIfNeeded();
    final now = DateTime.now();
    final todayKey = _dateKey(now);

    // Always write the screen-off timestamp. If there is already an open
    // interval from a previous SCREEN_OFF that was never closed (e.g. service
    // restarted while screen was off), we keep the earlier timestamp so we
    // don't lose that sleep time.
    if (_openScreenOffAt == null) {
      _openScreenOffAt = now;
      await _appendEvent(type: _screenOffEventType, timestamp: now);
      debugPrint('🔒 SCREEN_OFF → rolling anchor set at $now ($todayKey)');
      return;
    }

    debugPrint(
      '🔒 SCREEN_OFF → anchor already open ($_openScreenOffAt), keeping earlier',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SCREEN ON — close open interval, record to raw buffer, no is_sleeping check
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _onScreenTurnedOn() async {
    await _restoreOpenScreenStateIfNeeded();
    final now = DateTime.now();
    final lastOff = _openScreenOffAt;
    if (lastOff == null) {
      debugPrint('ℹ️ SCREEN_ON → no open screen-off anchor found, ignoring');
      return;
    }

    debugPrint('🌞 SCREEN_ON → closing interval $lastOff → $now');

    final duration = now.difference(lastOff);
    if (duration >= minSleepGap) {
      await _appendEvent(type: _screenOnEventType, timestamp: now);
      debugPrint(
        '💾 Raw interval saved → ${_dateKey(lastOff)}  (${duration
            .inMinutes} min)',
      );
    } else {
      debugPrint(
        '⛔ Interval too short (${duration.inMinutes} min < ${minSleepGap.inMinutes} min), discarded',
      );
    }

    // Clear the open anchor — interval is now closed.
    _openScreenOffAt = null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CALCULATION — clip raw intervals to sleep window, sum minutes
  // ─────────────────────────────────────────────────────────────────────────

  Future<int> _calculateSleepMinutesForWindow(_SleepWindow window) async {
    await _flushPendingWrites();
    final allIntervals = <_TimeInterval>[];
    final now = DateTime.now();
    final dayKeys = <String>{
      window.dateKey,
      _dateKey(window.start.subtract(_previousDayOffset)),
    };
    final allEvents = <_ScreenEventRecord>[];

    for (final dayKey in dayKeys) {
      allEvents.addAll(await _readEventsForDay(dayKey));
    }

    allEvents.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    allIntervals.addAll(_buildIntervalsFromEvents(allEvents));

    // Add open interval if screen is currently off.
    final openAnchor = _openScreenOffAt;
    if (openAnchor != null) {
      final end = now.isAfter(window.end) ? window.end : now;
      if (end.difference(openAnchor) >= minSleepGap) {
        allIntervals.add(_TimeInterval(start: openAnchor, end: end));
        debugPrint(
          '📱 Open interval included (screen still off): ${end
              .difference(openAnchor)
              .inMinutes} min',
        );
      }
    }

    if (allIntervals.isEmpty) return 0;

    // Clip every interval to [window.start, window.end].
    final clipped = <_TimeInterval>[];
    for (final iv in allIntervals) {
      final start = iv.start.isBefore(window.start) ? window.start : iv.start;
      final end = iv.end.isAfter(window.end) ? window.end : iv.end;
      if (end.isAfter(start) && end.difference(start) >= minSleepGap) {
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
    if (start.isAfter(now.add(sleepWindowSeedLeadTime))) {
      start = start.subtract(_previousDayOffset);
    }

    DateTime end = DateTime(
      start.year,
      start.month,
      start.day,
      wakeHour,
      wakeMinute,
    );

    if (!end.isAfter(start)) {
      end = end.add(_previousDayOffset);
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
  // FILE STORAGE
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _restoreOpenScreenStateIfNeeded() async {
    if (_hasRestoredScreenState) return;
    _hasRestoredScreenState = true;
    await _flushPendingWrites();

    final now = DateTime.now();
    final dayKeys = <String>{
      _todayDateKey(),
      _dateKey(now.subtract(_screenStateRestoreRange)),
    };
    final allEvents = <_ScreenEventRecord>[];

    for (final dayKey in dayKeys) {
      allEvents.addAll(await _readEventsForDay(dayKey));
    }

    allEvents.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    DateTime? openStart;
    for (final event in allEvents) {
      if (event.type == _screenOffEventType) {
        openStart ??= event.timestamp;
        continue;
      }

      if (event.type == _screenOnEventType) {
        openStart = null;
      }
    }

    _openScreenOffAt = openStart;
    if (openStart != null) {
      debugPrint('🔄 Restored open screen-off anchor from file: $openStart');
    }
  }

  Future<void> _appendEvent({
    required String type,
    required DateTime timestamp,
    bool synthetic = false,
  }) async {
    final dayKey = _dateKey(timestamp);
    final event = _ScreenEventRecord(
      type: type,
      timestamp: timestamp,
      synthetic: synthetic,
    );

    final builder = StringBuffer();
    builder.write(jsonEncode(event.toJson()));
    builder.write('\n');
    final payload = builder.toString();

    final buffer = _pendingWriteBuffers.putIfAbsent(dayKey, StringBuffer.new);
    buffer.write(payload);
    _pendingWriteSizes[dayKey] =
        (_pendingWriteSizes[dayKey] ?? 0) + utf8
            .encode(payload)
            .length;

    if ((_pendingWriteSizes[dayKey] ?? 0) >= _flushThresholdBytes) {
      await _flushPendingWrites();
      return;
    }

    _scheduleFlush();
  }

  void _scheduleFlush() {
    _flushTimer?.cancel();
    _flushTimer = Timer(_flushDelay, () {
      unawaited(_flushPendingWrites());
    });
  }

  Future<void> _flushPendingWrites() {
    _flushTimer?.cancel();
    _flushTimer = null;

    final nextFlush = _pendingFlush.then((_) async {
      if (_pendingWriteBuffers.isEmpty) return;

      final bufferedWrites = <String, String>{};
      for (final entry in _pendingWriteBuffers.entries) {
        bufferedWrites[entry.key] = entry.value.toString();
      }
      _pendingWriteBuffers.clear();
      _pendingWriteSizes.clear();

      for (final entry in bufferedWrites.entries) {
        final dayKey = entry.key;
        final payload = entry.value;

        try {
          final file = await _eventFileForDay(dayKey);
          final sink = file.openWrite(mode: FileMode.append);
          sink.write(payload);
          await sink.flush();
          await sink.close();
        } catch (e) {
          debugPrint('❌ Failed to append sleep events for $dayKey: $e');
          final retryBuffer = _pendingWriteBuffers.putIfAbsent(
            dayKey,
            StringBuffer.new,
          );
          retryBuffer.write(payload);
          _pendingWriteSizes[dayKey] =
              (_pendingWriteSizes[dayKey] ?? 0) + utf8
                  .encode(payload)
                  .length;
          _scheduleFlush();
        }
      }
    });

    _pendingFlush = nextFlush.catchError((Object error, StackTrace stackTrace) {
      debugPrint('❌ Sleep event flush failed: $error');
    });

    return _pendingFlush;
  }

  Future<File> _eventFileForDay(String dayKey) async {
    final directory = await _sleepEventsDirectory();
    return File('${directory.path}/screen_events_$dayKey.jsonl');
  }

  Future<Directory> _sleepEventsDirectory() async {
    final baseDirectory = await getApplicationDocumentsDirectory();
    final directory = Directory(
      '${baseDirectory.path}/$_storageDirectoryName',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<List<_ScreenEventRecord>> _readEventsForDay(String dayKey) async {
    try {
      final file = await _eventFileForDay(dayKey);
      if (!await file.exists()) return [];

      final events = <_ScreenEventRecord>[];
      await for (final line in file
          .openRead()
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (line
            .trim()
            .isEmpty) continue;

        try {
          final decoded = jsonDecode(line);
          if (decoded is Map<String, dynamic>) {
            final event = _ScreenEventRecord.fromJson(decoded);
            if (event != null) {
              events.add(event);
            }
          } else if (decoded is Map) {
            final event = _ScreenEventRecord.fromJson(
              decoded.cast<String, dynamic>(),
            );
            if (event != null) {
              events.add(event);
            }
          }
        } catch (e) {
          debugPrint('⚠️ Skipping malformed sleep event line for $dayKey: $e');
        }
      }
      return events;
    } catch (e) {
      debugPrint('❌ Failed to read sleep events for $dayKey: $e');
      return [];
    }
  }

  List<_TimeInterval> _buildIntervalsFromEvents(
      List<_ScreenEventRecord> events,) {
    final intervals = <_TimeInterval>[];
    DateTime? lastOff;

    for (final event in events) {
      if (event.type == _screenOffEventType) {
        lastOff ??= event.timestamp;
        continue;
      }

      if (event.type == _screenOnEventType && lastOff != null) {
        if (event.timestamp.isAfter(lastOff)) {
          intervals.add(_TimeInterval(start: lastOff, end: event.timestamp));
        }
        lastOff = null;
      }
    }

    return intervals;
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

class ScreenEventLogEntry {
  final String type;
  final DateTime timestamp;
  final bool synthetic;
  final String dateKey;

  const ScreenEventLogEntry({
    required this.type,
    required this.timestamp,
    required this.synthetic,
    required this.dateKey,
  });
}

class ScreenSleepSummary {
  final String dateKey;
  final DateTime start;
  final DateTime end;
  final Duration duration;

  const ScreenSleepSummary({
    required this.dateKey,
    required this.start,
    required this.end,
    required this.duration,
  });
}

class _ScreenEventRecord {
  final String type;
  final DateTime timestamp;
  final bool synthetic;

  const _ScreenEventRecord({
    required this.type,
    required this.timestamp,
    required this.synthetic,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'synthetic': synthetic,
    };
  }

  static _ScreenEventRecord? fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    final timestampValue = json['timestamp'] as String?;
    final synthetic = json['synthetic'] as bool? ?? false;

    if (type == null || timestampValue == null) {
      return null;
    }

    try {
      return _ScreenEventRecord(
        type: type,
        timestamp: DateTime.parse(timestampValue),
        synthetic: synthetic,
      );
    } catch (_) {
      return null;
    }
  }
}
