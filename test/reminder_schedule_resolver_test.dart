import 'package:flutter_test/flutter_test.dart';
import 'package:snevva/services/reminder/reminder_schedule_resolver.dart';

void main() {
  group('canonical date/time parsing', () {
    test('normalizes legacy display dates to ISO calendar dates', () {
      expect(canonicalLocalDate('April 11, 2026'), '2026-04-11');
      expect(canonicalLocalDate('2026-04-11T18:30:00'), '2026-04-11');
    });

    test('normalizes common time formats to canonical 24 hour values', () {
      expect(canonicalLocalTime('8:05 pm'), '20:05');
      expect(canonicalLocalTime('12:00 AM'), '00:00');
      expect(canonicalLocalTime('2026-04-11T09:45:00'), '09:45');
    });

    test('generates canonical wall-clock times for times-per-day windows', () {
      expect(
        generateTimesBetween(startTime: '08:00', endTime: '20:00', times: 3),
        ['08:00', '12:00', '16:00'],
      );
    });
  });
}
