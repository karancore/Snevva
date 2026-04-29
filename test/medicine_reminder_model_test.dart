import 'package:flutter_test/flutter_test.dart';
import 'package:snevva/common/global_variables.dart';
import 'package:snevva/models/reminder_schedule_metadata.dart';
import 'package:snevva/models/reminders/medicine_reminder_model.dart';

void main() {
  group('MedicineReminderModel.fromJson', () {
    test('preserves times from mixed-case persisted reminder payloads', () {
      final model = MedicineReminderModel.fromJson({
        'Id': 345835231,
        'Title': 'Asa',
        'Category': 'medicine',
        'MedicineName': 'Asa',
        'MedicineType': 'Tablet',
        'WhenToTake': 'Before food',
        'Dosage': {'Value': 1, 'Unit': 'TABLET'},
        'MedicineFrequencyPerDay': '1',
        'ReminderFrequencyType': 'Once',
        'CustomReminder': {
          'Type': Option.times.name,
          'TimesPerDay': {
            'Count': '1',
            'List': ['10:18'],
          },
        },
        'UpdatedAt': '2026-04-16T10:16:51.303053',
        'ScheduleMetadata':
            const ReminderScheduleMetadata(
              timezoneId: 'Asia/Kolkata',
              scheduleSemantics: ScheduleSemantics.wallClock,
              alarmIds: [637376590],
            ).toJson(),
      }, timezoneIdFallback: 'Asia/Kolkata');

      expect(model.id, 345835231);
      expect(model.title, 'Asa');
      expect(model.medicineName, 'Asa');
      expect(model.customReminder.type, Option.times);
      expect(model.customReminder.timesPerDay?.count, '1');
      expect(model.customReminder.timesPerDay?.list, ['10:18']);
      expect(model.scheduleMetadata.alarmIds, [637376590]);
    });

    test(
      'uses the supplied local timezone fallback for single-instance reminders when metadata is missing',
      () {
        final model = MedicineReminderModel.fromJson({
          'Id': 345835232,
          'Title': 'Asa',
          'Category': 'medicine',
          'MedicineName': 'Asa',
          'MedicineType': 'Tablet',
          'WhenToTake': 'Before food',
          'Dosage': {'Value': 1, 'Unit': 'TABLET'},
          'MedicineFrequencyPerDay': '1',
          'ReminderFrequencyType': 'Once',
          'CustomReminder': {
            'Type': Option.times.name,
            'TimesPerDay': {
              'Count': '1',
              'List': ['10:18'],
            },
          },
        }, timezoneIdFallback: 'Asia/Kolkata');

        expect(model.scheduleMetadata.timezoneId, 'Asia/Kolkata');
        expect(
          model.scheduleMetadata.scheduleSemantics,
          ScheduleSemantics.absolute,
        );
      },
    );
  });
}
