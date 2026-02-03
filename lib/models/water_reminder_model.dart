import 'package:alarm/model/alarm_settings.dart';

class WaterReminderModel {
  final int id; // Unique identifier for this water reminder group
  final String title;
  final String category;
  final List<AlarmSettings> alarms;
  final String timesPerDay;
  final String? interval;

  WaterReminderModel({
    required this.id,
    required this.title,
    required this.category,
    required this.alarms,
    required this.timesPerDay,
    this.interval,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      "Category": category,
      'alarms': alarms.map((a) => a.toJson()).toList(),
      'timesPerDay': timesPerDay,
      'interval': interval,
    };
  }

  factory WaterReminderModel.fromJson(Map<String, dynamic> json) {
    return WaterReminderModel(
      id: json['id'],
      title: json['title'],
      category: json["Category"],
      alarms:
          (json['alarms'] as List)
              .map((a) => AlarmSettings.fromJson(a))
              .toList(),
      timesPerDay: json['timesPerDay'],
      interval: json['interval'],
    );
  }
}
