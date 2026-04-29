import 'dart:convert';

import 'package:snevva/models/hive_models/reminder_payload_model.dart';
import 'package:snevva/models/reminder_schedule_metadata.dart';

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
  final ReminderScheduleMetadata scheduleMetadata;
  final DateTime? updatedAt;

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
    this.updatedAt,
    this.scheduleMetadata = const ReminderScheduleMetadata(
      timezoneId: 'UTC',
      scheduleSemantics: ScheduleSemantics.wallClock,
    ),
  });

  factory MedicineReminderModel.fromJson(Map<String, dynamic> json) {
    final customReminderRaw = json['customReminder'] ?? json['CustomReminder'];
    final dosageRaw = json['dosage'] ?? json['Dosage'];
    final remindBeforeRaw = json['remindBefore'] ?? json['RemindBefore'];

    return MedicineReminderModel(
      id: _readInt(json, const ['id', 'Id']),
      updatedAt: _tryParseDateTime(
        json['updatedAt'] ?? json['UpdatedAt'],
      ),
      alarmIds: _parseAlarmIds(json['alarmIds'] ?? json['AlarmIds']),
      title: (json['title'] ?? json['Title'] ?? '').toString(),
      category: (json['category'] ?? json['Category'] ?? '').toString(),
      whenToTake: (json['whenToTake'] ?? json['WhenToTake'] ?? '').toString(),
      medicineName:
          (json['medicineName'] ?? json['MedicineName'] ?? '').toString(),
      medicineType:
          (json['medicineType'] ?? json['MedicineType'] ?? '').toString(),
      dosage:
          dosageRaw is Map
              ? Dosage.fromJson(Map<String, dynamic>.from(dosageRaw as Map))
              : Dosage(value: 0, unit: ''),
      medicineFrequencyPerDay:
          (json['medicineFrequencyPerDay'] ??
                  json['MedicineFrequencyPerDay'] ??
                  '')
              .toString(),
      reminderFrequencyType:
          (json['reminderFrequencyType'] ??
                  json['ReminderFrequencyType'] ??
                  '')
              .toString(),
      customReminder:
          customReminderRaw is Map
              ? CustomReminder.fromJson(
                Map<String, dynamic>.from(customReminderRaw as Map),
              )
              : CustomReminder.fromJson(const {}),
      remindBefore:
          remindBeforeRaw == null
              ? null
              : RemindBefore.fromJson(
                Map<String, dynamic>.from(remindBeforeRaw as Map),
              ),
      startDate: (json['startDate'] ?? json['StartDate'] ?? '').toString(),
      endDate: (json['endDate'] ?? json['EndDate'] ?? '').toString(),
      notes: (json['notes'] ?? json['Notes'] ?? '').toString(),
      scheduleMetadata: ReminderScheduleMetadata.fromJson(
        json['scheduleMetadata'] is Map
            ? Map<String, dynamic>.from(json['scheduleMetadata'] as Map)
            : json['ScheduleMetadata'] is Map
            ? Map<String, dynamic>.from(json['ScheduleMetadata'] as Map)
            : null,
        timezoneIdFallback: 'UTC',
        semanticsFallback: ReminderPayloadModel.defaultSemanticsForCategory(
          (json['category'] ?? json['Category'] ?? '').toString(),
          isSingleInstance:
              ((((json['customReminder'] ?? json['CustomReminder'])
                                  ?['timesPerDay'] ??
                              (json['customReminder'] ?? json['CustomReminder'])
                                  ?['TimesPerDay'])
                          ?['count'] ??
                      (((json['customReminder'] ?? json['CustomReminder'])
                                  ?['timesPerDay'] ??
                              (json['customReminder'] ?? json['CustomReminder'])
                                  ?['TimesPerDay'])
                          ?['Count']) ??
                      '0')
                          .toString() ==
                      '1') ||
                  (((((json['customReminder'] ?? json['CustomReminder'])
                                      ?['timesPerDay'] ??
                                  (json['customReminder'] ??
                                      json['CustomReminder'])?['TimesPerDay'])
                              ?['list'] as List?) ??
                          (((json['customReminder'] ?? json['CustomReminder'])
                                      ?['timesPerDay'] ??
                                  (json['customReminder'] ??
                                      json['CustomReminder'])?['TimesPerDay'])
                              ?['List'] as List?))
                              ?.length ??
                          0) <=
                      1,
        ),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> data = {
      'id': id,
      'updatedAt': updatedAt?.toIso8601String(),
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
      'scheduleMetadata': scheduleMetadata.toJson(),
    };

    if (remindBefore != null) {
      data['remindBefore'] = remindBefore!.toJson();
    }

    return data;
  }
}

int _readInt(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is int) return value;
    if (value == null) continue;
    final parsed = int.tryParse(value.toString());
    if (parsed != null) return parsed;
  }
  return 0;
}

DateTime? _tryParseDateTime(dynamic raw) {
  if (raw == null) return null;
  return DateTime.tryParse(raw.toString());
}

List<int> _parseAlarmIds(dynamic raw) {
  if (raw is! List) return const <int>[];

  final ids = <int>[];
  for (final item in raw) {
    if (item is int) {
      ids.add(item);
      continue;
    }
    final parsed = int.tryParse(item.toString());
    if (parsed != null) {
      ids.add(parsed);
    }
  }
  return ids;
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
    final typeStr = (json['type'] ?? json['Type'] ?? '').toString();
    final type = Option.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => Option.times,
    );
    if (type == Option.times) {
      return CustomReminder(
        type: type,
        timesPerDay: TimesPerDay.fromJson(
          json['timesPerDay'] ?? json['TimesPerDay'] ?? {},
        ),
      );
    } else {
      return CustomReminder(
        type: type,
        everyXHours: EveryXHours.fromJson(
          json['everyXHours'] ?? json['EveryXHours'] ?? {},
        ),
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
      count: (json['count'] ?? json['Count'] ?? 0).toString(),
      list: List<String>.from(json['list'] ?? json['List'] ?? []),
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
      hours: (json['hours'] ?? json['Hours'] ?? 0).toString(),
      startTime: (json['startTime'] ?? json['StartTime'] ?? '').toString(),
      endTime: (json['endTime'] ?? json['EndTime'] ?? '').toString(),
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
