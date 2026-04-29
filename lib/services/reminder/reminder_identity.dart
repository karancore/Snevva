import 'dart:convert';

import 'package:alarm/model/alarm_settings.dart';

class ReminderIdentity {
  const ReminderIdentity._();

  static Map<String, dynamic> decodePayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) {
      return const <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}

    return const <String, dynamic>{};
  }

  static int reminderIdFromPayload(
    Map<String, dynamic> payload, {
    required int fallbackId,
  }) {
    final parsed = int.tryParse(payload['groupId']?.toString() ?? '');
    return parsed ?? fallbackId;
  }

  static int reminderIdFromAlarm(AlarmSettings alarm) {
    return reminderIdFromPayload(
      decodePayload(alarm.payload),
      fallbackId: alarm.id,
    );
  }

  static bool matchesReminderId(AlarmSettings alarm, int reminderId) {
    return reminderIdFromAlarm(alarm) == reminderId;
  }
}
