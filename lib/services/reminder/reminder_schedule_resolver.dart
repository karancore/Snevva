import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../models/hive_models/reminder_payload_model.dart';
import '../../models/reminder_schedule_metadata.dart';
import 'device_timezone_service.dart';

class ReminderResolutionException implements Exception {
  final String message;

  const ReminderResolutionException(this.message);

  @override
  String toString() => message;
}

class ResolvedReminderSchedule {
  final ReminderPayloadModel reminder;
  final List<DateTime> mainTimes;
  final List<DateTime> preReminderTimes;
  final String? nextFireAt;
  final ReminderScheduleMetadata updatedMetadata;

  const ResolvedReminderSchedule({
    required this.reminder,
    required this.mainTimes,
    required this.preReminderTimes,
    required this.nextFireAt,
    required this.updatedMetadata,
  });
}

class ReminderScheduleResolver {
  const ReminderScheduleResolver();

  Future<ResolvedReminderSchedule> resolve(
    ReminderPayloadModel reminder,
  ) async {
    final currentTimezoneId = await DeviceTimezoneService.instance
        .getTimeZoneId();
    final semantics = reminder.scheduleMetadata.scheduleSemantics;

    final resolvedMainTimes = switch (reminder.category.trim().toLowerCase()) {
      'water' => _resolveWater(reminder, currentTimezoneId),
      'medicine' => _resolveMedicine(reminder, currentTimezoneId),
      'meal' || 'event' => _resolveSingleOrExplicit(
        reminder,
        currentTimezoneId,
      ),
      _ => throw ReminderResolutionException(
        'Unsupported reminder category: ${reminder.category}',
      ),
    };

    if (resolvedMainTimes.isEmpty) {
      throw ReminderResolutionException(
        'No future alarms resolved for reminder ${reminder.id}',
      );
    }

    resolvedMainTimes.sort();

    // PHASE F: Safe Generation Limits (Post-Sort for explicit mapping)
    // 36h window provides overlap with the 6-hour WorkManager reconciliation
    // cycle. Even if a worker tick is delayed, alarms won't expire prematurely.
    var filteredMainTimes = <DateTime>[];
    final limit = DateTime.now().add(const Duration(hours: 36));
    
    for (final time in resolvedMainTimes) {
      if (filteredMainTimes.length >= 50) break;
      if (time.isBefore(limit) || time.isAtSameMomentAs(limit)) {
        filteredMainTimes.add(time);
      }
    }
    if (filteredMainTimes.isEmpty && resolvedMainTimes.isNotEmpty) {
      filteredMainTimes = [resolvedMainTimes.first]; // Ensure at least one to wake up
    }

    final preReminderTimes = _resolvePreReminderTimes(
      reminder: reminder,
      mainTimes: filteredMainTimes,
    );
    final nextFireAt = filteredMainTimes.first.toUtc().toIso8601String();
    final updatedMetadata = reminder.scheduleMetadata.copyWith(
      scheduleVersion: kCurrentReminderScheduleVersion,
      timezoneId:
          semantics == ScheduleSemantics.wallClock
              ? currentTimezoneId
              : reminder.scheduleMetadata.timezoneId,
      clearNextFireAt: true,
      nextFireAt: nextFireAt,
      lastResolvedAt: DateTime.now().toUtc().toIso8601String(),
      lastResolutionStatus: ReminderResolutionStatus.resolved,
    );

    return ResolvedReminderSchedule(
      reminder: reminder.copyWithScheduleMetadata(updatedMetadata),
      mainTimes: filteredMainTimes,
      preReminderTimes: preReminderTimes,
      nextFireAt: nextFireAt,
      updatedMetadata: updatedMetadata,
    );
  }

