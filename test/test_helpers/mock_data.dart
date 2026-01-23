import 'package:flutter/material.dart';
import 'package:snevva/models/hive_models/sleep_log.dart';
import 'package:snevva/models/awake_interval.dart';

class MockSleepData {
  static DateTime get today => DateTime(2026, 1, 22);

  static DateTime get yesterday => today.subtract(Duration(days: 1));

  static TimeOfDay get standardBedtime => TimeOfDay(hour: 23, minute: 0);

  static TimeOfDay get standardWaketime => TimeOfDay(hour: 7, minute: 0);

  static SleepLog createSleepLog({
    required DateTime date,
    int durationMinutes = 420, // 7 hours default
  }) {
    return SleepLog(
      date: DateTime(date.year, date.month, date.day),
      durationMinutes: durationMinutes,
    );
  }

  static List<SleepLog> createWeekOfSleep() {
    final today = DateTime.now();
    final weekStart = today.subtract(Duration(days: today.weekday - 1));

    return List.generate(7, (index) {
      final date = weekStart.add(Duration(days: index));
      return createSleepLog(
        date: date,
        durationMinutes: 400 + (index * 10), // Varying durations
      );
    });
  }

  static List<AwakeInterval> createPhoneUsageIntervals() {
    final baseTime = DateTime(2026, 1, 23, 1, 0);

    return [
      AwakeInterval(
        baseTime,
        baseTime.add(Duration(minutes: 15)),
      ),
      AwakeInterval(
        baseTime.add(Duration(hours: 2)),
        baseTime.add(Duration(hours: 2, minutes: 30)),
      ),
    ];
  }

  static Map<String, dynamic> createApiSleepResponse() {
    return {
      "data": {
        "SleepData": [
          {
            "Day": 22,
            "Month": 1,
            "Year": 2026,
            "SleepingFrom": "23:00",
            "SleepingTo": "07:00",
          },
          {
            "Day": 21,
            "Month": 1,
            "Year": 2026,
            "SleepingFrom": "23:30",
            "SleepingTo": "07:30",
          },
        ],
      },
    };
  }
}