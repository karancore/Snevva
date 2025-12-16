import 'package:alarm/model/alarm_settings.dart';

class MedicineReminderModel {
  final String title;
  final List<String> medicines;
  final AlarmSettings alarm;

  MedicineReminderModel({
    required this.title,
    required this.medicines,
    required this.alarm,
  });

  // Convert to JSON for SharedPreferences
  Map<String, dynamic> toJson() => {
    'title': title,
    'medicines': medicines,
    'alarm': alarm.toJson(),
  };

  // Load JSON back into model
  factory MedicineReminderModel.fromJson(Map<String, dynamic> json) {
    return MedicineReminderModel(
      title: json['title'],
      medicines: List<String>.from(json['medicines']),
      alarm: AlarmSettings.fromJson(json['alarm']),
    );
  }
}