  Future<DateTime?> computeNextFireSafe(ReminderPayloadModel reminder) async {
    final metadata = reminder.scheduleMetadata;
    final currentTimezoneId = await DeviceTimezoneService.instance.getTimeZoneId();

    bool isStale = false;
    if (metadata.lastResolvedAt == null) {
      isStale = true;
    } else {
      final lastResolved = DateTime.tryParse(metadata.lastResolvedAt!)?.toUtc();
      if (lastResolved == null || DateTime.now().toUtc().difference(lastResolved).inHours > 24) {
        isStale = true;
      }
    }

    if (metadata.timezoneId != currentTimezoneId) isStale = true;
    if (metadata.scheduleVersion != kCurrentReminderScheduleVersion) isStale = true;
    
    if (metadata.nextFireAt == null) {
      isStale = true;
    } else {
      final cachedNext = DateTime.tryParse(metadata.nextFireAt!);
      if (cachedNext == null || cachedNext.isBefore(DateTime.now())) {
        isStale = true;
      }
    }

    if (!isStale && metadata.nextFireAt != null) {
      return DateTime.tryParse(metadata.nextFireAt!);
    }

    try {
      final resolved = await resolve(reminder);
      if (resolved.nextFireAt != null) {
        return DateTime.tryParse(resolved.nextFireAt!);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  List<DateTime> _resolveWater(
    ReminderPayloadModel reminder,
    String currentTimezoneId,
  ) {
    if (reminder.customReminder.everyXHours != null) {
      final interval = reminder.customReminder.everyXHours!;
      final start = canonicalLocalTime(reminder.waterStartSafe);
      final end = canonicalLocalTime(reminder.waterEndSafe);
      final startMinutes = _minutesForLocalTime(start);
      final endMinutes = _minutesForLocalTime(end);
      final windowEndMinutes =
          endMinutes < startMinutes ? endMinutes + (24 * 60) : endMinutes;
      final results = <DateTime>[];
      var current = startMinutes + interval.hours * 60;
      final now = DateTime.now();
      final limit = now.add(const Duration(hours: 36));

      while (current <= windowEndMinutes) {
        if (results.length >= 50) break;
        
        final normalizedMinutes = current % (24 * 60);
        final localTime = _localTimeFromMinutes(normalizedMinutes);
        final t = _resolveOccurrence(
          localDate: canonicalLocalDate(reminder.startDate),
          localTime: localTime,
          timezoneId: currentTimezoneId,
          semantics: ScheduleSemantics.wallClock,
          rollForwardIfPast: true,
        );
        
        if (t.isBefore(limit) || t.isAtSameMomentAs(limit)) {
          results.add(t);
        }
        current += interval.hours * 60;
      }
      return results;
    }

    final count = reminder.waterTimesCountSafe;
    final explicitTimes = reminder.customReminder.timesPerDay?.list ?? const [];
    if (explicitTimes.isNotEmpty) {
      return explicitTimes
          .map(canonicalLocalTime)
          .map(
            (localTime) => _resolveOccurrence(
              localDate: canonicalLocalDate(reminder.startDate),
              localTime: localTime,
              timezoneId: currentTimezoneId,
              semantics: ScheduleSemantics.wallClock,
              rollForwardIfPast: true,
            ),
          )
          .toList()
        ..sort();
    }

    final start = canonicalLocalTime(reminder.waterStartSafe);
    final end = canonicalLocalTime(reminder.waterEndSafe);
    return generateTimesBetween(
      startTime: start,
      endTime: end,
      times: count,
    ).map(
      (localTime) => _resolveOccurrence(
        localDate: canonicalLocalDate(reminder.startDate),
        localTime: localTime,
        timezoneId: currentTimezoneId,
        semantics: ScheduleSemantics.wallClock,
        rollForwardIfPast: true,
      ),
    ).toList()
      ..sort();
  }

  List<DateTime> _resolveMedicine(
    ReminderPayloadModel reminder,
    String currentTimezoneId,
  ) {
    final metadata = reminder.scheduleMetadata;
    if (reminder.customReminder.everyXHours != null) {
      final interval = reminder.customReminder.everyXHours!;
      final start = canonicalLocalTime(interval.startTime);
      final end = canonicalLocalTime(interval.endTime);
      final startMinutes = _minutesForLocalTime(start);
      final endMinutes = _minutesForLocalTime(end);
      final windowEndMinutes =
          endMinutes < startMinutes ? endMinutes + (24 * 60) : endMinutes;
      final results = <DateTime>[];
      var current = startMinutes + interval.hours * 60;
      final now = DateTime.now();
      final limit = now.add(const Duration(hours: 36));

      while (current <= windowEndMinutes) {
        if (results.length >= 50) break;
        
        final normalizedMinutes = current % (24 * 60);
        final localTime = _localTimeFromMinutes(normalizedMinutes);
        final t = _resolveOccurrence(
          localDate: canonicalLocalDate(reminder.startDate),
          localTime: localTime,
          timezoneId:
              metadata.scheduleSemantics == ScheduleSemantics.absolute
                  ? metadata.timezoneId
                  : currentTimezoneId,
          semantics: metadata.scheduleSemantics,
          rollForwardIfPast: metadata.scheduleSemantics ==
              ScheduleSemantics.wallClock,
        );
        
        if (t.isBefore(limit) || t.isAtSameMomentAs(limit)) {
          results.add(t);
        }
        current += interval.hours * 60;
      }
      return results..sort();
    }

    final times = reminder.medicineTimesSafe.map(canonicalLocalTime);
    return times
        .map(
          (localTime) => _resolveOccurrence(
            localDate: canonicalLocalDate(reminder.startDate),
            localTime: localTime,
            timezoneId:
                metadata.scheduleSemantics == ScheduleSemantics.absolute
                    ? metadata.timezoneId
                    : currentTimezoneId,
            semantics: metadata.scheduleSemantics,
            rollForwardIfPast: metadata.scheduleSemantics ==
                ScheduleSemantics.wallClock,
          ),
        )
        .where((dt) => dt.isAfter(DateTime.now()))
        .toList()
      ..sort();
  }

  List<DateTime> _resolveSingleOrExplicit(
    ReminderPayloadModel reminder,
    String currentTimezoneId,
  ) {
    final times = reminder.timesSafe;
    final metadata = reminder.scheduleMetadata;
    final localDate = canonicalLocalDate(reminder.startDate);

    return times
        .map((raw) {
          final trimmed = raw.trim();
          final direct = DateTime.tryParse(trimmed);
          if (direct != null) {
            return direct.isUtc ? direct.toLocal() : direct;
          }
          return _resolveOccurrence(
            localDate: localDate,
            localTime: canonicalLocalTime(trimmed),
            timezoneId:
                metadata.scheduleSemantics == ScheduleSemantics.absolute
                    ? metadata.timezoneId
                    : currentTimezoneId,
            semantics: metadata.scheduleSemantics,
            rollForwardIfPast: metadata.scheduleSemantics ==
                ScheduleSemantics.wallClock,
          );
        })
        .where((dt) => dt.isAfter(DateTime.now()))
        .toList()
      ..sort();
  }

  List<DateTime> _resolvePreReminderTimes({
    required ReminderPayloadModel reminder,
    required List<DateTime> mainTimes,
  }) {
    final before = reminder.remindBefore;
    if (before == null) return const [];

    final offset =
        before.unit == 'hours'
            ? Duration(hours: before.time)
            : Duration(minutes: before.time);

    return mainTimes
        .map((mainTime) => mainTime.subtract(offset))
        .where((beforeTime) => beforeTime.isAfter(DateTime.now()))
        .toList()
      ..sort();
  }

  DateTime _resolveOccurrence({
    required String? localDate,
    required String localTime,
    required String timezoneId,
    required ScheduleSemantics semantics,
    required bool rollForwardIfPast,
  }) {
    final parsedTime = _parseCanonicalLocalTime(localTime);
    final date = _parseCanonicalLocalDate(localDate);
    final now = DateTime.now();
    final targetDate = date ?? now;

    final location = _safeLocation(timezoneId);
    var resolved = tz.TZDateTime(
      location,
      targetDate.year,
      targetDate.month,
      targetDate.day,
      parsedTime.$1,
      parsedTime.$2,
    );

    if (semantics == ScheduleSemantics.wallClock && rollForwardIfPast) {
      while (!resolved.toLocal().isAfter(now)) {
        resolved = tz.TZDateTime(
          location,
          resolved.year,
          resolved.month,
          resolved.day + 1,
          parsedTime.$1,
          parsedTime.$2,
        );
      }
      return resolved.toLocal();
    }

    return resolved.toLocal();
  }

  tz.Location _safeLocation(String timezoneId) {
    try {
      return tz.getLocation(timezoneId);
    } catch (_) {
      return tz.local;
    }
  }
}

String? canonicalLocalDate(String? raw) {
  final trimmed = (raw ?? '').trim();
  if (trimmed.isEmpty) return null;

  final direct = DateTime.tryParse(trimmed);
  if (direct != null) {
    final local = direct.isUtc ? direct.toLocal() : direct;
    return DateFormat('yyyy-MM-dd').format(local);
  }

  final knownFormats = [
    DateFormat('MMMM dd, yyyy'),
    DateFormat('yyyy-MM-dd'),
    DateFormat('dd/MM/yyyy'),
  ];
  for (final format in knownFormats) {
    try {
      final parsed = format.parseStrict(trimmed);
      return DateFormat('yyyy-MM-dd').format(parsed);
    } catch (_) {}
  }

  throw ReminderResolutionException('Unsupported date format: "$raw"');
}

String canonicalLocalTime(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    throw const ReminderResolutionException('Time is required');
  }

  final direct = DateTime.tryParse(trimmed);
  if (direct != null) {
    final local = direct.isUtc ? direct.toLocal() : direct;
    return DateFormat('HH:mm').format(local);
  }

  final cleansed =
      trimmed.replaceAll(RegExp(r'\s+'), ' ').replaceAll('.', '');

  final meridiemNormalized = cleansed.replaceAllMapped(
    RegExp(r'\b(am|pm)\b', caseSensitive: false),
    (match) => match.group(0)!.toUpperCase(),
  );
  final formats = [
    DateFormat('HH:mm'),
    DateFormat('hh:mm a'),
    DateFormat('h:mm a'),
  ];
  for (final format in formats) {
    try {
      final parsed = format.parseStrict(meridiemNormalized);
      return DateFormat('HH:mm').format(parsed);
    } catch (_) {}
  }

  throw ReminderResolutionException('Unsupported time format: "$raw"');
}

List<String> generateTimesBetween({
  required String startTime,
  required String endTime,
  required int times,
}) {
  if (times <= 0) return const [];
  final start = _parseCanonicalLocalTime(startTime);
  final end = _parseCanonicalLocalTime(endTime);
  final startMinutes = start.$1 * 60 + start.$2;
  var endMinutes = end.$1 * 60 + end.$2;
  if (endMinutes < startMinutes) {
    endMinutes += 24 * 60;
  }

  final totalMinutes = endMinutes - startMinutes;
  if (totalMinutes <= 0) {
    return [startTime];
  }

  final gap = (totalMinutes / times).floor().clamp(1, totalMinutes);
  return List<String>.generate(times, (index) {
    final minutes = (startMinutes + gap * index) % (24 * 60);
    return _localTimeFromMinutes(minutes);
  });
}

(int, int) _parseCanonicalLocalTime(String value) {
  final parts = value.split(':');
  if (parts.length != 2) {
    throw ReminderResolutionException('Expected canonical time HH:mm: "$value"');
  }
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) {
    throw ReminderResolutionException('Invalid canonical time: "$value"');
  }
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    throw ReminderResolutionException('Out-of-range canonical time: "$value"');
  }
  return (hour, minute);
}

DateTime? _parseCanonicalLocalDate(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return DateFormat('yyyy-MM-dd').parseStrict(value, true).toLocal();
}

int _minutesForLocalTime(String localTime) {
  final parsed = _parseCanonicalLocalTime(localTime);
  return parsed.$1 * 60 + parsed.$2;
}

String _localTimeFromMinutes(int minutes) {
  final normalized = minutes % (24 * 60);
  final hour = (normalized ~/ 60).toString().padLeft(2, '0');
  final minute = (normalized % 60).toString().padLeft(2, '0');
  return '$hour:$minute';
}
