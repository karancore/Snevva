import 'package:flutter_test/flutter_test.dart';
import 'package:snevva/services/sleep_noticing_service.dart';

void main() {
  late SleepNoticingService service;

  setUp(() {
    service = SleepNoticingService();
  });

  group('SleepNoticingService Logic Tests', () {
    test('Condition 1: Phone used within 15 minutes of bedtime -> Ignore usage', () {
      final bedtime = DateTime(2023, 1, 1, 22, 0); // 10:00 PM
      final phoneUsageStart = DateTime(2023, 1, 1, 22, 10); // 10:10 PM (within 15 mins)
      final phoneUsageDuration = Duration(minutes: 5);

      final newBedtime = service.calculateNewBedtime(
        bedtime: bedtime,
        phoneUsageStart: phoneUsageStart,
        phoneUsageDuration: phoneUsageDuration,
      );

      expect(newBedtime, bedtime);
    });

    test('Condition 2: Phone used after 15 minutes -> Adjust bedtime', () {
      final bedtime = DateTime(2023, 1, 1, 22, 0); // 10:00 PM
      final phoneUsageStart = DateTime(2023, 1, 1, 22, 20); // 10:20 PM (after 15 mins)
      final phoneUsageDuration = Duration(minutes: 10); // Used for 10 mins

      // Expected Logic:
      // Usage End = 10:20 + 10m = 10:30 PM
      // New Bedtime = Usage End - 15m = 10:15 PM
      final expectedBedtime = DateTime(2023, 1, 1, 22, 15);

      final newBedtime = service.calculateNewBedtime(
        bedtime: bedtime,
        phoneUsageStart: phoneUsageStart,
        phoneUsageDuration: phoneUsageDuration,
      );

      expect(newBedtime, expectedBedtime);
    });

    test('Edge Case: Usage exactly at 15 minutes -> Should Adjust (based on current logic)', () {
      final bedtime = DateTime(2023, 1, 1, 22, 0);
      final phoneUsageStart = DateTime(2023, 1, 1, 22, 15); // Exactly 15 mins
      final phoneUsageDuration = Duration(minutes: 5);

      // Usage End = 22:20
      // New Bedtime = 22:20 - 15 = 22:05
      final expectedBedtime = DateTime(2023, 1, 1, 22, 5);

      final newBedtime = service.calculateNewBedtime(
        bedtime: bedtime,
        phoneUsageStart: phoneUsageStart,
        phoneUsageDuration: phoneUsageDuration,
      );

      expect(newBedtime, expectedBedtime);
    });

    test('Edge Case: Midnight Crossing', () {
      final bedtime = DateTime(2023, 1, 1, 23, 30); // 11:30 PM
      final phoneUsageStart = DateTime(2023, 1, 2, 0, 10); // 12:10 AM next day (40 mins later)
      final phoneUsageDuration = Duration(minutes: 20);

      // Usage End = 00:10 + 20m = 00:30
      // New Bedtime = 00:30 - 15m = 00:15
      final expectedBedtime = DateTime(2023, 1, 2, 0, 15);

      final newBedtime = service.calculateNewBedtime(
        bedtime: bedtime,
        phoneUsageStart: phoneUsageStart,
        phoneUsageDuration: phoneUsageDuration,
      );

      expect(newBedtime, expectedBedtime);
    });

    test('Deep Sleep Calculation', () {
      final newBedtime = DateTime(2023, 1, 1, 23, 0); // 11:00 PM
      final wakeTime = DateTime(2023, 1, 2, 7, 0); // 7:00 AM next day

      final deepSleep = service.calculateDeepSleep(newBedtime, wakeTime);

      expect(deepSleep.inHours, 8);
    });
  });
}
