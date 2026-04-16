import 'package:alarm/alarm.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snevva/common/global_variables.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/models/reminder_schedule_metadata.dart';
import 'package:snevva/models/reminders/water_reminder_model.dart';

void main() {
  group('WaterReminderModel.fromJson', () {
    AlarmSettings buildAlarm(int id, DateTime dateTime) {
      return AlarmSettings(
        id: id,
        dateTime: dateTime,
        assetAudioPath: alarmSound,
        volumeSettings: VolumeSettings.fade(
          fadeDuration: const Duration(seconds: 1),
        ),
        notificationSettings: const NotificationSettings(
          title: 'Water alarms',
          body: 'Time to drink water!',
          stopButton: 'Stop',
        ),
      );
    }

    test('hydrates alarm maps decoded from persisted Hive JSON', () {
      final alarms = [
        buildAlarm(1001, DateTime(2026, 4, 15, 16, 30)),
        buildAlarm(1002, DateTime(2026, 4, 15, 17, 30)),
        buildAlarm(1003, DateTime(2026, 4, 15, 18, 30)),
      ];

      final model = WaterReminderModel.fromJson({
        'id': 281729654,
        'title': 'Water alarms',
        'Category': 'water',
        'type': Option.interval.name,
        'alarms': alarms.map((alarm) => alarm.toJson()).toList(),
        'timesPerDay': '',
        'waterReminderStartTime': '15:30',
        'waterReminderEndTime': '18:30',
        'interval': '1',
        'scheduleMetadata': const ReminderScheduleMetadata(
          timezoneId: 'Asia/Kolkata',
          scheduleSemantics: ScheduleSemantics.wallClock,
          alarmIds: [1001, 1002, 1003],
        ).toJson(),
      });

      expect(model.id, 281729654);
      expect(model.type, Option.interval);
      expect(model.alarms, hasLength(3));
      expect(model.alarms.map((alarm) => alarm.id), [1001, 1002, 1003]);
      expect(model.waterReminderStartTime, '15:30');
      expect(model.waterReminderEndTime, '18:30');
      expect(model.scheduleMetadata.timezoneId, 'Asia/Kolkata');
      expect(model.scheduleMetadata.alarmIds, [1001, 1002, 1003]);
    });
  });
}
