import 'package:hive/hive.dart';

part 'reminder_payload_model.g.dart';

@HiveType(typeId: 10)
class ReminderPayloadModel extends HiveObject{

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final String category;

  @HiveField(4)
  final List<String> medicineNames;

  @HiveField(5)
  final int startDay;

  @HiveField(6)
  final int startMonth;

  @HiveField(7)
  final int startYear;

  @HiveField(8)
  final List<String> remindTimes;

  @HiveField(9)
  final int remindFrequencyHour;

  @HiveField(10)
  final int remindFrequencyCount;

  @HiveField(11)
  final bool isActive;

  ReminderPayloadModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.medicineNames,
    required this.startDay,
    required this.startMonth,
    required this.startYear,
    required this.remindTimes,
    required this.remindFrequencyHour,
    required this.remindFrequencyCount,
    required this.isActive,
  });
}
