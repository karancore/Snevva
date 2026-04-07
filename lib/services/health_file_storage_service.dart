import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/hive_models/sleep_log.dart';
import '../models/hive_models/steps_model.dart';
import 'hive_service.dart';

class HealthFileStorageService {
  HealthFileStorageService._();

  static final HealthFileStorageService instance = HealthFileStorageService._();

  static const String _migrationCompletedKey = 'migration_completed';

  Future<Directory> _baseDir() => getApplicationSupportDirectory();

  Future<Directory> _dailyDir() async {
    final dir = Directory('${(await _baseDir()).path}/daily');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _metaFile() async =>
      File('${(await _baseDir()).path}/meta.json');

  Future<File> _syncQueueFile() async =>
      File('${(await _baseDir()).path}/sync_queue.json');

  Future<File> _dailyFile(String dayKey) async =>
      File('${(await _dailyDir()).path}/$dayKey.json');

  Future<void> ensureInitialized() async {
    await _dailyDir();
    await _readMeta();
    await syncSleepScheduleFromPrefs();
  }

  Future<void> syncSleepScheduleFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final meta = await _readMeta();
    final bedtime = prefs.getInt('user_bedtime_ms');
    final waketime = prefs.getInt('user_waketime_ms');

    if (bedtime != null) {
      meta['bedtime_minutes'] = bedtime;
    }
    if (waketime != null) {
      meta['waketime_minutes'] = waketime;
    }
    meta['current_day'] = _dayKey(DateTime.now());
    await _writeMeta(meta);
  }

  Future<void> migrateLegacyDataIfNeeded() async {
    await ensureInitialized();
    final meta = await _readMeta();
    if (meta[_migrationCompletedKey] == true) {
      return;
    }

    try {
      final stepBox = await HiveService().stepHistoryBox();
      for (final dynamic rawKey in stepBox.keys) {
        final key = rawKey.toString();
        final StepEntry? entry = stepBox.get(rawKey);
        if (entry == null) continue;
        await writeStepCount(key, entry.steps);
      }

      final sleepBox = await HiveService().sleepLogBox();
      for (final dynamic rawKey in sleepBox.keys) {
        final key = rawKey.toString();
        final SleepLog? log = sleepBox.get(rawKey);
        if (log == null) continue;
        await writeSleepSummary(
          key,
          durationMinutes: log.durationMinutes,
          startTime: log.startTime,
          endTime: log.endTime,
          goalMinutes: log.goalMinutes,
        );
      }

      final queue = await _buildQueueFromDailyFiles();
      await _writeSyncQueue(queue);
      meta[_migrationCompletedKey] = true;
      meta['current_day'] = _dayKey(DateTime.now());
      await _writeMeta(meta);
    } catch (e, stackTrace) {
      debugPrint('❌ Health file migration failed: $e\n$stackTrace');
    }
  }

