import 'package:flutter_test/flutter_test.dart';
import 'package:snevva/Controllers/Reminder/reminder_controller.dart';
import 'package:snevva/services/reminder/reminder_schedule_resolver.dart';
import 'package:timezone/data/latest.dart' as tz_data;

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
  });

  group('normalizeReminderTimesForPersistence', () {
    test('preserves canonical HH:mm times from time-only input', () {
      expect(normalizeReminderTimesForPersistence(['15:24', '3:05 PM']), [
        '15:24',
        '15:05',
      ]);
    });

    test('converts ISO timestamps into local HH:mm values', () {
      const rawIso = '2026-04-15T09:54:00.000Z';

      expect(normalizeReminderTimesForPersistence([rawIso]), [
        canonicalLocalTime(rawIso),
      ]);
    });

    test('skips malformed entries without dropping valid times', () {
      expect(normalizeReminderTimesForPersistence(['bad-value', '15:30', '']), [
        '15:30',
      ]);
    });
  });

  group('reminderDateTimeInTimezone', () {
    test(
      'projects a stored alarm instant back into the reminder timezone wall clock',
      () {
        final scheduledUtc = DateTime.utc(2026, 4, 23, 7, 42);

        final reminderDateTime = reminderDateTimeInTimezone(
          scheduledUtc,
          timezoneId: 'Asia/Kolkata',
        );

        expect(reminderDateTime.year, 2026);
        expect(reminderDateTime.month, 4);
        expect(reminderDateTime.day, 23);
        expect(reminderDateTime.hour, 13);
        expect(reminderDateTime.minute, 12);
      },
    );

    test('falls back to the process local timezone for Local metadata', () {
      final scheduledUtc = DateTime.utc(2026, 4, 23, 7, 42);

      final reminderDateTime = reminderDateTimeInTimezone(
        scheduledUtc,
        timezoneId: 'Local',
      );

      expect(reminderDateTime, scheduledUtc.toLocal());
    });
  });
}
