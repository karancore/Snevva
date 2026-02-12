import 'package:hive/hive.dart';

import '../../common/global_variables.dart';
import '../../consts/consts.dart';

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
      'whenToTake': whenToTake,
      'startWaterTime': startWaterTime,
      'endWaterTime': endWaterTime,
    };
  }

  factory ReminderPayloadModel.fromJson(Map<String, dynamic> json) {
    return ReminderPayloadModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      category: json['category'] ?? '',
      medicineName: json['medicineName'],
      medicineType: json['medicineType'],
      dosage: json['dosage'] != null ? Dosage.fromJson(json['dosage']) : null,
      whenToTake: json['whenToTake'],
      medicineFrequencyPerDay: json['medicineFrequencyPerDay'],
      reminderFrequencyType: json['reminderFrequencyType'],
      customReminder:
          json['customReminder'] != null
              ? CustomReminder.fromJson(json['customReminder'])
              : const CustomReminder(),
      remindBefore:
          json['remindBefore'] != null
              ? RemindBefore.fromJson(json['remindBefore'])
              : null,
      startDate: json['startDate'],
      endDate: json['endDate'],
      notes: json['notes'],
      startWaterTime: json['startWaterTime'],
      endWaterTime: json['endWaterTime'],
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

  Map<String, dynamic> toJson() => {'value': value, 'unit': unit};

  factory Dosage.fromJson(Map<String, dynamic> json) =>
      Dosage(value: json['value'], unit: json['unit']);
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
    final type = Option.values.firstWhere(
      (e) => e.name == json['type'],

      orElse: () {
        debugPrint("Unknown reminder type:  ${json['type']}");
        return Option.times;
      },
    );

    switch (type) {
      case Option.times:
        return CustomReminder(
          type: type,
          timesPerDay: TimesPerDay.fromJson(json['timesPerDay'] ?? {}),
        );
      case Option.interval:
        return CustomReminder(
          type: type,
          everyXHours: EveryXHours.fromJson(json['everyXHours'] ?? {}),
        );
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {'type': type?.name};
    if (timesPerDay != null) {
      data['timesPerDay'] = timesPerDay!.toJson();
    }
    if (everyXHours != null) {
      data['everyXHours'] = everyXHours!.toJson();
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

  Map<String, dynamic> toJson() => {'count': count, 'list': list};

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

  const RemindBefore({required this.time, required this.unit});

  Map<String, dynamic> toJson() => {'time': time, 'unit': unit};

  factory RemindBefore.fromJson(Map<String, dynamic> json) =>
      RemindBefore(time: json['time'], unit: json['unit']);
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
    return startWaterTime!;
  }

  String get waterEndSafe {
    _ensure('water');
    return endWaterTime!;
  }

  int get waterTimesCountSafe {
    _ensure('water');
    return int.parse(customReminder.timesPerDay!.count);
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
