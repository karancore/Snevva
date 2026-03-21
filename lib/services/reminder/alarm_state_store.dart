import 'dart:convert';

import 'package:alarm/model/alarm_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:snevva/services/hive_service.dart';

class AlarmStateSnapshot {
  final Map<int, int> scheduledIdsEpochMs;
  final Map<int, int> triggeredIdsEpochMs;
  final Map<String, int> scheduledSignaturesEpochMs;
  final Map<String, int> triggeredSignaturesEpochMs;
  final Map<String, int> scheduledSignatureToAlarmId;
  final Map<String, int> triggeredSignatureToAlarmId;

  const AlarmStateSnapshot({
    required this.scheduledIdsEpochMs,
    required this.triggeredIdsEpochMs,
    required this.scheduledSignaturesEpochMs,
    required this.triggeredSignaturesEpochMs,
    required this.scheduledSignatureToAlarmId,
    required this.triggeredSignatureToAlarmId,
  });

  static const empty = AlarmStateSnapshot(
    scheduledIdsEpochMs: <int, int>{},
    triggeredIdsEpochMs: <int, int>{},
    scheduledSignaturesEpochMs: <String, int>{},
    triggeredSignaturesEpochMs: <String, int>{},
    scheduledSignatureToAlarmId: <String, int>{},
    triggeredSignatureToAlarmId: <String, int>{},
  );
}

class AlarmStateStore {
  static const String _keyPrefix = 'alarm_state_v1:';

  final HiveService _hiveService;
  final String _scope;

  AlarmStateStore({
    required String scope,
    HiveService? hiveService,
  }) : _scope = scope.trim().isEmpty ? 'anonymous' : scope.trim(),
       _hiveService = hiveService ?? HiveService();

  String get _key => '$_keyPrefix$_scope';

