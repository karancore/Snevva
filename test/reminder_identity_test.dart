import 'dart:convert';

import 'package:alarm/alarm.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/services/reminder/reminder_identity.dart';

void main() {
  group('ReminderIdentity', () {
    AlarmSettings buildAlarm({
      required int alarmId,
      Map<String, dynamic>? payload,
    }) {
      return AlarmSettings(
        id: alarmId,
        dateTime: DateTime(2026, 4, 15, 9, 0),
        assetAudioPath: alarmSound,
        volumeSettings: VolumeSettings.fade(fadeDuration: Duration(seconds: 1)),
        notificationSettings: const NotificationSettings(
          title: 'Reminder',
          body: 'Body',
          stopButton: 'Stop',
        ),
        payload: payload == null ? null : jsonEncode(payload),
      );
    }

    test('prefers persisted groupId over scheduled alarm id', () {
      final alarm = buildAlarm(
        alarmId: 1987654321,
        payload: {'groupId': '42', 'category': 'meal'},
      );

      expect(ReminderIdentity.reminderIdFromAlarm(alarm), 42);
      expect(ReminderIdentity.matchesReminderId(alarm, 42), isTrue);
      expect(ReminderIdentity.matchesReminderId(alarm, alarm.id), isFalse);
    });

    test('falls back to alarm id for legacy entries without groupId', () {
      final alarm = buildAlarm(alarmId: 13579, payload: {'category': 'event'});

      expect(ReminderIdentity.reminderIdFromAlarm(alarm), 13579);
      expect(ReminderIdentity.matchesReminderId(alarm, 13579), isTrue);
    });

    test('returns empty payload map for invalid payload json', () {
      final decoded = ReminderIdentity.decodePayload('{not-json');

      expect(decoded, isEmpty);
    });
  });
}
