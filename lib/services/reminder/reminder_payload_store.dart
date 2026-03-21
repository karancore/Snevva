import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:snevva/models/hive_models/reminder_payload_model.dart';
import 'package:snevva/services/hive_service.dart';

class ReminderPayloadStore {
  static const String _keyPrefix = 'reminder_payloads_v1:';

  final HiveService _hiveService;
  final String _scope;

  ReminderPayloadStore({
    required String scope,
    HiveService? hiveService,
  }) : _scope = scope.trim().isEmpty ? 'anonymous' : scope.trim(),
       _hiveService = hiveService ?? HiveService();

  String get _key => '$_keyPrefix$_scope';

  Future<void> write(List<ReminderPayloadModel> reminders) async {
    final box = await _hiveService.remindersBox();
    final encoded =
        reminders.map((r) => jsonEncode(r.toJson())).toList(growable: false);
    await box.put(_key, encoded);
  }

  Future<void> upsert(ReminderPayloadModel reminder) async {
    final current = await read();
    final next = <ReminderPayloadModel>[];
    var replaced = false;
    for (final r in current) {
      if (r.id == reminder.id) {
        next.add(reminder);
        replaced = true;
      } else {
        next.add(r);
      }
    }
    if (!replaced) {
      next.add(reminder);
    }
    await write(next);
  }

  Future<void> removeById(int id) async {
    final current = await read();
    final next = current.where((r) => r.id != id).toList(growable: false);
    await write(next);
  }

  Future<List<ReminderPayloadModel>> read() async {
    final box = await _hiveService.remindersBox();
    final raw = box.get(_key);
    if (raw is! List) return const [];

    final out = <ReminderPayloadModel>[];
    for (final item in raw) {
      if (item is! String) continue;
      try {
        final decoded = jsonDecode(item);
        if (decoded is! Map<String, dynamic>) continue;
        out.add(ReminderPayloadModel.fromJson(decoded));
      } catch (e) {
        debugPrint('ReminderPayloadStore: failed to decode reminder: $e');
      }
    }
    return out;
  }

  Future<void> clear() async {
    final box = await _hiveService.remindersBox();
    await box.delete(_key);
  }
}
