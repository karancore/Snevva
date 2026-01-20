import 'package:hive/hive.dart';

part 'sleep_log.g.dart';

@HiveType(typeId: 4)
class SleepLog extends HiveObject {
  @HiveField(0)
  DateTime date; // The date of the sleep log (usually the wake-up day)

  @HiveField(1)
  int durationMinutes; // Total deep sleep duration in minutes

  SleepLog({required this.date, required this.durationMinutes});
}
