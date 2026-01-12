import 'package:alarm/model/alarm_settings.dart';
import 'package:flutter/material.dart';

class MedicineReminderModel {
  final String title;
  final String note;
  final List<MedicineItem> medicines;
  final AlarmSettings alarm;

  MedicineReminderModel({
    required this.title,
    required this.note,
    required this.medicines,
    required this.alarm,
  });

  // Convert to JSON for SharedPreferences
  Map<String, dynamic> toJson() => {
    'title': title,
    'medicines': medicines.map((e) => e.toJson()).toList(),
    'note': note,
    'alarm': alarm.toJson(),
  };

  // Load JSON back into model
  factory MedicineReminderModel.fromJson(Map<String, dynamic> json) {
    return MedicineReminderModel(
      title: json['title'],
      note: json['note'],
      medicines: (json['medicines'] as List)
          .map((e) => MedicineItem.fromJson(e))
          .toList(),
      alarm: AlarmSettings.fromJson(json['alarm']),
    );
  }
}
class MedicineItem {
  String name;
  List<MedicineTime> times;

  MedicineItem({
    required this.name,
    required this.times,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'times': times.map((e) => e.toJson()).toList(),
  };

  factory MedicineItem.fromJson(Map<String, dynamic> json) {
    return MedicineItem(
      name: json['name'],
      times: (json['times'] as List)
          .map((e) => MedicineTime.fromJson(e))
          .toList(),
    );
  }
}
class MedicineTime {
  final TimeOfDay time;

  MedicineTime({required this.time});

  Map<String, dynamic> toJson() => {
    'hour': time.hour,
    'minute': time.minute,
  };

  factory MedicineTime.fromJson(Map<String, dynamic> json) {
    return MedicineTime(
      time: TimeOfDay(hour: json['hour'], minute: json['minute']),
    );
  }
}
