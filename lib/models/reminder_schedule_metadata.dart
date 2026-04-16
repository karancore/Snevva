enum ScheduleSemantics { wallClock, absolute }

enum TxnStatus { idle, scheduling, committed }

enum ReminderResolutionStatus {
  pending,
  resolved,
  scheduled,
  failed,
  rolledBack,
  migrated,
}

const int kCurrentReminderScheduleVersion = 2;

String scheduleSemanticsToStorageValue(ScheduleSemantics semantics) {
  switch (semantics) {
    case ScheduleSemantics.wallClock:
      return 'wall_clock';
    case ScheduleSemantics.absolute:
      return 'absolute';
  }
}

String txnStatusToStorageValue(TxnStatus status) {
  switch (status) {
    case TxnStatus.idle:
      return 'idle';
    case TxnStatus.scheduling:
      return 'scheduling';
    case TxnStatus.committed:
      return 'committed';
  }
}

ScheduleSemantics scheduleSemanticsFromStorageValue(
  String? value, {
  required ScheduleSemantics fallback,
}) {
  switch ((value ?? '').trim().toLowerCase()) {
    case 'absolute':
      return ScheduleSemantics.absolute;
    case 'wall_clock':
      return ScheduleSemantics.wallClock;
    default:
      return fallback;
  }
}

TxnStatus txnStatusFromStorageValue(String? value) {
  switch ((value ?? '').trim().toLowerCase()) {
    case 'scheduling':
      return TxnStatus.scheduling;
    case 'committed':
      return TxnStatus.committed;
    default:
      return TxnStatus.idle;
  }
}

String reminderResolutionStatusToStorageValue(
  ReminderResolutionStatus status,
) {
  switch (status) {
    case ReminderResolutionStatus.pending:
      return 'pending';
    case ReminderResolutionStatus.resolved:
      return 'resolved';
    case ReminderResolutionStatus.scheduled:
      return 'scheduled';
    case ReminderResolutionStatus.failed:
      return 'failed';
    case ReminderResolutionStatus.rolledBack:
      return 'rolled_back';
    case ReminderResolutionStatus.migrated:
      return 'migrated';
  }
}

ReminderResolutionStatus reminderResolutionStatusFromStorageValue(
  String? value,
) {
  switch ((value ?? '').trim().toLowerCase()) {
    case 'resolved':
      return ReminderResolutionStatus.resolved;
    case 'scheduled':
      return ReminderResolutionStatus.scheduled;
    case 'failed':
      return ReminderResolutionStatus.failed;
    case 'rolled_back':
      return ReminderResolutionStatus.rolledBack;
    case 'migrated':
      return ReminderResolutionStatus.migrated;
    default:
      return ReminderResolutionStatus.pending;
  }
}

class ReminderScheduleMetadata {
  final int scheduleVersion;
  final String timezoneId;
  final ScheduleSemantics scheduleSemantics;
  final String? nextFireAt;
  final List<int> alarmIds;
  final List<int> preAlarmIds;
  final String? lastResolvedAt;
  final ReminderResolutionStatus lastResolutionStatus;
  final bool migratedFromLegacy;
  final TxnStatus txnStatus;
  final List<int> pendingAlarmIds;
  final String? lastFiredAt;
  final String? lastExpectedFireAt;

  const ReminderScheduleMetadata({
    this.scheduleVersion = kCurrentReminderScheduleVersion,
    required this.timezoneId,
    required this.scheduleSemantics,
    this.nextFireAt,
    this.alarmIds = const [],
    this.preAlarmIds = const [],
    this.lastResolvedAt,
    this.lastResolutionStatus = ReminderResolutionStatus.pending,
    this.migratedFromLegacy = false,
    this.txnStatus = TxnStatus.idle,
    this.pendingAlarmIds = const [],
    this.lastFiredAt,
    this.lastExpectedFireAt,
  });

  factory ReminderScheduleMetadata.fallback({
    required String timezoneId,
    required ScheduleSemantics semantics,
  }) {
    return ReminderScheduleMetadata(
      timezoneId: timezoneId,
      scheduleSemantics: semantics,
    );
  }

