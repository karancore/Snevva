import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FileStorageService
//
// Architecture (both Dart and Kotlin use the SAME base directory):
//   Base: context.filesDir  (= getApplicationSupportDirectory() in Flutter)
//   ├── fs/<uid>/buffer/steps_buf.tmp   ← append-only step events ("$ts,$steps\n")
//   ├── fs/<uid>/buffer/sleep_buf.tmp   ← append-only sleep intervals ("$dateKey|$start|$end\n")
//   ├── fs/<uid>/daily/YYYY-MM-DD.json  ← aggregated daily record (steps + sleep)
//   └── fs/<uid>/sync_queue.json        ← [{"date":"2026-04-05","type":"both"}]
//
// <uid>  = PatientCode from SharedPreferences (falls back to "anonymous").
// _filesDir is cached per-login session. Call reset() on logout/login so the
// next caller picks up the new user's directory.
//
// Key invariants:
//   • Never read during normal append operation
//   • Flush reads buffer ONCE, writes daily JSON, deletes buffer → RAM freed
//   • Daily file deleted only AFTER confirmed HTTP 200
//   • getApplicationSupportDirectory() on Android == context.filesDir — same
//     path used by Kotlin's BufferManager.kt so both sides share one store.
// ─────────────────────────────────────────────────────────────────────────────

class FileStorageService {
  FileStorageService._internal();
  static final FileStorageService _instance = FileStorageService._internal();
  factory FileStorageService() => _instance;

  Directory? _filesDir;

  // ───────────────────────────────────────────────
  // INIT
  // ───────────────────────────────────────────────

  /// Invalidate the cached directory so the next access re-reads the current
  /// user's PatientCode. Call this on logout (before prefs.clear()) AND on
  /// successful login so a hot-session-swap always gets the right directory.
  void reset() {
    _filesDir = null;
  }

  Future<Directory> get _files async {
    if (_filesDir != null) return _filesDir!;
    final appDir = await getApplicationSupportDirectory();
    // Scope to the logged-in user so User A's files are never visible to User B.
    // Mirrors Kotlin's fsDir() in BufferManager / ApiSyncWorker / SleepCalcWorker.
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('PatientCode') ?? 'anonymous';
    _filesDir = Directory('${appDir.path}/fs/$uid');
    return _filesDir!;
  }

  // ───────────────────────────────────────────────
  // ONE-TIME MIGRATION
  // ───────────────────────────────────────────────

