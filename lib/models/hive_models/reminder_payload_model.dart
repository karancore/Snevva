import 'package:hive/hive.dart';

import '../../common/global_variables.dart';

part 'reminder_payload_model.g.dart';

String safeString(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;

  final normalized = value.toString().trim();
  return normalized.isEmpty ? fallback : normalized;
}

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

  @HiveField(13)
  final String? whenToTake;

  @HiveField(14)
  final String? startWaterTime;

  @HiveField(15)
  final String? endWaterTime;

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
    this.whenToTake,
    this.startWaterTime,
    this.endWaterTime,
  });

  static String _normalizeCategoryForApi(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) return normalized;
    switch (normalized.toLowerCase()) {
      case 'medicine':
        return 'Medicine';
      case 'water':
        return 'Water';
      case 'meal':
        return 'Meal';
      case 'event':
        return 'Event';
      default:
        return normalized;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Title': title,
      'Category': _normalizeCategoryForApi(category),
      'MedicineName': medicineName,
      'MedicineType': medicineType,
      'Dosage': dosage?.toJson(),
      'MedicineFrequencyPerDay': medicineFrequencyPerDay,
      'ReminderFrequencyType': reminderFrequencyType,
      'CustomReminder': customReminder.toJson(),
      'RemindBefore': remindBefore?.toJson(),
      'StartDate': startDate,
      'EndDate': endDate,
      'Notes': notes,
      'WhenToTake': whenToTake,
      'StartWaterTime': startWaterTime,
      'EndWaterTime': endWaterTime,
    };
  }

  factory ReminderPayloadModel.fromJson(Map<String, dynamic> json) {
    final custom =
        json['CustomReminder'] != null
            ? CustomReminder.fromJson(json['CustomReminder'])
            : const CustomReminder();

    final interval = custom.everyXHours;
    final startWaterTime = json['StartWaterTime'] ?? interval?.startTime;
    final endWaterTime = json['EndWaterTime'] ?? interval?.endTime;

    return ReminderPayloadModel(
      id: json['Id'] ?? 0,
      title: json['Title'] ?? '',
      category: json['Category'] ?? '',
      medicineName: json['MedicineName'],
      medicineType: json['MedicineType'],
      dosage: json['Dosage'] != null ? Dosage.fromJson(json['Dosage']) : null,
      whenToTake: json['WhenToTake'],
      medicineFrequencyPerDay: json['MedicineFrequencyPerDay'],
      reminderFrequencyType: json['ReminderFrequencyType'],
      customReminder: custom,
      remindBefore:
          json['RemindBefore'] != null
              ? RemindBefore.fromJson(json['RemindBefore'])
              : null,
      startDate: json['StartDate'],
      endDate: json['EndDate'],
      notes: json['Notes'],
      startWaterTime: startWaterTime,
      endWaterTime: endWaterTime,
    );
  }
  @override
  String toString() {
    final buffer = StringBuffer();

    buffer.writeln('🔔 ReminderPayloadModel');
    buffer.writeln('id: $id');
    buffer.writeln('title: $title');
    buffer.writeln('category: $category');

    // -------- Medicine --------
    if (category == "medicine") {
      buffer.writeln('--- Medicine Info ---');
      buffer.writeln('medicineName: $medicineName');
      buffer.writeln('medicineType: $medicineType');
      buffer.writeln('dosage: ${dosage?.value} ${dosage?.unit}');
      buffer.writeln('whenToTake: $whenToTake');
      buffer.writeln('frequency: $medicineFrequencyPerDay');
    }

    // -------- Water --------
    if (category == "water") {
      buffer.writeln('--- Water Info ---');
      buffer.writeln('startWaterTime: $startWaterTime');
      buffer.writeln('endWaterTime: $endWaterTime');
    }

    // -------- Common Reminder --------
    buffer.writeln('--- Reminder Timing ---');
    buffer.writeln('reminderType: ${customReminder.type}');

    if (customReminder.timesPerDay != null) {
      buffer.writeln('timesPerDay count: ${customReminder.timesPerDay!.count}');
      buffer.writeln('times: ${customReminder.timesPerDay!.list}');
    }

    if (customReminder.everyXHours != null) {
      buffer.writeln('intervalHours: ${customReminder.everyXHours!.hours}');
      buffer.writeln('intervalStart: ${customReminder.everyXHours!.startTime}');
      buffer.writeln('intervalEnd: ${customReminder.everyXHours!.endTime}');
    }

    if (remindBefore != null) {
      buffer.writeln(
        'remindBefore: ${remindBefore!.time} ${remindBefore!.unit}',
      );
    }

    buffer.writeln('startDate: $startDate');
    buffer.writeln('endDate: $endDate');
    buffer.writeln('notes: $notes');

    return buffer.toString();
  }
}

@HiveType(typeId: 21)
class Dosage {
  @HiveField(0)
  final num value;

