import 'package:flutter_test/flutter_test.dart';
import 'package:snevva/common/global_variables.dart';
import 'package:snevva/models/hive_models/reminder_payload_model.dart';
import 'package:snevva/models/mappers/reminder_api_mapper.dart';
import 'package:snevva/models/reminder_schedule_metadata.dart';

void main() {
  group('ReminderApiMapper', () {
    test('maps exact API category casing to internal lowercase', () {
      final reminder = ReminderApiMapper.fromApiJson({
        'Id': 42,
        'Title': 'Hydrate',
        'Category': 'Water',
        'CustomReminder': {
          'Type': Option.times.name,
          'TimesPerDay': {
            'Count': '2',
            'List': ['08:00', '12:00'],
          },
        },
        'StartWaterTime': '08:00',
        'EndWaterTime': '20:00',
      }, timezoneIdFallback: 'Asia/Kolkata');

      expect(reminder.category, 'water');
      expect(reminder.scheduleMetadata.timezoneId, 'Asia/Kolkata');
      expect(
        reminder.scheduleMetadata.scheduleSemantics,
        ScheduleSemantics.wallClock,
      );
    });

    test('preserves exact API category casing on output', () {
      final reminder = ReminderPayloadModel(
        id: 7,
        title: 'Morning meds',
        category: 'medicine',
        medicineName: 'Vitamin C',
        medicineType: 'Tablet',
        whenToTake: 'After food',
        customReminder: const CustomReminder(
          type: Option.times,
          timesPerDay: TimesPerDay(count: '1', list: ['08:00']),
        ),
        scheduleMetadata: const ReminderScheduleMetadata(
          timezoneId: 'Asia/Kolkata',
          scheduleSemantics: ScheduleSemantics.absolute,
        ),
      );

      final payload = ReminderApiMapper.toApiJson(reminder);

      expect(payload['Category'], 'Medicine');
      expect(payload['CustomReminder']['TimesPerDay']['List'], ['08:00']);
    });
  });
}