  /// Copies daily JSON files that were written to the old app_flutter/fs/daily/
  /// path (using getApplicationDocumentsDirectory) into the new files/fs/daily/
  /// path so existing data is not lost after the path change.
  ///
  /// Safe to call on every cold start — skips if migration flag is already set.
  Future<void> migrateOldFilesIfNeeded() async {
    const v1Key = 'fs_path_migration_done_v1';
    const v2Key = 'fs_uid_migration_done_v2';
    try {
      final prefs = await SharedPreferences.getInstance();
      final appDir = await getApplicationSupportDirectory();

      // ── v1: app_flutter/fs/daily → files/fs/daily ──────────────────────────
      if (prefs.getBool(v1Key) != true) {
        final oldBase = await getApplicationDocumentsDirectory();
        final oldDaily = Directory('${oldBase.path}/fs/daily');
        if (oldDaily.existsSync()) {
          final newDailyDir = await _ensureDir('daily');
          int copied = 0;

          for (final entity in oldDaily.listSync()) {
            if (entity is! File) continue;
            final name = entity.uri.pathSegments.last;
            if (!name.endsWith('.json')) continue;

            final dest = File('${newDailyDir.path}/$name');
            if (dest.existsSync()) {
              try {
                final oldJson = jsonDecode(entity.readAsStringSync()) as Map<String, dynamic>;
                final newJson = jsonDecode(dest.readAsStringSync()) as Map<String, dynamic>;
                final oldMins = (oldJson['sleep']?['total_sleep_minutes'] as int?) ?? 0;
                final newMins = (newJson['sleep']?['total_sleep_minutes'] as int?) ?? 0;
                if (oldMins <= newMins) continue;
              } catch (_) {}
            }

            await entity.copy(dest.path);
            copied++;
          }
          debugPrint('✅ fs v1 migration: copied $copied daily file(s) from app_flutter → files');
        }
        await prefs.setBool(v1Key, true);
      }

      // ── v2: files/fs/{buffer,daily,sync_queue} → files/fs/<uid>/ ───────────
      // Runs once per user after the multi-user update is installed.
      if (prefs.getBool(v2Key) != true) {
        final uid = prefs.getString('PatientCode');
        if (uid == null || uid.isEmpty) {
          // Not logged in — nothing to migrate yet; mark done so we don't loop.
          await prefs.setBool(v2Key, true);
        } else {
          final oldFs = Directory('${appDir.path}/fs');
          final newFs = Directory('${appDir.path}/fs/$uid');

          if (oldFs.existsSync()) {
            int moved = 0;
            for (final entity in oldFs.listSync()) {
              // Skip sub-directories that look like uid directories (already migrated)
              // A uid-style name contains alphanumeric chars; skip directories entirely —
              // we handle buffer/ and daily/ recursively below.
              if (entity is Directory) {
                final dirName = entity.uri.pathSegments
                    .where((s) => s.isNotEmpty)
                    .last;
                // Migrate known flat sub-dirs
                if (dirName == 'buffer' || dirName == 'daily') {
                  final destDir = Directory('${newFs.path}/$dirName');
                  if (!destDir.existsSync()) await destDir.create(recursive: true);
                  for (final sub in entity.listSync()) {
                    if (sub is! File) continue;
                    final fname = sub.uri.pathSegments.last;
                    final dest = File('${destDir.path}/$fname');
                    if (!dest.existsSync()) {
                      await sub.copy(dest.path);
                      moved++;
                    }
                  }
                }
                // Skip any other directory (could be another uid or anonymous)
                continue;
              }
              // Top-level files (e.g. sync_queue.json, api_sync_logs.json)
              if (entity is File) {
                final fname = entity.uri.pathSegments.last;
                if (!newFs.existsSync()) await newFs.create(recursive: true);
                final dest = File('${newFs.path}/$fname');
                if (!dest.existsSync()) {
                  await entity.copy(dest.path);
                  moved++;
                }
              }
            }
            debugPrint('✅ fs v2 migration: moved $moved item(s) into fs/$uid/');
          }
          await prefs.setBool(v2Key, true);
        }
      }
    } catch (e) {
      debugPrint('⚠️ fs migration error (non-fatal): $e');
    }
  }

