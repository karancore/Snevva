import 'package:alarm/model/alarm_settings.dart';

import '../common/global_variables.dart';

class WaterReminderModel {
  final int id; // Unique identifier for this water reminder group
  final String title;
  final String category;
  final Option type; // ✅ discriminator
  final List<AlarmSettings> alarms;
  final String? notes;
  final String timesPerDay;
  final String waterReminderStartTime;
  final String waterReminderEndTime;

  final String? interval;

  WaterReminderModel({
    required this.id,
    required this.title,
    required this.category,
    required this.type,
    required this.alarms,
    required this.timesPerDay,
    required this.waterReminderStartTime,
    required this.waterReminderEndTime,
    this.interval,
    this.notes,
  }) : assert(
         (type == Option.times && interval == null) ||
             (type == Option.interval && interval != null),
         'Invalid WaterReminderModel state',
       );

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'Category': category,
      'type': type.name, // ✅ JSON-safe
      'alarms': alarms.map((a) => a.toJson()).toList(),
      'timesPerDay': timesPerDay,
      'waterReminderStartTime': waterReminderStartTime,
      'waterReminderEndTime': waterReminderEndTime,
      'notes': notes,
      'interval': interval,
    };
  }

  factory WaterReminderModel.fromJson(Map<String, dynamic> json) {
    final type = Option.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => Option.times,
    );

    return WaterReminderModel(
      id: json['id'],
      title: json['title'],
      category: json['Category'],
      type: type,
      notes: json['notes'],
      alarms:
          (json['alarms'] as List)
              .map((a) => AlarmSettings.fromJson(a))
              .toList(),
      timesPerDay: json['timesPerDay'],
      waterReminderStartTime: json['waterReminderStartTime'],
      waterReminderEndTime: json['waterReminderEndTime'],
      interval: json['interval'],
    );
  }
}
