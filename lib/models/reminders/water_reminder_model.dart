import 'dart:convert';

import 'package:alarm/model/alarm_settings.dart';
import 'package:snevva/models/reminder_schedule_metadata.dart';

import '../../common/global_variables.dart';

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
  final ReminderScheduleMetadata scheduleMetadata;
  final DateTime? updatedAt;

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
    this.updatedAt,
    this.scheduleMetadata = const ReminderScheduleMetadata(
      timezoneId: 'UTC',
      scheduleSemantics: ScheduleSemantics.wallClock,
    ),
  }) : assert(
         (type == Option.times && interval == null) ||
             (type == Option.interval && interval != null),
         'Invalid WaterReminderModel state',
       );

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'updatedAt': updatedAt?.toIso8601String(),
      'title': title,
      'Category': category,
      'type': type.name, // ✅ JSON-safe
      'alarms': alarms.map((a) => a.toJson()).toList(),
      'timesPerDay': timesPerDay,
      'waterReminderStartTime': waterReminderStartTime,
      'waterReminderEndTime': waterReminderEndTime,
      'notes': notes,
      'interval': interval,
      'scheduleMetadata': scheduleMetadata.toJson(),
    };
  }

  factory WaterReminderModel.fromJson(Map<String, dynamic> json) {
    final typeStr = (json['type'] ?? json['Type'] ?? '').toString();
    final type = Option.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => Option.times,
    );
    final rawAlarms = json['alarms'] ?? json['Alarms'];
    final rawScheduleMetadata =
        json['scheduleMetadata'] ?? json['ScheduleMetadata'];

    return WaterReminderModel(
      id: _parseInt(json['id'] ?? json['Id']),
      updatedAt: (json['updatedAt'] ?? json['UpdatedAt']) != null
          ? DateTime.tryParse(
            (json['updatedAt'] ?? json['UpdatedAt']).toString(),
          )
          : null,
      title: (json['title'] ?? json['Title'] ?? 'Water Reminder').toString(),
      category: (json['category'] ?? json['Category'] ?? 'Water').toString(),
      type: type,
      notes: _parseNullableString(json['notes'] ?? json['Notes']),
      alarms: _parseAlarms(rawAlarms),
      timesPerDay:
          (json['timesPerDay'] ?? json['TimesPerDay'] ?? '').toString(),
      waterReminderStartTime: (json['waterReminderStartTime'] ??
              json['WaterReminderStartTime'] ??
              json['StartWaterTime'] ??
              '00:00')
          .toString(),
      waterReminderEndTime: (json['waterReminderEndTime'] ??
              json['WaterReminderEndTime'] ??
              json['EndWaterTime'] ??
              '23:59')
          .toString(),
      interval: type == Option.interval
          ? (json['interval'] ?? json['Interval'] ?? '60').toString()
          : null,
      scheduleMetadata: ReminderScheduleMetadata.fromJson(
        rawScheduleMetadata is Map
            ? Map<String, dynamic>.from(rawScheduleMetadata)
            : null,
        timezoneIdFallback: 'UTC',
        semanticsFallback: ScheduleSemantics.wallClock,
      ),
    );
  }

  static List<AlarmSettings> _parseAlarms(dynamic rawAlarms) {
    if (rawAlarms is String) {
      try {
        return _parseAlarms(jsonDecode(rawAlarms));
      } catch (_) {
        return const <AlarmSettings>[];
      }
    }

    if (rawAlarms is! List) {
      return const <AlarmSettings>[];
    }

    final alarms = <AlarmSettings>[];
    for (final item in rawAlarms) {
      if (item is AlarmSettings) {
        alarms.add(item);
        continue;
      }
      if (item is Map) {
        alarms.add(AlarmSettings.fromJson(Map<String, dynamic>.from(item)));
        continue;
      }
      if (item is String) {
        try {
          final decoded = jsonDecode(item);
          if (decoded is Map) {
            alarms.add(
              AlarmSettings.fromJson(Map<String, dynamic>.from(decoded)),
            );
          }
        } catch (_) {}
      }
    }
    return alarms;
  }
}

int _parseInt(dynamic raw) {
  if (raw is int) return raw;
  return int.tryParse(raw?.toString() ?? '') ?? 0;
}

String? _parseNullableString(dynamic raw) {
  if (raw == null) return null;
  final text = raw.toString().trim();
  return text.isEmpty ? null : text;
}