  Future<Directory> _ensureDir(String sub) async {
    final base = await _files;
    final dir = Directory('${base.path}/$sub');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _bufferFile(String name) async {
    final dir = await _ensureDir('buffer');
    return File('${dir.path}/$name');
  }

  Future<File> _dailyFile(String dateKey) async {
    final dir = await _ensureDir('daily');
    return File('${dir.path}/$dateKey.json');
  }

  Future<File> get _syncQueueFile async {
    final base = await _files;
    if (!base.existsSync()) await base.create(recursive: true);
    return File('${base.path}/sync_queue.json');
  }

  // ───────────────────────────────────────────────
  // STEP BUFFER — append only, zero reads
  // ───────────────────────────────────────────────

  /// Appends a single step event to the buffer. O(1), no RAM mirror.
  /// Kotlin's BufferManager.kt is the primary writer; this Dart method is used
  /// for the Flutter-background-service isolate path.
  Future<void> appendStepEvent(int steps) async {
    try {
      final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final file = await _bufferFile('steps_buf.tmp');
      await file.writeAsString('$ts,$steps\n', mode: FileMode.append, flush: true);
    } catch (e) {
      debugPrint('❌ FileStorageService.appendStepEvent error: $e');
    }
  }

  /// Reads the step buffer exactly once, aggregates totals per day, merges into
  /// daily JSON files, then deletes the buffer. Call this on day change or flush.
  Future<void> flushStepsToDaily() async {
    try {
      final file = await _bufferFile('steps_buf.tmp');
      if (!file.existsSync() || file.lengthSync() == 0) return;

      final lines = await file.readAsLines();
      final Map<String, int> maxPerDay = {};

      for (final line in lines) {
        final parsed = _parseStepLine(line);
        if (parsed == null) continue;
        final ts = parsed.$1;
        final steps = parsed.$2;
        final key = _dateKeyFromEpoch(ts);
        // We store the maximum (latest) step count per day since the sensor
        // delivers cumulative counts within a day.
        if (steps > (maxPerDay[key] ?? 0)) {
          maxPerDay[key] = steps;
        }
      }

      for (final entry in maxPerDay.entries) {
        await _mergeStepsIntoDailyFile(entry.key, entry.value);
      }

      await file.delete();
      debugPrint('✅ Steps buffer flushed (${maxPerDay.length} day(s))');
    } catch (e) {
      debugPrint('❌ FileStorageService.flushStepsToDaily error: $e');
    }
  }

  // ───────────────────────────────────────────────
  // SLEEP BUFFER — append only
  // ───────────────────────────────────────────────

  /// Appends a completed sleep interval to the sleep buffer.
  /// Format: "$dateKey|$startIso|$endIso\n"
  Future<void> appendSleepInterval(
    String dateKey,
    DateTime start,
    DateTime end,
  ) async {
    try {
      if (!end.isAfter(start)) return;
      final line = '$dateKey|${start.toIso8601String()}|${end.toIso8601String()}\n';
      final file = await _bufferFile('sleep_buf.tmp');
      await file.writeAsString(line, mode: FileMode.append, flush: true);
      debugPrint('📝 Sleep interval buffered: $dateKey (${end.difference(start).inMinutes}m)');
    } catch (e) {
      debugPrint('❌ FileStorageService.appendSleepInterval error: $e');
    }
  }

  /// Reads the sleep buffer exactly once, aggregates intervals per day, merges
  /// into daily JSON files, then deletes the buffer.
  Future<void> flushSleepToDaily() async {
    try {
      final file = await _bufferFile('sleep_buf.tmp');
      if (!file.existsSync() || file.lengthSync() == 0) return;

      final lines = await file.readAsLines();
      // Group intervals by dateKey
      final Map<String, List<_SleepSegment>> byDay = {};

      for (final line in lines) {
        final seg = _parseSleepLine(line);
        if (seg == null) continue;
        byDay.putIfAbsent(seg.dateKey, () => []).add(seg);
      }

      for (final entry in byDay.entries) {
        final merged = _mergeSegments(entry.value);
        final totalMinutes = merged.fold<int>(
          0,
          (sum, s) => sum + s.end.difference(s.start).inMinutes,
        );
        await _mergeSleepIntoDailyFile(entry.key, totalMinutes, merged);
      }

      await file.delete();
      debugPrint('✅ Sleep buffer flushed');
    } catch (e) {
      debugPrint('❌ FileStorageService.flushSleepToDaily error: $e');
    }
  }

  // ───────────────────────────────────────────────
  // DAILY JSON READ HELPERS
  // ───────────────────────────────────────────────

  /// Returns the total step count for a given date key (e.g. "2026-04-07").
  Future<int> readDailySteps(String dateKey) async {
    try {
      final file = await _dailyFile(dateKey);
      if (!file.existsSync()) return 0;
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return (json['steps']?['total'] as int?) ?? 0;
    } catch (e) {
      debugPrint('❌ readDailySteps($dateKey) error: $e');
      return 0;
    }
  }

  /// Returns the total sleep duration in minutes for a given date key.
  Future<int> readDailySleepMinutes(String dateKey) async {
    try {
      final file = await _dailyFile(dateKey);
      if (!file.existsSync()) return 0;
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return (json['sleep']?['total_sleep_minutes'] as int?) ?? 0;
    } catch (e) {
      debugPrint('❌ readDailySleepMinutes($dateKey) error: $e');
      return 0;
    }
  }

  /// Returns a map of dateKey → steps for the last [days] days.
  Future<Map<String, int>> readRecentStepsMap({int days = 7}) async {
    final result = <String, int>{};
    final now = DateTime.now();
    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      final key = _dateKeyFromDateTime(date);
      result[key] = await readDailySteps(key);
    }
    return result;
  }

