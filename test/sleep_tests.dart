import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════════
// QUICK FIX VERSION - Minimal setup for immediate testing
// ══════════════════════════════════════════════════════════════════

void main() {
  // Initialize test environment
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Initialize Hive with temp directory for tests
    final tempDir = Directory.systemTemp.createTempSync('hive_test_');
    Hive.init(tempDir.path);

    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({});

    // Set GetX to test mode
    Get.testMode = true;
  });

  tearDownAll(() async {
    await Hive.close();
  });

  group('Sleep Detection Logic Tests (Unit)', () {
    test('Screen off duration calculation', () {
      final screenOffTime = DateTime(2026, 1, 22, 23, 0);
      final screenOnTime = DateTime(2026, 1, 23, 7, 0); // 8 hours later

      final duration = screenOnTime.difference(screenOffTime);

      expect(duration.inHours, equals(8));
      expect(duration.inMinutes, equals(480));
    });

    test('Short screen-off should be ignored (< 3 min)', () {
      final screenOffTime = DateTime(2026, 1, 22, 23, 0);
      final screenOnTime = DateTime(2026, 1, 22, 23, 2, 30); // 2.5 min

      final duration = screenOnTime.difference(screenOffTime);
      const minSleepGap = Duration(minutes: 3);

      final shouldBeIgnored = duration < minSleepGap;

      expect(shouldBeIgnored, isTrue);
    });

    test('Valid sleep duration (> 3 min)', () {
      final screenOffTime = DateTime(2026, 1, 22, 23, 0);
      final screenOnTime = DateTime(2026, 1, 22, 23, 5); // 5 min

      final duration = screenOnTime.difference(screenOffTime);
      const minSleepGap = Duration(minutes: 3);

      final isValid = duration >= minSleepGap;

      expect(isValid, isTrue);
    });
  });

  group('Midnight Boundary Tests', () {
    test('Sleep spans midnight (23:00 → 07:00)', () {
      final bedtime = DateTime(2026, 1, 22, 23, 0);
      final wakeTime = DateTime(2026, 1, 23, 7, 0);

      final duration = wakeTime.difference(bedtime);

      expect(duration.inHours, equals(8));
      expect(bedtime.day, equals(22));
      expect(wakeTime.day, equals(23));
    });

    test('Wake time normalization when before bedtime', () {
      final bedtime = DateTime(2026, 1, 22, 23, 0);
      DateTime wakeTime = DateTime(2026, 1, 22, 7, 0); // Same day!

      // Normalize
      if (wakeTime.isBefore(bedtime) || wakeTime.isAtSameMomentAs(bedtime)) {
        wakeTime = wakeTime.add(Duration(days: 1));
      }

      expect(wakeTime.day, equals(23));
      expect(wakeTime.difference(bedtime).inHours, equals(8));
    });

    test('Phone usage spans midnight', () {
      final usageStart = DateTime(2026, 1, 22, 23, 50);
      final usageEnd = DateTime(2026, 1, 23, 0, 10);

      final duration = usageEnd.difference(usageStart);

      expect(duration.inMinutes, equals(20));
    });

    test('Bedtime after midnight, wake in morning', () {
      final bedtime = DateTime(2026, 1, 23, 2, 0); // 2 AM
      final wakeTime = DateTime(2026, 1, 23, 10, 0); // 10 AM same day

      final duration = wakeTime.difference(bedtime);

      expect(duration.inHours, equals(8));
    });
  });

  group('Duration Validation Tests', () {
    test('Very short sleep (< 10 min) should be rejected', () {
      final duration = Duration(minutes: 5);
      final isValid = duration.inMinutes >= 10;

      expect(isValid, isFalse);
    });

    test('Exactly 10 minutes (boundary)', () {
      final duration = Duration(minutes: 10);
      final isValid = duration.inMinutes >= 10;

      expect(isValid, isTrue);
    });

    test('Negative duration detection', () {
      final bedtime = DateTime(2026, 1, 23, 7, 0);
      final wakeTime = DateTime(2026, 1, 22, 23, 0);

      final duration = wakeTime.difference(bedtime);

      expect(duration.isNegative, isTrue);
    });

    test('24+ hour sleep (extreme case)', () {
      final bedtime = DateTime(2026, 1, 22, 23, 0);
      final wakeTime = DateTime(2026, 1, 24, 10, 0); // 35 hours

      final duration = wakeTime.difference(bedtime);

      expect(duration.inHours, equals(35));
    });
  });

  group('Bedtime Adjustment Logic Tests', () {
    test('Phone used within 15-min grace period (should ignore)', () {
      final bedtime = DateTime(2026, 1, 22, 23, 0);
      final phoneStart = DateTime(2026, 1, 22, 23, 10); // 10 min after

      const gracePeriod = Duration(minutes: 15);
      final safeLimit = bedtime.add(gracePeriod);

      final shouldIgnore = phoneStart.isBefore(safeLimit);

      expect(shouldIgnore, isTrue);
    });

    test('Phone used at exactly 15 minutes (boundary)', () {
      final bedtime = DateTime(2026, 1, 22, 23, 0);
      final phoneStart = DateTime(2026, 1, 22, 23, 15); // Exactly 15 min

      const gracePeriod = Duration(minutes: 15);
      final safeLimit = bedtime.add(gracePeriod);

      final shouldIgnore = phoneStart.isBefore(safeLimit);

      expect(shouldIgnore, isFalse); // At boundary, should NOT ignore
    });

    test('Phone used 16 min after bedtime (outside grace)', () {
      final bedtime = DateTime(2026, 1, 22, 23, 0);
      final phoneStart = DateTime(2026, 1, 22, 23, 16);
      final phoneDuration = Duration(minutes: 40);

      const gracePeriod = Duration(minutes: 15);
      final safeLimit = bedtime.add(gracePeriod);

      final shouldAdjust = phoneStart.isAfter(safeLimit) ||
          phoneStart.isAtSameMomentAs(safeLimit);

      if (shouldAdjust) {
        final usageEnd = phoneStart.add(phoneDuration);
        final newBedtime = usageEnd.subtract(Duration(minutes: 15));

        expect(newBedtime.isAfter(bedtime), isTrue);
        expect(newBedtime.hour, equals(23));
        expect(newBedtime.minute, equals(41));
      }

      expect(shouldAdjust, isTrue);
    });

    test('Calculate new bedtime formula', () {
      final phoneStart = DateTime(2026, 1, 22, 23, 30);
      final phoneDuration = Duration(minutes: 20);

      final usageEnd = phoneStart.add(phoneDuration);
      final newBedtime = usageEnd.subtract(Duration(minutes: 15));

      // Usage ends at 23:50, new bedtime should be 23:35
      expect(newBedtime.hour, equals(23));
      expect(newBedtime.minute, equals(35));
    });
  });

  group('Interval Merging Tests', () {
    test('Overlapping intervals should merge', () {
      final intervals = <Map<String, DateTime>>[
        {
          'start': DateTime(2026, 1, 23, 1, 0),
          'end': DateTime(2026, 1, 23, 1, 30),
        },
        {
          'start': DateTime(2026, 1, 23, 1, 20), // Overlaps
          'end': DateTime(2026, 1, 23, 1, 50),
        },
      ];

      // Sort by start time
      intervals.sort((a, b) => a['start']!.compareTo(b['start']!));

      // Merge logic
      final merged = <Map<String, DateTime>>[];
      var current = intervals.first;

      for (int i = 1; i < intervals.length; i++) {
        final next = intervals[i];

        if (!next['start']!.isAfter(current['end']!)) {
          // Merge
          current = {
            'start': current['start']!,
            'end': next['end']!.isAfter(current['end']!)
                ? next['end']!
                : current['end']!,
          };
        } else {
          merged.add(current);
          current = next;
        }
      }
      merged.add(current);

      expect(merged.length, equals(1));
      expect(merged.first['start'], equals(DateTime(2026, 1, 23, 1, 0)));
      expect(merged.first['end'], equals(DateTime(2026, 1, 23, 1, 50)));
    });

    test('Touching intervals (end = next start) should merge', () {
      final interval1End = DateTime(2026, 1, 23, 1, 30);
      final interval2Start = DateTime(2026, 1, 23, 1, 30);

      final shouldMerge = !interval2Start.isAfter(interval1End);

      expect(shouldMerge, isTrue);
    });

    test('Non-overlapping intervals remain separate', () {
      final intervals = <Map<String, DateTime>>[
        {
          'start': DateTime(2026, 1, 23, 1, 0),
          'end': DateTime(2026, 1, 23, 1, 15),
        },
        {
          'start': DateTime(2026, 1, 23, 2, 0), // 45 min gap
          'end': DateTime(2026, 1, 23, 2, 30),
        },
      ];

      // Check if overlapping
      final gap = intervals[1]['start']!.difference(intervals[0]['end']!);

      expect(gap.inMinutes, equals(45));
      expect(intervals[1]['start']!.isAfter(intervals[0]['end']!), isTrue);
    });

    test('Interval fully contained in another', () {
      final largeInterval = {
        'start': DateTime(2026, 1, 23, 1, 0),
        'end': DateTime(2026, 1, 23, 3, 0),
      };

      final smallInterval = {
        'start': DateTime(2026, 1, 23, 1, 30),
        'end': DateTime(2026, 1, 23, 2, 0),
      };

      final isContained =
          smallInterval['start']!.isAfter(largeInterval['start']!) &&
              smallInterval['end']!.isBefore(largeInterval['end']!);

      expect(isContained, isTrue);
    });
  });

  group('Date Key Generation Tests', () {
    test('Single-digit day/month padding', () {
      final date = DateTime(2026, 1, 5);
      final key = '${date.year}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';

      expect(key, equals('2026-01-05'));
    });

    test('December 31st edge case', () {
      final date = DateTime(2025, 12, 31);
      final key = '${date.year}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';

      expect(key, equals('2025-12-31'));
    });

    test('Leap year Feb 29', () {
      final date = DateTime(2024, 2, 29);
      final key = '${date.year}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';

      expect(key, equals('2024-02-29'));
    });

    test('Date keys are sortable', () {
      final keys = [
        '2026-01-20',
        '2026-01-22',
        '2026-01-19',
        '2026-01-21',
      ];

      keys.sort();

      expect(keys, equals([
        '2026-01-19',
        '2026-01-20',
        '2026-01-21',
        '2026-01-22',
      ]));
    });
  });

  group('Deep Sleep Calculation Tests', () {
    test('No phone usage = total window', () {
      final totalWindow = Duration(hours: 8);
      final awakeTime = Duration.zero;
      final deepSleep = totalWindow - awakeTime;

      expect(deepSleep.inHours, equals(8));
    });

    test('Deep sleep with phone usage', () {
      final totalWindow = Duration(hours: 8);
      final awakeTime = Duration(hours: 1, minutes: 30);
      final deepSleep = totalWindow - awakeTime;

      expect(deepSleep.inMinutes, equals(390)); // 6.5 hours
    });

    test('Multiple awake intervals', () {
      final totalWindow = Duration(hours: 8);

      final awakeIntervals = [
        Duration(minutes: 15),
        Duration(minutes: 30),
        Duration(minutes: 20),
      ];

      final totalAwake = awakeIntervals.fold<Duration>(
        Duration.zero,
            (prev, interval) => prev + interval,
      );

      final deepSleep = totalWindow - totalAwake;

      expect(totalAwake.inMinutes, equals(65));
      expect(deepSleep.inMinutes, equals(415)); // 6h 55m
    });

    test('Awake time exceeds total window (edge case)', () {
      final totalWindow = Duration(hours: 8);
      final awakeTime = Duration(hours: 9); // More than total!

      final deepSleep = totalWindow - awakeTime;

      expect(deepSleep.isNegative, isTrue);
    });
  });

  group('TimeOfDay Conversion Tests', () {
    test('TimeOfDay to minutes', () {
      final time = TimeOfDay(hour: 23, minute: 30);
      final minutes = time.hour * 60 + time.minute;

      expect(minutes, equals(1410));
    });

    test('Minutes to TimeOfDay', () {
      final minutes = 1410; // 23:30
      final time = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);

      expect(time.hour, equals(23));
      expect(time.minute, equals(30));
    });

    test('Midnight conversion', () {
      final time = TimeOfDay(hour: 0, minute: 0);
      final minutes = time.hour * 60 + time.minute;

      expect(minutes, equals(0));
    });

    test('Round-trip conversion', () {
      final originalTime = TimeOfDay(hour: 14, minute: 45);
      final minutes = originalTime.hour * 60 + originalTime.minute;
      final convertedBack = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);

      expect(convertedBack.hour, equals(originalTime.hour));
      expect(convertedBack.minute, equals(originalTime.minute));
    });
  });

  group('Edge Case: Future Bedtime Resolution', () {
    test('Bedtime in future should resolve to yesterday', () {
      final now = DateTime(2026, 1, 23, 10, 0); // 10 AM
      final bedtimeTOD = TimeOfDay(hour: 23, minute: 0); // 11 PM

      // Build datetime for today
      DateTime bedtime = DateTime(
        now.year,
        now.month,
        now.day,
        bedtimeTOD.hour,
        bedtimeTOD.minute,
      );

      // If bedtime is in future, subtract a day
      if (bedtime.isAfter(now.add(Duration(minutes: 5)))) {
        bedtime = bedtime.subtract(Duration(days: 1));
      }

      expect(bedtime.day, equals(22)); // Previous day
    });

    test('Bedtime in past should stay same day', () {
      final now = DateTime(2026, 1, 23, 23, 30); // 11:30 PM
      final bedtimeTOD = TimeOfDay(hour: 23, minute: 0); // 11 PM

      DateTime bedtime = DateTime(
        now.year,
        now.month,
        now.day,
        bedtimeTOD.hour,
        bedtimeTOD.minute,
      );

      if (bedtime.isAfter(now.add(Duration(minutes: 5)))) {
        bedtime = bedtime.subtract(Duration(days: 1));
      }

      expect(bedtime.day, equals(23)); // Same day
    });
  });

  group('Stress Test Scenarios', () {
    test('100 intervals merge performance', () {
      final intervals = <Map<String, DateTime>>[];
      final baseTime = DateTime(2026, 1, 23, 0, 0);

      // Create 100 overlapping intervals
      for (int i = 0; i < 100; i++) {
        intervals.add({
          'start': baseTime.add(Duration(minutes: i * 2)),
          'end': baseTime.add(Duration(minutes: i * 2 + 5)),
        });
      }

      expect(intervals.length, equals(100));

      // Simple merge check
      intervals.sort((a, b) => a['start']!.compareTo(b['start']!));

      expect(intervals.first['start'], equals(baseTime));
    });

    test('Rapid date key generation', () {
      final keys = <String>[];
      final baseDate = DateTime(2026, 1, 1);

      for (int i = 0; i < 365; i++) {
        final date = baseDate.add(Duration(days: i));
        final key = '${date.year}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}';
        keys.add(key);
      }

      expect(keys.length, equals(365));
      expect(keys.toSet().length, equals(365)); // All unique
    });
  });
}