  Future<AlarmStateSnapshot> read() async {
    final box = await _hiveService.remindersBox();
    final raw = box.get(_key);
    if (raw is! String || raw.trim().isEmpty) return AlarmStateSnapshot.empty;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return AlarmStateSnapshot.empty;

      Map<int, int> readIntMap(String key) {
        final value = decoded[key];
        if (value is! Map) return <int, int>{};
        final out = <int, int>{};
        value.forEach((k, v) {
          final id = int.tryParse(k.toString());
          final epoch = v is int ? v : int.tryParse(v.toString());
          if (id != null && epoch != null) out[id] = epoch;
        });
        return out;
      }

      Map<String, int> readStringMap(String key) {
        final value = decoded[key];
        if (value is! Map) return <String, int>{};
        final out = <String, int>{};
        value.forEach((k, v) {
          final sig = k.toString();
          final epoch = v is int ? v : int.tryParse(v.toString());
          if (sig.isNotEmpty && epoch != null) out[sig] = epoch;
        });
        return out;
      }

      return AlarmStateSnapshot(
        scheduledIdsEpochMs: readIntMap('scheduledIds'),
        triggeredIdsEpochMs: readIntMap('triggeredIds'),
        scheduledSignaturesEpochMs: readStringMap('scheduledSigs'),
        triggeredSignaturesEpochMs: readStringMap('triggeredSigs'),
        scheduledSignatureToAlarmId: readStringMap('scheduledSigToId'),
        triggeredSignatureToAlarmId: readStringMap('triggeredSigToId'),
      );
    } catch (_) {
      return AlarmStateSnapshot.empty;
    }
  }

  Future<void> write(AlarmStateSnapshot snapshot) async {
    final box = await _hiveService.remindersBox();
    final payload = <String, dynamic>{
      'scheduledIds': snapshot.scheduledIdsEpochMs.map(
        (k, v) => MapEntry(k.toString(), v),
      ),
      'triggeredIds': snapshot.triggeredIdsEpochMs.map(
        (k, v) => MapEntry(k.toString(), v),
      ),
      'scheduledSigs': snapshot.scheduledSignaturesEpochMs,
      'triggeredSigs': snapshot.triggeredSignaturesEpochMs,
      'scheduledSigToId': snapshot.scheduledSignatureToAlarmId,
      'triggeredSigToId': snapshot.triggeredSignatureToAlarmId,
    };
    await box.put(_key, jsonEncode(payload));
  }

  Future<void> prune({Duration maxAge = const Duration(days: 14)}) async {
    final nowEpoch = DateTime.now().millisecondsSinceEpoch;
    final cutoff = nowEpoch - maxAge.inMilliseconds;

    final snapshot = await read();

    Map<int, int> pruneIntMap(Map<int, int> input) {
      final out = <int, int>{};
      input.forEach((k, v) {
        if (v >= cutoff) out[k] = v;
      });
      return out;
    }

    Map<String, int> pruneStringMap(Map<String, int> input) {
      final out = <String, int>{};
      input.forEach((k, v) {
        if (v >= cutoff) out[k] = v;
      });
      return out;
    }

    final pruned = AlarmStateSnapshot(
      scheduledIdsEpochMs: pruneIntMap(snapshot.scheduledIdsEpochMs),
      triggeredIdsEpochMs: pruneIntMap(snapshot.triggeredIdsEpochMs),
      scheduledSignaturesEpochMs: pruneStringMap(snapshot.scheduledSignaturesEpochMs),
      triggeredSignaturesEpochMs: pruneStringMap(snapshot.triggeredSignaturesEpochMs),
      scheduledSignatureToAlarmId: pruneStringMap(snapshot.scheduledSignatureToAlarmId),
      triggeredSignatureToAlarmId: pruneStringMap(snapshot.triggeredSignatureToAlarmId),
    );

    await write(pruned);
  }

  Future<void> clear() async {
    final box = await _hiveService.remindersBox();
    await box.delete(_key);
  }

  Future<void> markScheduled({
    required int alarmId,
    required String signature,
    required DateTime scheduledAt,
  }) async {
    final snapshot = await read();
    final nowEpoch = DateTime.now().millisecondsSinceEpoch;

    final scheduledIds = Map<int, int>.from(snapshot.scheduledIdsEpochMs);
    final scheduledSigs = Map<String, int>.from(snapshot.scheduledSignaturesEpochMs);
    final scheduledSigToId = Map<String, int>.from(snapshot.scheduledSignatureToAlarmId);
    final triggeredIds = Map<int, int>.from(snapshot.triggeredIdsEpochMs);
    final triggeredSigs = Map<String, int>.from(snapshot.triggeredSignaturesEpochMs);
    final triggeredSigToId = Map<String, int>.from(snapshot.triggeredSignatureToAlarmId);

    scheduledIds[alarmId] = nowEpoch;
    scheduledSigs[signature] = scheduledAt.millisecondsSinceEpoch;
    scheduledSigToId[signature] = alarmId;

    // If we are re-scheduling the same id/signature, it is no longer "triggered".
    triggeredIds.remove(alarmId);
    triggeredSigs.remove(signature);
    triggeredSigToId.remove(signature);

    await write(
      AlarmStateSnapshot(
        scheduledIdsEpochMs: scheduledIds,
        triggeredIdsEpochMs: triggeredIds,
        scheduledSignaturesEpochMs: scheduledSigs,
        triggeredSignaturesEpochMs: triggeredSigs,
        scheduledSignatureToAlarmId: scheduledSigToId,
        triggeredSignatureToAlarmId: triggeredSigToId,
      ),
    );
  }

  Future<void> markTriggered({
    required int alarmId,
    required String signature,
    required DateTime triggeredAt,
  }) async {
    final snapshot = await read();
    final nowEpoch = DateTime.now().millisecondsSinceEpoch;

    final scheduledIds = Map<int, int>.from(snapshot.scheduledIdsEpochMs);
    final scheduledSigs = Map<String, int>.from(snapshot.scheduledSignaturesEpochMs);
    final scheduledSigToId = Map<String, int>.from(snapshot.scheduledSignatureToAlarmId);
    final triggeredIds = Map<int, int>.from(snapshot.triggeredIdsEpochMs);
    final triggeredSigs = Map<String, int>.from(snapshot.triggeredSignaturesEpochMs);
    final triggeredSigToId = Map<String, int>.from(snapshot.triggeredSignatureToAlarmId);

    scheduledIds.remove(alarmId);
    scheduledSigs.remove(signature);
    scheduledSigToId.remove(signature);

    triggeredIds[alarmId] = nowEpoch;
    triggeredSigs[signature] = triggeredAt.millisecondsSinceEpoch;
    triggeredSigToId[signature] = alarmId;

    await write(
      AlarmStateSnapshot(
        scheduledIdsEpochMs: scheduledIds,
        triggeredIdsEpochMs: triggeredIds,
        scheduledSignaturesEpochMs: scheduledSigs,
        triggeredSignaturesEpochMs: triggeredSigs,
        scheduledSignatureToAlarmId: scheduledSigToId,
        triggeredSignatureToAlarmId: triggeredSigToId,
      ),
    );
  }

  Future<void> markTriggeredFromAlarm(AlarmSettings alarm, {String? signature}) async {
    try {
      await markTriggered(
        alarmId: alarm.id,
        signature: signature ?? 'id:${alarm.id}|at:${alarm.dateTime.toIso8601String()}',
        triggeredAt: alarm.dateTime,
      );
    } catch (e) {
      debugPrint('AlarmStateStore.markTriggeredFromAlarm failed: $e');
    }
  }
}