  /// Returns a map of dateKey → sleep minutes for the last [days] days.
  Future<Map<String, int>> readRecentSleepMap({int days = 7}) async {
    final result = <String, int>{};
    final now = DateTime.now();
    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      final key = _dateKeyFromDateTime(date);
      result[key] = await readDailySleepMinutes(key);
    }
    return result;
  }

  Future<void> pruneSleepDataBeforeCurrentWeek() async {
    try {
      final dir = await _ensureDir('daily');
      final queuedKeys = (await readSyncQueue()).toSet();
      final now = DateTime.now();
      final weekStart = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1));

      final dateKeyPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

      for (final entity in dir.listSync()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.isEmpty
            ? ''
            : entity.uri.pathSegments.last;
        if (!name.endsWith('.json')) continue;

        final dateKey = name.substring(0, name.length - 5);
        if (!dateKeyPattern.hasMatch(dateKey)) continue;
        if (queuedKeys.contains(dateKey)) continue;

        final date = DateTime.tryParse(dateKey);
        if (date == null) continue;
        if (!date.isBefore(weekStart)) continue;

        await _mergeDailyJson(dateKey, (json) {
          json['sleep'] = {'total_sleep_minutes': 0, 'segments': []};
        });
      }
    } catch (e) {
      debugPrint('❌ pruneSleepDataBeforeCurrentWeek error: $e');
    }
  }

  // ───────────────────────────────────────────────
  // SYNC QUEUE
  // ───────────────────────────────────────────────

  Future<List<String>> readSyncQueue() async {
    try {
      final file = await _syncQueueFile;
      if (!file.existsSync()) return [];
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
      final list = jsonDecode(content) as List<dynamic>;
      return list.cast<String>();
    } catch (e) {
      debugPrint('❌ readSyncQueue error: $e');
      return [];
    }
  }

  Future<void> addToSyncQueue(String dateKey) async {
    try {
      final queue = await readSyncQueue();
      if (!queue.contains(dateKey)) {
        queue.add(dateKey);
        final file = await _syncQueueFile;
        await file.writeAsString(jsonEncode(queue));
        debugPrint('📋 Added $dateKey to sync queue');
      }
    } catch (e) {
      debugPrint('❌ addToSyncQueue error: $e');
    }
  }

  Future<void> removeFromSyncQueue(String dateKey) async {
    try {
      final queue = await readSyncQueue();
      queue.remove(dateKey);
      final file = await _syncQueueFile;
      await file.writeAsString(jsonEncode(queue));
    } catch (e) {
      debugPrint('❌ removeFromSyncQueue error: $e');
    }
  }

  /// Marks a daily file as sent=true (called before deletion on HTTP 200).
  Future<void> markDailyAsSent(String dateKey) async {
    try {
      await _mergeDailyJson(dateKey, (json) {
        json['sent'] = true;
      });
    } catch (e) {
      debugPrint('❌ markDailyAsSent error: $e');
    }
  }

  /// Directly writes (or merges) a known sleep duration into the daily JSON.
  /// Use this for on-demand saves (e.g., when the sleep controller finalises a
  /// session retroactively). Does NOT go through the buffer.
  Future<void> writeSleepMinutes(String dateKey, int minutes) async {
    if (minutes <= 0) return;
    await _mergeDailyJson(dateKey, (json) {
      final existing = (json['sleep']?['total_sleep_minutes'] as int?) ?? 0;
      if (minutes >= existing) {
        // Preserve existing segments if any; just update the total
        final existingSegs = json['sleep']?['segments'] ?? [];
        json['sleep'] = {
          'total_sleep_minutes': minutes,
          'segments': existingSegs,
        };
      }
    });
    debugPrint('✅ writeSleepMinutes: $dateKey → ${minutes}m');
  }

   /// Directly writes (or merges) a known step total into the daily JSON.
  Future<void> writeStepTotal(String dateKey, int steps) async {
    if (steps <= 0) return;
    await _mergeDailyJson(dateKey, (json) {
      final existing = (json['steps']?['total'] as int?) ?? 0;
      if (steps >= existing) {
        json['steps'] = {'total': steps};
      }
    });
    debugPrint('✅ writeStepTotal: $dateKey → $steps');
  }

  /// Deletes a daily file. Only call this AFTER confirmed HTTP 200.
  Future<void> deleteDailyFile(String dateKey) async {
    try {
      final file = await _dailyFile(dateKey);
      if (file.existsSync()) {
        await file.delete();
        debugPrint('🗑️ Deleted daily file: $dateKey');
      }
    } catch (e) {
      debugPrint('❌ deleteDailyFile error: $e');
    }
  }

  // ───────────────────────────────────────────────
  // INTERNAL — daily JSON merge helpers
  // ───────────────────────────────────────────────

  Future<void> _mergeStepsIntoDailyFile(String dateKey, int steps) async {
    await _mergeDailyJson(dateKey, (json) {
      final current = (json['steps']?['total'] as int?) ?? 0;
      if (steps > current) {
        json['steps'] = {'total': steps};
      }
    });
  }

  Future<void> _mergeSleepIntoDailyFile(
    String dateKey,
    int totalMinutes,
    List<_SleepSegment> segments,
  ) async {
    await _mergeDailyJson(dateKey, (json) {
      final existing = (json['sleep']?['total_sleep_minutes'] as int?) ?? 0;
      // Always write the freshest value (or merge if larger)
      if (totalMinutes >= existing) {
        json['sleep'] = {
          'total_sleep_minutes': totalMinutes,
          'segments': segments
              .map((s) => {
                    'start': s.start.toIso8601String(),
                    'end': s.end.toIso8601String(),
                  })
              .toList(),
        };
      }
    });
  }

  Future<void> _mergeDailyJson(
    String dateKey,
    void Function(Map<String, dynamic> json) mutate,
  ) async {
    final file = await _dailyFile(dateKey);
    Map<String, dynamic> json;
    if (file.existsSync()) {
      try {
        json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      } catch (_) {
        json = _emptyDailyJson(dateKey);
      }
    } else {
      json = _emptyDailyJson(dateKey);
    }

    mutate(json);

    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(json),
    );
  }

  Map<String, dynamic> _emptyDailyJson(String dateKey) => {
        'date': dateKey,
        'steps': {'total': 0},
        'sleep': {'total_sleep_minutes': 0, 'segments': []},
        'sent': false,
        'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      };

  // ───────────────────────────────────────────────
  // INTERNAL — parsers and date helpers
  // ───────────────────────────────────────────────

  (int, int)? _parseStepLine(String line) {
    try {
      final parts = line.trim().split(',');
      if (parts.length < 2) return null;
      return (int.parse(parts[0]), int.parse(parts[1]));
    } catch (_) {
      return null;
    }
  }

  _SleepSegment? _parseSleepLine(String line) {
    try {
      final parts = line.trim().split('|');
      if (parts.length < 3) return null;
      return _SleepSegment(
        dateKey: parts[0],
        start: DateTime.parse(parts[1]),
        end: DateTime.parse(parts[2]),
      );
    } catch (_) {
      return null;
    }
  }

  List<_SleepSegment> _mergeSegments(List<_SleepSegment> segs) {
    if (segs.isEmpty) return [];
    final sorted = [...segs]..sort((a, b) => a.start.compareTo(b.start));
    final merged = <_SleepSegment>[sorted.first];
    for (int i = 1; i < sorted.length; i++) {
      final cur = sorted[i];
      final last = merged.last;
      if (!cur.start.isAfter(last.end)) {
        // Overlapping — extend
        merged[merged.length - 1] = _SleepSegment(
          dateKey: last.dateKey,
          start: last.start,
          end: cur.end.isAfter(last.end) ? cur.end : last.end,
        );
      } else {
        merged.add(cur);
      }
    }
    return merged;
  }

  String _dateKeyFromEpoch(int epochSecs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(epochSecs * 1000);
    return _dateKeyFromDateTime(dt);
  }

  String _dateKeyFromDateTime(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Private data classes
// ─────────────────────────────────────────────────────────────────────────────

class _SleepSegment {
  final String dateKey;
  final DateTime start;
  final DateTime end;
  const _SleepSegment({
    required this.dateKey,
    required this.start,
    required this.end,
  });
}