  factory ReminderScheduleMetadata.fromJson(
    Map<String, dynamic>? json, {
    required String timezoneIdFallback,
    required ScheduleSemantics semanticsFallback,
  }) {
    final data = json ?? const <String, dynamic>{};

    List<int> parseIds(dynamic raw) {
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

    return ReminderScheduleMetadata(
      scheduleVersion:
          (data['schedule_version'] as int?) ?? kCurrentReminderScheduleVersion,
      timezoneId:
          (data['timezone_id']?.toString().trim().isNotEmpty ?? false)
              ? data['timezone_id'].toString().trim()
              : timezoneIdFallback,
      scheduleSemantics: scheduleSemanticsFromStorageValue(
        data['schedule_semantics']?.toString(),
        fallback: semanticsFallback,
      ),
      nextFireAt: data['next_fire_at']?.toString(),
      alarmIds: parseIds(data['alarm_ids']),
      preAlarmIds: parseIds(data['pre_alarm_ids']),
      lastResolvedAt: data['last_resolved_at']?.toString(),
      lastResolutionStatus: reminderResolutionStatusFromStorageValue(
        data['last_resolution_status']?.toString(),
      ),
      migratedFromLegacy: data['migrated_from_legacy'] == true,
      txnStatus: txnStatusFromStorageValue(data['txn_status']?.toString()),
      pendingAlarmIds: parseIds(data['pending_alarm_ids']),
      lastFiredAt: data['last_fired_at']?.toString(),
      lastExpectedFireAt: data['last_expected_fire_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schedule_version': scheduleVersion,
      'timezone_id': timezoneId,
      'schedule_semantics':
          scheduleSemanticsToStorageValue(scheduleSemantics),
      'next_fire_at': nextFireAt,
      'alarm_ids': alarmIds,
      'pre_alarm_ids': preAlarmIds,
      'last_resolved_at': lastResolvedAt,
      'last_resolution_status':
          reminderResolutionStatusToStorageValue(lastResolutionStatus),
      'migrated_from_legacy': migratedFromLegacy,
      'txn_status': txnStatusToStorageValue(txnStatus),
      'pending_alarm_ids': pendingAlarmIds,
      'last_fired_at': lastFiredAt,
      'last_expected_fire_at': lastExpectedFireAt,
    };
  }

  ReminderScheduleMetadata copyWith({
    int? scheduleVersion,
    String? timezoneId,
    ScheduleSemantics? scheduleSemantics,
    String? nextFireAt,
    bool clearNextFireAt = false,
    List<int>? alarmIds,
    List<int>? preAlarmIds,
    String? lastResolvedAt,
    bool clearLastResolvedAt = false,
    ReminderResolutionStatus? lastResolutionStatus,
    bool? migratedFromLegacy,
    TxnStatus? txnStatus,
    List<int>? pendingAlarmIds,
    String? lastFiredAt,
    String? lastExpectedFireAt,
  }) {
    return ReminderScheduleMetadata(
      scheduleVersion: scheduleVersion ?? this.scheduleVersion,
      timezoneId: timezoneId ?? this.timezoneId,
      scheduleSemantics: scheduleSemantics ?? this.scheduleSemantics,
      nextFireAt: clearNextFireAt ? null : (nextFireAt ?? this.nextFireAt),
      alarmIds: alarmIds ?? this.alarmIds,
      preAlarmIds: preAlarmIds ?? this.preAlarmIds,
      lastResolvedAt:
          clearLastResolvedAt ? null : (lastResolvedAt ?? this.lastResolvedAt),
      lastResolutionStatus:
          lastResolutionStatus ?? this.lastResolutionStatus,
      migratedFromLegacy: migratedFromLegacy ?? this.migratedFromLegacy,
      txnStatus: txnStatus ?? this.txnStatus,
      pendingAlarmIds: pendingAlarmIds ?? this.pendingAlarmIds,
      lastFiredAt: lastFiredAt ?? this.lastFiredAt,
      lastExpectedFireAt: lastExpectedFireAt ?? this.lastExpectedFireAt,
    );
  }
}
