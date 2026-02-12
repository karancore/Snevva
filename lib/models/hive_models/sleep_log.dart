import 'package:hive/hive.dart';

@HiveType(typeId: 4)
class SleepLog extends HiveObject {
  @HiveField(0)
  DateTime date; // The date of the sleep log (usually the wake-up day)

  @HiveField(1)
  int durationMinutes; // Total deep sleep duration in minutes

  @HiveField(2)
  DateTime? startTime; // When sleep started

  @HiveField(3)
  DateTime? endTime; // When sleep ended

  @HiveField(4)
  int? goalMinutes; // Sleep goal in minutes

  SleepLog({
    required this.date,
    required this.durationMinutes,
    this.startTime,
    this.endTime,
    this.goalMinutes,
  });
}
