import 'package:hive/hive.dart';

import '../../common/global_variables.dart';
import '../mappers/reminder_payload_mapper.dart';
import '../reminder_schedule_metadata.dart';

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

  @HiveField(13)
  final String? whenToTake;

  @HiveField(14)
  final String? startWaterTime;

  @HiveField(15)
  final String? endWaterTime;

  @HiveField(16)
  final DateTime? updatedAt;

  final ReminderScheduleMetadata scheduleMetadata;

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
    this.updatedAt,
    this.scheduleMetadata = const ReminderScheduleMetadata(
      timezoneId: 'UTC',
      scheduleSemantics: ScheduleSemantics.wallClock,
    ),
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

  static ScheduleSemantics defaultSemanticsForCategory(
    String rawCategory, {
    bool isSingleInstance = false,
  }) {
    switch (rawCategory.trim().toLowerCase()) {
      case 'event':
        return isSingleInstance
            ? ScheduleSemantics.absolute
            : ScheduleSemantics.wallClock;
      case 'medicine':
        return isSingleInstance
            ? ScheduleSemantics.absolute
            : ScheduleSemantics.wallClock;
      case 'water':
      case 'meal':
      default:
        return ScheduleSemantics.wallClock;
    }
  }

  bool get isSingleInstance {
    final type = customReminder.type;
    if (type == Option.interval) return false;
    final count = int.tryParse(customReminder.timesPerDay?.count ?? '');
    return (count ?? customReminder.timesPerDay?.list.length ?? 0) <= 1;
  }

  Map<String, dynamic> toApiJson() {
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
      'UpdatedAt': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toLocalJson() {
    return {
      'Id': id,
      'Title': title,
      'Category': category,
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
      'UpdatedAt': updatedAt?.toIso8601String(),
      'ScheduleMetadata': scheduleMetadata.toJson(),
    };
  }

  factory ReminderPayloadModel.fromApiJson(
    Map<String, dynamic> json, {
    required String timezoneIdFallback,
  }) {
    final custom =
        json['CustomReminder'] != null
            ? CustomReminder.fromJson(json['CustomReminder'])
            : const CustomReminder();

    final interval = custom.everyXHours;
    final startWaterTime = json['StartWaterTime'] ?? interval?.startTime;
    final endWaterTime = json['EndWaterTime'] ?? interval?.endTime;
    final category = (json['Category'] ?? '').toString();
    final fallbackSemantics = defaultSemanticsForCategory(
      category,
      isSingleInstance:
          int.tryParse(custom.timesPerDay?.count ?? '') == 1 ||
          (custom.timesPerDay?.list.length ?? 0) <= 1,
    );

    return ReminderPayloadModel(
      id: json['Id'] ?? 0,
      title: json['Title'] ?? '',
      category: category,
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
      startDate: json['StartDate'] ?? '',
      endDate: json['EndDate'],
      notes: json['Notes'],
      startWaterTime: startWaterTime,
      endWaterTime: endWaterTime,
      updatedAt: ReminderPayloadMapper.tryParseUpdatedAt(json),
      scheduleMetadata: ReminderScheduleMetadata.fromJson(
        null,
        timezoneIdFallback: timezoneIdFallback,
        semanticsFallback: fallbackSemantics,
      ),
    );
  }

  factory ReminderPayloadModel.fromLocalJson(
    Map<String, dynamic> json, {
    required String timezoneIdFallback,
  }) {
    final custom =
        json['CustomReminder'] != null
            ? CustomReminder.fromJson(
              Map<String, dynamic>.from(json['CustomReminder'] as Map),
            )
            : const CustomReminder();

    final category = (json['Category'] ?? '').toString();
    final fallbackSemantics = defaultSemanticsForCategory(
      category,
      isSingleInstance:
          int.tryParse(custom.timesPerDay?.count ?? '') == 1 ||
          (custom.timesPerDay?.list.length ?? 0) <= 1,
    );

    return ReminderPayloadModel(
      id: json['Id'] ?? 0,
      title: json['Title'] ?? '',
      category: category,
      medicineName: json['MedicineName']?.toString(),
      medicineType: json['MedicineType']?.toString(),
      dosage:
          json['Dosage'] is Map
              ? Dosage.fromJson(Map<String, dynamic>.from(json['Dosage'] as Map))
              : null,
      medicineFrequencyPerDay: json['MedicineFrequencyPerDay']?.toString(),
      reminderFrequencyType: json['ReminderFrequencyType']?.toString(),
      customReminder: custom,
      remindBefore:
          json['RemindBefore'] is Map
              ? RemindBefore.fromJson(
                Map<String, dynamic>.from(json['RemindBefore'] as Map),
              )
              : null,
      startDate: json['StartDate']?.toString(),
      endDate: json['EndDate']?.toString(),
      notes: json['Notes']?.toString(),
      whenToTake: json['WhenToTake']?.toString(),
      startWaterTime: json['StartWaterTime']?.toString(),
      endWaterTime: json['EndWaterTime']?.toString(),
      updatedAt: ReminderPayloadMapper.tryParseUpdatedAt(json),
      scheduleMetadata: ReminderScheduleMetadata.fromJson(
        json['ScheduleMetadata'] is Map
            ? Map<String, dynamic>.from(json['ScheduleMetadata'] as Map)
            : null,
        timezoneIdFallback: timezoneIdFallback,
        semanticsFallback: fallbackSemantics,
      ),
    );
  }

  factory ReminderPayloadModel.fromJson(Map<String, dynamic> json) {
    return ReminderPayloadModel.fromApiJson(
      json,
      timezoneIdFallback: 'UTC',
    );
  }

  Map<String, dynamic> toJson() => toApiJson();

  ReminderPayloadModel copyWith({
    int? id,
    String? title,
    String? category,
    String? medicineName,
    String? medicineType,
    Dosage? dosage,
    String? medicineFrequencyPerDay,
    String? reminderFrequencyType,
    CustomReminder? customReminder,
    RemindBefore? remindBefore,
    String? startDate,
    String? endDate,
    String? notes,
    String? whenToTake,
    String? startWaterTime,
    String? endWaterTime,
    DateTime? updatedAt,
    ReminderScheduleMetadata? scheduleMetadata,
  }) {
    return ReminderPayloadModel(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      medicineName: medicineName ?? this.medicineName,
      medicineType: medicineType ?? this.medicineType,
      dosage: dosage ?? this.dosage,
      medicineFrequencyPerDay:
          medicineFrequencyPerDay ?? this.medicineFrequencyPerDay,
      reminderFrequencyType:
          reminderFrequencyType ?? this.reminderFrequencyType,
      customReminder: customReminder ?? this.customReminder,
      remindBefore: remindBefore ?? this.remindBefore,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      notes: notes ?? this.notes,
      whenToTake: whenToTake ?? this.whenToTake,
      startWaterTime: startWaterTime ?? this.startWaterTime,
      endWaterTime: endWaterTime ?? this.endWaterTime,
      updatedAt: updatedAt ?? this.updatedAt,
      scheduleMetadata: scheduleMetadata ?? this.scheduleMetadata,
    );
  }

  ReminderPayloadModel copyWithScheduleMetadata(
    ReminderScheduleMetadata metadata,
  ) => copyWith(scheduleMetadata: metadata);
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
    if (category == "event") {
      buffer.writeln('--- Event Info ---');
      buffer.writeln('startDate: $startDate');
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
    final typeStr = (json['Type'] ?? json['type'] ?? '').toString();
    final type = Option.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => Option.times,
    );

    switch (type) {
      case Option.times:
        return CustomReminder(
          type: type,
          timesPerDay: TimesPerDay.fromJson(
            json['TimesPerDay'] ?? json['timesPerDay'] ?? {},
          ),
        );
      case Option.interval:
        return CustomReminder(
          type: type,
          everyXHours: EveryXHours.fromJson(
            json['EveryXHours'] ?? json['everyXHours'] ?? {},
          ),
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

  Map<String, dynamic> toJson() => {'Count': count, 'List': list};

  factory TimesPerDay.fromJson(Map<String, dynamic> json) => TimesPerDay(
    count: (json['Count'] ?? json['count'] ?? '').toString(),
    list: List<String>.from(json['List'] ?? json['list'] ?? []),
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
    hours: int.tryParse((json['Hours'] ?? json['hours'] ?? '0').toString()) ?? 0,
    startTime: (json['StartTime'] ?? json['startTime'] ?? '').toString(),
    endTime: (json['EndTime'] ?? json['endTime'] ?? '').toString(),
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
