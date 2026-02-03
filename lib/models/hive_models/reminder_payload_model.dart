import 'package:hive/hive.dart';

part 'reminder_payload_model.g.dart';

@HiveType(typeId: 20)
class ReminderPayloadModel {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String category; // permanent

  @HiveField(3)
  final String? medicineName;

  @HiveField(4)
  final String? medicineType;

  @HiveField(5)
  final Dosage? dosage;

  @HiveField(6)
  final String? medicineFrequencyPerDay;

  @HiveField(7)
  final String? reminderFrequencyType;

  @HiveField(8)
  final CustomReminder customReminder;

  @HiveField(9)
  final RemindBefore? remindBefore;

  @HiveField(10)
  final String? startDate;

  @HiveField(11)
  final String? endDate;

  @HiveField(12)
  final String? notes;

  const ReminderPayloadModel({
    required this.id,
    required this.title,
    required this.category,
    this.medicineName,
    this.medicineType,
    this.dosage,
    this.medicineFrequencyPerDay,
    this.reminderFrequencyType,
    required this.customReminder,
    this.remindBefore,
    this.startDate,
    this.endDate,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'medicineName': medicineName,
      'medicineType': medicineType,
      'dosage': dosage?.toJson(),
      'medicineFrequencyPerDay': medicineFrequencyPerDay,
      'reminderFrequencyType': reminderFrequencyType,
      'customReminder': customReminder?.toJson(),
      'remindBefore': remindBefore?.toJson(),
      'startDate': startDate,
      'endDate': endDate,
      'notes': notes,
    };
  }

  factory ReminderPayloadModel.fromJson(Map<String, dynamic> json) {
    return ReminderPayloadModel(
      id: json['id'],
      title: json['title'],
      category: json['category'],
      medicineName: json['medicineName'],
      medicineType: json['medicineType'],
      dosage: json['dosage'] != null ? Dosage.fromJson(json['dosage']) : null,
      medicineFrequencyPerDay: json['medicineFrequencyPerDay'],
      reminderFrequencyType: json['reminderFrequencyType'],
      customReminder: CustomReminder.fromJson(json['customReminder']),
      remindBefore: json['remindBefore'] != null
          ? RemindBefore.fromJson(json['remindBefore'])
          : null,
      startDate: json['startDate'],
      endDate: json['endDate'],
      notes: json['notes'],
    );
  }
}

@HiveType(typeId: 21)
class Dosage {
  @HiveField(0)
  final int value;

  @HiveField(1)
  final String unit;

  const Dosage({
    required this.value,
    required this.unit,
  });

  Map<String, dynamic> toJson() => {
    'value': value,
    'unit': unit,
  };

  factory Dosage.fromJson(Map<String, dynamic> json) => Dosage(
    value: json['value'],
    unit: json['unit'],
  );
}

@HiveType(typeId: 22)
class CustomReminder {
  @HiveField(0)
  final TimesPerDay? timesPerDay;

  @HiveField(1)
  final EveryXHours? everyXHours;

  const CustomReminder({
    this.timesPerDay,
    this.everyXHours,
  });

  Map<String, dynamic> toJson() => {
    'timesPerDay': timesPerDay?.toJson(),
    'everyXHours': everyXHours?.toJson(),
  };

  factory CustomReminder.fromJson(Map<String, dynamic> json) => CustomReminder(
    timesPerDay: json['timesPerDay'] != null
        ? TimesPerDay.fromJson(json['timesPerDay'])
        : null,
    everyXHours: json['everyXHours'] != null
        ? EveryXHours.fromJson(json['everyXHours'])
        : null,
  );
}

@HiveType(typeId: 23)
class TimesPerDay {
  @HiveField(0)
  final String count;

  @HiveField(1)
  final List<String> list;

  const TimesPerDay({
    required this.count,
    required this.list,
  });

  Map<String, dynamic> toJson() => {
    'count': count,
    'list': list,
  };

  factory TimesPerDay.fromJson(Map<String, dynamic> json) => TimesPerDay(
    count: json['count'],
    list: List<String>.from(json['list'] ?? []),
  );
}

@HiveType(typeId: 24)
class EveryXHours {
  @HiveField(0)
  final int hours;

  @HiveField(1)
  final String startTime;

  @HiveField(2)
  final String endTime;

  const EveryXHours({
    required this.hours,
    required this.startTime,
    required this.endTime,
  });

  Map<String, dynamic> toJson() => {
    'hours': hours,
    'startTime': startTime,
    'endTime': endTime,
  };

  factory EveryXHours.fromJson(Map<String, dynamic> json) => EveryXHours(
    hours: json['hours'],
    startTime: json['startTime'],
    endTime: json['endTime'],
  );
}

@HiveType(typeId: 25)
class RemindBefore {
  @HiveField(0)
  final int time;

  @HiveField(1)
  final String unit;

  const RemindBefore({
    required this.time,
    required this.unit,
  });

  Map<String, dynamic> toJson() => {
    'time': time,
    'unit': unit,
  };

  factory RemindBefore.fromJson(Map<String, dynamic> json) => RemindBefore(
    time: json['time'],
    unit: json['unit'],
  );
}