  @HiveField(1)
  final String unit;

  const Dosage({required this.value, required this.unit});

  Map<String, dynamic> toJson() => {'Value': value, 'Unit': unit};

  factory Dosage.fromJson(Map<String, dynamic> json) =>
      Dosage(value: json['Value'], unit: json['Unit']);
}

@HiveType(typeId: 22)
class CustomReminder {
  @HiveField(0)
  final Option? type;

  @HiveField(1)
  final TimesPerDay? timesPerDay;

  @HiveField(2)
  final EveryXHours? everyXHours;

  const CustomReminder({this.type, this.timesPerDay, this.everyXHours});

  factory CustomReminder.fromJson(Map<String, dynamic> json) {
    final rawType = json['Type'];
    final type =
        Option.values.cast<Option?>().firstWhere(
          (e) => e?.name == rawType,
          orElse:
              () =>
                  json['EveryXHours'] != null ? Option.interval : Option.times,
        ) ??
        Option.times;

    switch (type) {
      case Option.times:
        return CustomReminder(
          type: type,
          timesPerDay: TimesPerDay.fromJson(json['TimesPerDay'] ?? {}),
        );
      case Option.interval:
        return CustomReminder(
          type: type,
          everyXHours: EveryXHours.fromJson(json['EveryXHours'] ?? {}),
        );
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {'Type': type?.name};

    if (timesPerDay != null) {
      data['TimesPerDay'] = timesPerDay!.toJson();
    }

    if (everyXHours != null) {
      data['EveryXHours'] = everyXHours!.toJson();
    }

    return data;
  }
}

@HiveType(typeId: 23)
class TimesPerDay {
  @HiveField(0)
  final String count;

  @HiveField(1)
  final List<String> list;

  const TimesPerDay({required this.count, required this.list});

  Map<String, dynamic> toJson() => {'Count': count.toString(), 'List': list};

  factory TimesPerDay.fromJson(Map<String, dynamic> json) => TimesPerDay(
    count: (json['Count'] ?? '').toString(),
    list: List<String>.from(json['List'] ?? []),
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
    'Hours': hours,
    'StartTime': startTime,
    'EndTime': endTime,
  };

  factory EveryXHours.fromJson(Map<String, dynamic> json) => EveryXHours(
    hours: json['Hours'],
    startTime: json['StartTime'],
    endTime: json['EndTime'],
  );
}

@HiveType(typeId: 25)
class RemindBefore {
  @HiveField(0)
  final int time;

  @HiveField(1)
  final String unit;

  const RemindBefore({required this.time, required this.unit});

  Map<String, dynamic> toJson() => {'Time': time, 'Unit': unit};

  factory RemindBefore.fromJson(Map<String, dynamic> json) =>
      RemindBefore(time: json['Time'], unit: json['Unit']);
}

extension ReminderPayloadSafeAccess on ReminderPayloadModel {
  // ---------------- MEDICINE ----------------

  String get medicineNameSafe {
    _ensure('medicine');
    return medicineName!;
  }

  String get medicineTypeSafe {
    _ensure('medicine');
    return medicineType!;
  }

  String get whenToTakeSafe {
    _ensure('medicine');
    return whenToTake!;
  }

  Dosage get dosageSafe {
    _ensure('medicine');
    return dosage!;
  }

  List<String> get medicineTimesSafe {
    _ensure('medicine');
    return customReminder.timesPerDay!.list;
  }

  // ---------------- WATER ----------------

  String get waterStartSafe {
    _ensure('water');
    final start =
        (startWaterTime ?? customReminder.everyXHours?.startTime)?.trim();
    if (start == null || start.isEmpty) {
      throw Exception("Water reminder $id missing startWaterTime");
    }
    return start;
  }

  String get waterEndSafe {
    _ensure('water');
    final end = (endWaterTime ?? customReminder.everyXHours?.endTime)?.trim();
    if (end == null || end.isEmpty) {
      throw Exception("Water reminder $id missing endWaterTime");
    }
    return end;
  }

  int get waterTimesCountSafe {
    _ensure('water');
    final rawCount = customReminder.timesPerDay?.count;
    if (rawCount == null || rawCount.toString().trim().isEmpty) {
      throw Exception("Water reminder $id missing timesPerDay count");
    }
    return int.parse(rawCount.toString());
  }

  // ---------------- EVENT / MEAL ----------------

  List<String> get timesSafe {
    final list = customReminder.timesPerDay?.list;
    if (list == null || list.isEmpty) {
      throw Exception("Reminder $id has no times");
    }
    return list;
  }

  // ---------------- INTERNAL ----------------

  void _ensure(String expectedCategory) {
    if (category.toLowerCase() != expectedCategory) {
      throw Exception(
        "Tried to access $expectedCategory field on $category reminder (id: $id)",
      );
    }
  }
}
