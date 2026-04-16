import 'package:snevva/common/global_variables.dart';
import 'package:snevva/models/hive_models/reminder_payload_model.dart';

class ReminderPayloadMergeEntry {
  final ReminderPayloadModel reminder;
  final DateTime? updatedAt;
  final int sourceOrder;
  final int sourcePriority;
  final String sourceLabel;

  const ReminderPayloadMergeEntry({
    required this.reminder,
    this.updatedAt,
    this.sourceOrder = 0,
    this.sourcePriority = 0,
    this.sourceLabel = 'unknown',
  });
}

class ReminderPayloadMapper {
  static Map<int, ReminderPayloadModel> mergeByReminderId(
    Iterable<ReminderPayloadMergeEntry> entries, {
    void Function(String message)? log,
  }) {
    final merged = <int, ReminderPayloadMergeEntry>{};

    for (final entry in entries) {
      final reminderId = entry.reminder.id;
      if (reminderId <= 0) {
        log?.call(
          'Skip reminder with invalid id=$reminderId '
          '(category=${entry.reminder.category}, source=${entry.sourceLabel}).',
        );
        continue;
      }

      final existing = merged[reminderId];
      if (existing == null) {
        merged[reminderId] = entry;
        continue;
      }

      log?.call(
        'Duplicate reminderId detected: $reminderId '
        '(${existing.reminder.category} from ${existing.sourceLabel} vs '
        '${entry.reminder.category} from ${entry.sourceLabel}).',
      );

      merged[reminderId] = _resolveEntryConflict(existing, entry, log: log);
    }

    return {for (final item in merged.entries) item.key: item.value.reminder};
  }

  static ReminderPayloadModel resolveConflict(
    ReminderPayloadModel first,
    ReminderPayloadModel second, {
    DateTime? firstUpdatedAt,
    DateTime? secondUpdatedAt,
    int firstSourceOrder = 0,
    int secondSourceOrder = 1,
    int firstSourcePriority = 0,
    int secondSourcePriority = 0,
    String firstSourceLabel = 'first',
    String secondSourceLabel = 'second',
    void Function(String message)? log,
  }) {
    return _resolveEntryConflict(
      ReminderPayloadMergeEntry(
        reminder: first,
        updatedAt: firstUpdatedAt,
        sourceOrder: firstSourceOrder,
        sourcePriority: firstSourcePriority,
        sourceLabel: firstSourceLabel,
      ),
      ReminderPayloadMergeEntry(
        reminder: second,
        updatedAt: secondUpdatedAt,
        sourceOrder: secondSourceOrder,
        sourcePriority: secondSourcePriority,
        sourceLabel: secondSourceLabel,
      ),
      log: log,
    ).reminder;
  }

  static DateTime? tryParseUpdatedAt(Map<String, dynamic> raw) {
    const keys = [
      'UpdatedAt',
      'updatedAt',
      'LastUpdated',
      'lastUpdated',
      'ModifiedAt',
      'modifiedAt',
    ];

    for (final key in keys) {
      final rawValue = raw[key];
      if (rawValue == null) continue;
      final parsed = DateTime.tryParse(rawValue.toString());
      if (parsed != null) {
        return parsed.isUtc ? parsed.toLocal() : parsed;
      }
    }

    return null;
  }