  Future<int> readStepCount(String dayKey) async {
    final day = await _readDay(dayKey);
    final steps = day['steps'];
    if (steps is Map<String, dynamic>) {
      return (steps['total'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  Future<Map<String, int>> readStepCountsForRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final results = <String, int>{};
    DateTime cursor = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);

    while (!cursor.isAfter(last)) {
      final key = _dayKey(cursor);
      results[key] = await readStepCount(key);
      cursor = cursor.add(const Duration(days: 1));
    }

    return results;
  }

  Future<void> writeStepCount(String dayKey, int steps) async {
    final day = await _readDay(dayKey);
    final stepMap = Map<String, dynamic>.from(
      day['steps'] as Map<String, dynamic>,
    );
    stepMap['total'] = steps;
    stepMap['hourly'] = _normalizeHourly(stepMap['hourly']);
    day['steps'] = stepMap;
    day['sent'] = false;
    day['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    await _writeDay(dayKey, day);
  }

  Future<Duration> readSleepDuration(String dayKey) async {
    final day = await _readDay(dayKey);
    final sleep = day['sleep'];
    if (sleep is Map<String, dynamic>) {
      final minutes = (sleep['total_sleep_minutes'] as num?)?.toInt() ?? 0;
      return Duration(minutes: minutes);
    }
    return Duration.zero;
  }

  Future<Map<String, Duration>> readSleepDurationsForRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final results = <String, Duration>{};
    DateTime cursor = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);

    while (!cursor.isAfter(last)) {
      final key = _dayKey(cursor);
      results[key] = await readSleepDuration(key);
      cursor = cursor.add(const Duration(days: 1));
    }

    return results;
  }

  Future<void> writeSleepSummary(
    String dayKey, {
    required int durationMinutes,
    DateTime? startTime,
    DateTime? endTime,
    int? goalMinutes,
  }) async {
    final day = await _readDay(dayKey);
    final sleepMap = Map<String, dynamic>.from(
      day['sleep'] as Map<String, dynamic>,
    );
    sleepMap['total_sleep_minutes'] = durationMinutes;
    sleepMap['segments'] = _normalizeSegments(sleepMap['segments']);
    if (startTime != null) {
      sleepMap['window_start'] = _formatClock(startTime);
    }
    if (endTime != null) {
      sleepMap['window_end'] = _formatClock(endTime);
    }
    if (goalMinutes != null) {
      sleepMap['goal_minutes'] = goalMinutes;
    }
    day['sleep'] = sleepMap;
    day['sent'] = false;
    day['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    await _writeDay(dayKey, day);
  }

  Future<List<String>> readSyncQueue() async {
    final file = await _syncQueueFile();
    if (!await file.exists()) {
      return const <String>[];
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is List) {
        return decoded.whereType<String>().toList(growable: false);
      }
    } catch (e) {
      debugPrint('❌ Failed to read sync queue: $e');
    }
    return const <String>[];
  }

  Future<void> clearStepSleepHiveData() async {
    try {
      final stepBox = await HiveService().stepHistoryBox();
      final sleepBox = await HiveService().sleepLogBox();
      await stepBox.clear();
      await sleepBox.clear();
    } catch (e) {
      debugPrint('❌ Failed clearing legacy Hive data: $e');
    }
  }

  Future<Map<String, dynamic>> _readMeta() async {
    final file = await _metaFile();
    if (!await file.exists()) {
      final meta = <String, dynamic>{
        'current_day': _dayKey(DateTime.now()),
        'last_sync_ts': 0,
        _migrationCompletedKey: false,
      };
      await file.writeAsString(jsonEncode(meta));
      return meta;
    }

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (e) {
      debugPrint('❌ Failed to read meta.json: $e');
    }

    return <String, dynamic>{
      'current_day': _dayKey(DateTime.now()),
      'last_sync_ts': 0,
      _migrationCompletedKey: false,
    };
  }

  Future<void> _writeMeta(Map<String, dynamic> meta) async {
    final file = await _metaFile();
    await file.writeAsString(jsonEncode(meta), flush: true);
  }

  Future<Map<String, dynamic>> _readDay(String dayKey) async {
    final file = await _dailyFile(dayKey);
    if (!await file.exists()) {
      return _defaultDay(dayKey);
    }

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) {
        final normalized = _defaultDay(dayKey);
        normalized.addAll(decoded);
        normalized['steps'] = _normalizeStepsMap(decoded['steps']);
        normalized['sleep'] = _normalizeSleepMap(decoded['sleep']);
        return normalized;
      }
    } catch (e) {
      debugPrint('❌ Failed to read daily file for $dayKey: $e');
    }

    return _defaultDay(dayKey);
  }

  Future<void> _writeDay(String dayKey, Map<String, dynamic> payload) async {
    final file = await _dailyFile(dayKey);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(payload), flush: true);
  }

  Future<List<String>> _buildQueueFromDailyFiles() async {
    final directory = await _dailyDir();
    final builder = <String>[];
    await for (final entity in directory.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final name =
          entity.uri.pathSegments.isNotEmpty
              ? entity.uri.pathSegments.last
              : entity.path.split(Platform.pathSeparator).last;
      builder.add(name.replaceFirst('.json', ''));
    }
    builder.sort();
    return builder;
  }

  Future<void> _writeSyncQueue(List<String> queue) async {
    final file = await _syncQueueFile();
    await file.writeAsString(jsonEncode(queue), flush: true);
  }

  Map<String, dynamic> _defaultDay(String dayKey) {
    return <String, dynamic>{
      'date': dayKey,
      'steps': <String, dynamic>{'total': 0, 'hourly': List<int>.filled(24, 0)},
      'sleep': <String, dynamic>{
        'segments': <Map<String, dynamic>>[],
        'total_sleep_minutes': 0,
      },
      'sent': false,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> _normalizeStepsMap(dynamic raw) {
    final steps =
        raw is Map<String, dynamic>
            ? Map<String, dynamic>.from(raw)
            : <String, dynamic>{};
    steps['total'] = (steps['total'] as num?)?.toInt() ?? 0;
    steps['hourly'] = _normalizeHourly(steps['hourly']);
    return steps;
  }

  Map<String, dynamic> _normalizeSleepMap(dynamic raw) {
    final sleep =
        raw is Map<String, dynamic>
            ? Map<String, dynamic>.from(raw)
            : <String, dynamic>{};
    sleep['total_sleep_minutes'] =
        (sleep['total_sleep_minutes'] as num?)?.toInt() ?? 0;
    sleep['segments'] = _normalizeSegments(sleep['segments']);
    return sleep;
  }

  List<int> _normalizeHourly(dynamic raw) {
    final hourly = List<int>.filled(24, 0);
    if (raw is List) {
      for (int index = 0; index < raw.length && index < 24; index++) {
        final value = raw[index];
        hourly[index] = (value as num?)?.toInt() ?? 0;
      }
    }
    return hourly;
  }

  List<Map<String, dynamic>> _normalizeSegments(dynamic raw) {
    if (raw is! List) return <Map<String, dynamic>>[];

    return raw
        .whereType<Map>()
        .map(
          (segment) => <String, dynamic>{
            'screen_off': (segment['screen_off'] as num?)?.toInt() ?? 0,
            'screen_on': (segment['screen_on'] as num?)?.toInt() ?? 0,
          },
        )
        .toList(growable: false);
  }

  String _dayKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _formatClock(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
