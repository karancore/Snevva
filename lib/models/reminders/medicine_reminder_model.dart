import 'dart:convert';

import 'package:snevva/models/hive_models/reminder_payload_model.dart';

import '../../common/global_variables.dart';

class MedicineReminderModel {
  final int id;
  final List<int> alarmIds;
  final String title;
  final String category;
  final String medicineName;
  final String medicineType;
  final String whenToTake;
  final Dosage dosage;
  final String medicineFrequencyPerDay;
  final String reminderFrequencyType;
  final CustomReminder customReminder;
  final RemindBefore? remindBefore;
  final String startDate;
  final String endDate;
  final String notes;

  MedicineReminderModel({
    required this.id,
    this.alarmIds = const [],
    required this.title,
    required this.category,
    required this.medicineName,
    required this.medicineType,
    required this.dosage,
    required this.medicineFrequencyPerDay,
    required this.reminderFrequencyType,
    required this.customReminder,
    this.remindBefore,
    required this.startDate,
    required this.endDate,
    required this.notes,
    required this.whenToTake,
  });

  factory MedicineReminderModel.fromJson(Map<String, dynamic> json) {
    return MedicineReminderModel(
      id: json['id'] ?? 0,
      alarmIds:
          (json['alarmIds'] as List?)?.map((e) => e as int).toList() ??
          const [],
      title: json['title'] ?? '',
      category: json['category'] ?? '',
      whenToTake: json['whenToTake'] ?? '',
      medicineName: json['medicineName'] ?? '',
      medicineType: json['medicineType'] ?? '',
      dosage: Dosage.fromJson(json['dosage'] ?? {}),
      medicineFrequencyPerDay: json['medicineFrequencyPerDay'] ?? '',
      reminderFrequencyType: json['reminderFrequencyType'] ?? '',
      customReminder: CustomReminder.fromJson(json['customReminder'] ?? {}),
      remindBefore:
          json['remindBefore'] == null
              ? null
              : RemindBefore.fromJson(json['remindBefore']),
      startDate: json['startDate'] ?? '',
      endDate: json['endDate'] ?? '',
      notes: json['notes'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> data = {
      'id': id,
      'alarmIds': alarmIds,
      'title': title,
      'category': category,
      'medicineName': medicineName,
      'medicineType': medicineType,
      'whenToTake': whenToTake,
      'dosage': dosage.toJson(),
      'medicineFrequencyPerDay': medicineFrequencyPerDay,
      'reminderFrequencyType': reminderFrequencyType,
      'customReminder': customReminder.toJson(),
      'startDate': startDate,
      'endDate': endDate,
      'notes': notes,
    };

    if (remindBefore != null) {
      data['remindBefore'] = remindBefore!.toJson();
    }

    return data;
  }
}

class Dosage {
  final num value;
  final String unit;

  Dosage({required this.value, required this.unit});

  factory Dosage.fromJson(Map<String, dynamic> json) {
    return Dosage(value: json['value'] ?? 0, unit: json['unit'] ?? '');
  }

  Map<String, dynamic> toJson() {
    return {'value': value, 'unit': unit};
  }
}

class CustomReminder {
  final Option type;
  final TimesPerDay? timesPerDay;
  final EveryXHours? everyXHours;

  CustomReminder({required this.type, this.timesPerDay, this.everyXHours})
    : assert(
        (type == Option.times && timesPerDay != null && everyXHours == null) ||
            (type == Option.interval &&
                everyXHours != null &&
                timesPerDay == null),
        'Invalid CustomRemainder state',
      );

  factory CustomReminder.fromJson(Map<String, dynamic> json) {
    final type = Option.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => Option.times,
    );
    if (type == Option.times) {
      return CustomReminder(
        type: type,
        timesPerDay: TimesPerDay.fromJson(json['timesPerDay'] ?? {}),
      );
    } else {
      return CustomReminder(
        type: type,
        everyXHours: EveryXHours.fromJson(json['everyXHours'] ?? {}),
      );
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {'type': type.name};
    if (timesPerDay != null) {
      data['timesPerDay'] = timesPerDay!.toJson();
    }
    if (everyXHours != null) {
      data['everyXHours'] = everyXHours!.toJson();
    }
    return data;
  }
}

class TimesPerDay {
  final String count;
  final List<String> list;

  TimesPerDay({required this.count, required this.list});

  factory TimesPerDay.fromJson(Map<String, dynamic> json) {
    return TimesPerDay(
      count: json['count'] ?? 0,
      list: List<String>.from(json['list'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {'count': count, 'list': list};
  }
}

class EveryXHours {
  final String hours;
  final String startTime;
  final String endTime;

  EveryXHours({
    required this.hours,
    required this.startTime,
    required this.endTime,
  });

  factory EveryXHours.fromJson(Map<String, dynamic> json) {
    return EveryXHours(
      hours: json['hours'] ?? 0,
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'hours': hours, 'startTime': startTime, 'endTime': endTime};
  }
}

class RemindBefore {
  final int time;
  final String unit;

  RemindBefore({required this.time, required this.unit});

  factory RemindBefore.fromJson(Map<String, dynamic> json) {
    return RemindBefore(time: json['time'] ?? 0, unit: json['unit'] ?? '');
  }

  Map<String, dynamic> toJson() {
    return {'time': time, 'unit': unit};
  }
}

String reminderToString(MedicineReminderModel model) {
  return jsonEncode(model.toJson());
}

extension ReminderPayLoadValidation on ReminderPayloadModel {
  void validate() {
    switch (category.toLowerCase()) {
      case 'medicine':
        _validateMedicine();
        break;

      case 'water':
        _validateWater();
        break;

      case 'meal':
        _validateMeal();
        break;

      case 'event':
        _validateEvent();
        break;
    }
  }

  void _validateMedicine() {
    if (medicineName == null || medicineName!.trim().isEmpty) {
      throw Exception('Medicine reminder $id missing medicineName');
    }

    if (medicineType == null) {
      throw Exception('Medicine reminder $id missing medicineType');
    }

    if (whenToTake == null) {
      throw Exception('Medicine reminder $id missing whenToTake');
    }

    if (dosage == null) {
      throw Exception('Medicine reminder $id missing dosage');
    }

    final times = customReminder.timesPerDay?.list;
    if (times == null || times.isEmpty) {
      throw Exception('Medicine reminder $id has no scheduled times');
    }
  }

  void _validateWater() {
    if (customReminder.timesPerDay == null &&
        customReminder.everyXHours == null) {
      throw Exception('Water reminder $id has no frequency');
    }

    if (customReminder.timesPerDay != null) {
      if (startWaterTime == null || endWaterTime == null) {
        throw Exception('Water reminder $id missing start/end time');
      }
    }
  }

  void _validateEvent() {
    final times = customReminder.timesPerDay?.list;
    if (times == null || times.isEmpty) {
      throw Exception('Event reminder $id has no time');
    }
  }

  void _validateMeal() {
    final times = customReminder.timesPerDay?.list;
    if (times == null || times.isEmpty) {
      throw Exception('Meal reminder $id has no time');
    }
  }
}
