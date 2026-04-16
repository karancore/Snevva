import 'package:flutter_test/flutter_test.dart';
import 'package:snevva/Controllers/Reminder/reminder_controller.dart';
import 'package:snevva/services/reminder/reminder_schedule_resolver.dart';

void main() {
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
}