  static ReminderPayloadMergeEntry _resolveEntryConflict(
    ReminderPayloadMergeEntry first,
    ReminderPayloadMergeEntry second, {
    void Function(String message)? log,
  }) {
    final now = DateTime.now();

    final firstNextFuture = _nextFutureOccurrence(first.reminder, now);
    final secondNextFuture = _nextFutureOccurrence(second.reminder, now);
    final firstHasFuture = firstNextFuture != null;
    final secondHasFuture = secondNextFuture != null;

    if (firstHasFuture != secondHasFuture) {
      final winner = firstHasFuture ? first : second;
      log?.call(
        'Conflict resolved for reminderId=${winner.reminder.id}: '
        'preferred ${winner.reminder.category} from ${winner.sourceLabel} '
        'because it has a future occurrence.',
      );
      return winner;
    }

    final firstUpdated = first.updatedAt;
    final secondUpdated = second.updatedAt;
    if (firstUpdated != null || secondUpdated != null) {
      if (firstUpdated == null) {
        log?.call(
          'Conflict resolved for reminderId=${second.reminder.id}: '
          'preferred ${second.reminder.category} from ${second.sourceLabel} '
          'because it has the newer update timestamp.',
        );
        return second;
      }
      if (secondUpdated == null) {
        log?.call(
          'Conflict resolved for reminderId=${first.reminder.id}: '
          'preferred ${first.reminder.category} from ${first.sourceLabel} '
          'because it has the newer update timestamp.',
        );
        return first;
      }
      if (firstUpdated.isAfter(secondUpdated)) {
        log?.call(
          'Conflict resolved for reminderId=${first.reminder.id}: '
          'preferred ${first.reminder.category} from ${first.sourceLabel} '
          'because UpdatedAt is newer.',
        );
        return first;
      }
      if (secondUpdated.isAfter(firstUpdated)) {
        log?.call(
          'Conflict resolved for reminderId=${second.reminder.id}: '
          'preferred ${second.reminder.category} from ${second.sourceLabel} '
          'because UpdatedAt is newer.',
        );
        return second;
      }
    }

    final firstLatest = _latestOccurrence(first.reminder, now);
    final secondLatest = _latestOccurrence(second.reminder, now);

    if (firstLatest != null && secondLatest != null) {
      if (firstLatest.isAfter(secondLatest)) {
        log?.call(
          'Conflict resolved for reminderId=${first.reminder.id}: '
          'preferred ${first.reminder.category} from ${first.sourceLabel} '
          'because it has the later scheduled occurrence.',
        );
        return first;
      }
      if (secondLatest.isAfter(firstLatest)) {
        log?.call(
          'Conflict resolved for reminderId=${second.reminder.id}: '
          'preferred ${second.reminder.category} from ${second.sourceLabel} '
          'because it has the later scheduled occurrence.',
        );
        return second;
      }
    }

    if (first.sourcePriority != second.sourcePriority) {
      final winner =
          first.sourcePriority > second.sourcePriority ? first : second;
      log?.call(
        'Conflict resolved for reminderId=${winner.reminder.id}: '
        'preferred ${winner.reminder.category} from ${winner.sourceLabel} '
        'because source priority is higher.',
      );
      return winner;
    }

    if (first.sourceOrder != second.sourceOrder) {
      final winner = first.sourceOrder > second.sourceOrder ? first : second;
      log?.call(
        'Conflict resolved for reminderId=${winner.reminder.id}: '
        'preferred ${winner.reminder.category} from ${winner.sourceLabel} '
        'because it appeared later in the merge order.',
      );
      return winner;
    }

    final winner =
        first.reminder.category.compareTo(second.reminder.category) <= 0
            ? first
            : second;
    log?.call(
      'Conflict resolved for reminderId=${winner.reminder.id}: '
      'stable tie-breaker kept ${winner.reminder.category} '
      'from ${winner.sourceLabel}.',
    );
    return winner;
  }

  static DateTime? _nextFutureOccurrence(
    ReminderPayloadModel reminder,
    DateTime now,
  ) {
    final upcoming =
        _scheduleCandidates(
            reminder,
          ).where((item) => !item.isBefore(now)).toList()
          ..sort((a, b) => a.compareTo(b));

    return upcoming.isEmpty ? null : upcoming.first;
  }

  static DateTime? _latestOccurrence(
    ReminderPayloadModel reminder,
    DateTime now,
  ) {
    final candidates = _scheduleCandidates(reminder);
    if (candidates.isEmpty) return null;

    candidates.sort((a, b) => a.compareTo(b));
    return candidates.last;
  }

  static List<DateTime> _scheduleCandidates(ReminderPayloadModel reminder) {
    final results = <DateTime>[];

    final timedList = reminder.customReminder.timesPerDay?.list ?? const [];
    for (final rawTime in timedList) {
      final parsed = _parseReminderDateTime(
        rawTime,
        dateHint: reminder.startDate,
      );
      if (parsed != null) {
        results.add(parsed);
      }
    }

    if (results.isNotEmpty) {
      return results;
    }

    final interval = reminder.customReminder.everyXHours;
    if (interval == null || interval.hours <= 0) {
      return results;
    }

    final startText = (reminder.startWaterTime ?? interval.startTime).trim();
    final endText = (reminder.endWaterTime ?? interval.endTime).trim();

    if (startText.isEmpty || endText.isEmpty) {
      return results;
    }

    try {
      final start = stringToTimeOfDay(startText);
      final end = stringToTimeOfDay(endText);
      final window = buildTimeWindow(start, end);

      var current = window.start.add(Duration(hours: interval.hours));
      var guard = 0;
      while (!current.isAfter(window.end) && guard < 100) {
        results.add(current);
        current = current.add(Duration(hours: interval.hours));
        guard++;
      }
    } catch (_) {}

    return results;
  }

  static DateTime? _parseReminderDateTime(String raw, {String? dateHint}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    try {
      return buildDateTimeFromTimeString(time: trimmed, date: dateHint);
    } catch (_) {
      final parsed = DateTime.tryParse(trimmed);
      if (parsed == null) return null;
      return parsed.isUtc ? parsed.toLocal() : parsed;
    }
  }
}
