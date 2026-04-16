import 'dart:convert';

import 'package:alarm/alarm.dart';

import '../../common/global_variables.dart';
import '../../consts/consts.dart';
import '../../models/hive_models/reminder_payload_model.dart';
import '../../models/reminder_schedule_metadata.dart';
import 'reminder_schedule_resolver.dart';

typedef ReminderSaveCallback =
    Future<void> Function(ReminderPayloadModel reminder);
typedef AlarmSetCallback = Future<bool> Function(AlarmSettings alarmSettings);
typedef AlarmStopCallback = Future<bool> Function(int id);

class ReminderAlarmTransactionResult {
  final ReminderPayloadModel reminder;
  final List<AlarmSettings> mainAlarms;
  final List<AlarmSettings> preAlarms;

  const ReminderAlarmTransactionResult({
    required this.reminder,
    required this.mainAlarms,
    required this.preAlarms,
  });
}

class ReminderAlarmTransaction {
  ReminderAlarmTransaction({
    ReminderScheduleResolver? resolver,
    AlarmSetCallback? setAlarm,
    AlarmStopCallback? stopAlarm,
    ReminderSaveCallback? saveReminder,
  }) : _resolver = resolver ?? const ReminderScheduleResolver(),
       _setAlarm =
           setAlarm ?? ((settings) => Alarm.set(alarmSettings: settings)),
       _stopAlarm = stopAlarm ?? Alarm.stop,
       _saveReminder = saveReminder;

  final ReminderScheduleResolver _resolver;
  final AlarmSetCallback _setAlarm;
  final AlarmStopCallback _stopAlarm;
  final ReminderSaveCallback? _saveReminder;

  Future<ReminderAlarmTransactionResult> schedule(
    ReminderPayloadModel reminder,
  ) async {
    ReminderAlarmTransactionResult? finalResult;

    await runWithLock("reminder_${reminder.id}", () async {
      debugPrint('[ReminderTxn] START scheduling reminder ${reminder.id}');

      // PHASE C - Sanitization
      final sanitizedMeta = reminder.scheduleMetadata.copyWith(
        alarmIds: sanitizeIds(reminder.scheduleMetadata.alarmIds),
        pendingAlarmIds: sanitizeIds(reminder.scheduleMetadata.pendingAlarmIds),
      );
      var currentReminder = reminder.copyWithScheduleMetadata(sanitizedMeta);

      final resolved = await _resolver.resolve(currentReminder);

      // STEP 1 - Begin
      currentReminder = resolved.reminder.copyWithScheduleMetadata(
        resolved.updatedMetadata.copyWith(
          txnStatus: TxnStatus.scheduling,
          pendingAlarmIds: [],
        ),
      );
      if (_saveReminder != null) {
        await _saveReminder!(currentReminder);
      }

      try {
        final mainAlarms = <AlarmSettings>[];
        final preAlarms = <AlarmSettings>[];
        final newPendingIds = <int>[];
        final existingIds = <int>{
          ...currentReminder.scheduleMetadata.alarmIds,
          ...currentReminder.scheduleMetadata.pendingAlarmIds,
        };

        // STEP 2 - Schedule Incrementally
        for (var index = 0; index < resolved.mainTimes.length; index++) {
          final time = resolved.mainTimes[index];
          final alarmId = computeAlarmId(
            reminderId: currentReminder.id,
            scheduleVersion: currentReminder.scheduleMetadata.scheduleVersion,
            fireTime: time,
            isPreAlarm: false,
          );

          final alarm = buildMainAlarm(
            reminder: currentReminder,
            scheduledTime: time,
            alarmId: alarmId,
          );
          mainAlarms.add(alarm);

          if (!existingIds.contains(alarmId)) {
            debugPrint(
              '[ReminderTxn] SCHEDULE reminder ${currentReminder.id} alarmId=$alarmId (main)',
            );
            final success = await _setAlarm(alarm);
            if (!success) throw StateError('Failed to schedule alarm $alarmId');
            existingIds.add(alarmId);
          } else {
            debugPrint(
              '[ReminderTxn] SKIP IDEMPOTENT reminder ${currentReminder.id} alarmId=$alarmId',
            );
          }

          newPendingIds.add(alarmId);
          currentReminder = currentReminder.copyWithScheduleMetadata(
            currentReminder.scheduleMetadata.copyWith(
              pendingAlarmIds: List.of(newPendingIds),
            ),
          );
          if (_saveReminder != null) await _saveReminder!(currentReminder);
        }

        for (var index = 0; index < resolved.preReminderTimes.length; index++) {
          final time = resolved.preReminderTimes[index];
          final alarmId = computeAlarmId(
            reminderId: currentReminder.id,
            scheduleVersion: currentReminder.scheduleMetadata.scheduleVersion,
            fireTime: time,
            isPreAlarm: true,
          );

          final mainTime =
              index < resolved.mainTimes.length
                  ? resolved.mainTimes[index]
                  : resolved.mainTimes.first;

          final preAlarm = buildPreAlarm(
            reminder: currentReminder,
            scheduledTime: time,
            mainTime: mainTime,
            alarmId: alarmId,
          );
          preAlarms.add(preAlarm);

          if (!existingIds.contains(alarmId)) {
            debugPrint(
              '[ReminderTxn] SCHEDULE reminder ${currentReminder.id} alarmId=$alarmId (pre)',
            );
            final success = await _setAlarm(preAlarm);
            if (!success)
              throw StateError('Failed to schedule pre-alarm $alarmId');
            existingIds.add(alarmId);
          } else {
            debugPrint(
              '[ReminderTxn] SKIP IDEMPOTENT reminder ${currentReminder.id} pre-alarmId=$alarmId',
            );
          }

          newPendingIds.add(alarmId);
          currentReminder = currentReminder.copyWithScheduleMetadata(
            currentReminder.scheduleMetadata.copyWith(
              pendingAlarmIds: List.of(newPendingIds),
            ),
          );
          if (_saveReminder != null) await _saveReminder!(currentReminder);
        }

        // STEP 3 - Commit
        debugPrint(
          '[ReminderTxn] COMMIT scheduled reminder ${currentReminder.id}',
        );
        currentReminder = currentReminder.copyWithScheduleMetadata(
          currentReminder.scheduleMetadata.copyWith(
            alarmIds: newPendingIds.toList(),
            preAlarmIds: preAlarms.map((a) => a.id).toList(growable: false),
            pendingAlarmIds: [],
            txnStatus: TxnStatus.committed,
            lastResolutionStatus: ReminderResolutionStatus.scheduled,
            lastResolvedAt: DateTime.now().toUtc().toIso8601String(),
          ),
        );

        // PHASE H: Invariant Enforcement
        assert(
          currentReminder.scheduleMetadata.alarmIds.length <= 50,
          '[ReminderTxn][INVARIANT_VIOLATION] Limit exceeded',
        );
        assert(
          currentReminder.scheduleMetadata.alarmIds.toSet().length ==
              currentReminder.scheduleMetadata.alarmIds.length,
          '[ReminderTxn][INVARIANT_VIOLATION] Duplicates detected',
        );

        if (_saveReminder != null) {
          await _saveReminder!(currentReminder);
        }

        finalResult = ReminderAlarmTransactionResult(
          reminder: currentReminder,
          mainAlarms: mainAlarms,
          preAlarms: preAlarms,
        );
      } catch (error) {
        // In case of a hard crash during loop, the next app start will rollback via reconciliation.
        // But if it's just an exception being caught here, rollback immediately.
        await rollbackReminder(currentReminder);
        rethrow;
      }
    });

    return finalResult!;
  }

  Future<void> rollbackReminder(ReminderPayloadModel reminder) async {
    final ids = <int>{
      ...reminder.scheduleMetadata.alarmIds,
      ...reminder.scheduleMetadata.preAlarmIds,
      ...reminder.scheduleMetadata.pendingAlarmIds,
    };
    for (final id in ids) {
      try {
        await _stopAlarm(id);
      } catch (_) {}
    }

    // Also clear pending status if we are rolling back a failed transaction
    if (reminder.scheduleMetadata.txnStatus == TxnStatus.scheduling) {
      final rolledBack = reminder.copyWithScheduleMetadata(
        reminder.scheduleMetadata.copyWith(
          pendingAlarmIds: [],
          txnStatus: TxnStatus.idle,
        ),
      );
      if (_saveReminder != null) {
        await _saveReminder!(rolledBack);
      }
    }
  }

  AlarmSettings buildMainAlarm({
    required ReminderPayloadModel reminder,
    required DateTime scheduledTime,
    required int alarmId,
  }) {
    final category = reminder.category.trim().toLowerCase();

    return AlarmSettings(
      id: alarmId,
      dateTime: scheduledTime,
      assetAudioPath: _audioPathForCategory(category),
      loopAudio:
          category == 'medicine' || category == 'event' || category == 'meal',
      vibrate: category == 'medicine',
      androidFullScreenIntent: true,
      volumeSettings: VolumeSettings.fade(
        volume: 0.8,
        fadeDuration: const Duration(seconds: 5),
        volumeEnforced: true,
      ),
      payload: jsonEncode({
        'groupId': reminder.id.toString(),
        'category': category,
        'type':
            reminder.customReminder.type == Option.interval
                ? 'interval'
                : 'times',
        'startDate': reminder.startDate,
        'endDate': reminder.endDate,
        'remindBefore':
            reminder.remindBefore == null
                ? null
                : {
                  'time': reminder.remindBefore!.time,
                  'unit': reminder.remindBefore!.unit,
                },
        'scheduleMetadata': reminder.scheduleMetadata.toJson(),
      }),
      notificationSettings: NotificationSettings(
        title: _titleForReminder(reminder, category),
        body: _bodyForReminder(reminder, category),
        stopButton: 'Stop',
        icon: 'alarm',
        iconColor: AppColors.primaryColor,
      ),
    );
  }

  AlarmSettings buildPreAlarm({
    required ReminderPayloadModel reminder,
    required DateTime scheduledTime,
    required DateTime mainTime,
    required int alarmId,
  }) {
    final category = reminder.category.trim().toLowerCase();
    final before = reminder.remindBefore!;

    return AlarmSettings(
      id: alarmId,
      dateTime: scheduledTime,
      assetAudioPath: remindBeforeSound,
      loopAudio: false,
      allowAlarmOverlap: true,
      androidFullScreenIntent: true,
      volumeSettings: VolumeSettings.fade(
        fadeDuration: const Duration(seconds: 2),
      ),
      payload: jsonEncode({
        'groupId': reminder.id.toString(),
        'category': category,
        'type': 'before',
        'mainTime': mainTime.toIso8601String(),
        'scheduleMetadata': reminder.scheduleMetadata.toJson(),
      }),
      notificationSettings: NotificationSettings(
        title: 'Upcoming ${_titleForReminder(reminder, category)}',
        body:
            '${_beforeBodyForCategory(category)} ${before.time} ${before.unit}',
        stopButton: 'Stop',
        icon: 'alarm',
        iconColor: AppColors.primaryColor,
      ),
    );
  }

  String _audioPathForCategory(String category) {
    if (category.contains('water')) return waterSound;
    if (category.contains('meal')) return mealSound;
    if (category.contains('medicine')) return medicineSound;
    if (category.contains('event')) return eventSound;
    return alarmSound;
  }

  String _titleForReminder(ReminderPayloadModel reminder, String category) {
    final trimmed = reminder.title.trim();
    if (trimmed.isNotEmpty) return trimmed;
    switch (category) {
      case 'water':
        return 'WATER REMINDER';
      case 'meal':
        return 'MEAL REMINDER';
      case 'medicine':
        return 'MEDICINE REMINDER';
      case 'event':
        return 'EVENT REMINDER';
      default:
        return 'REMINDER';
    }
  }

  String _bodyForReminder(ReminderPayloadModel reminder, String category) {
    final notes = (reminder.notes ?? '').trim();
    if (category == 'medicine' && reminder.medicineNameSafe.isNotEmpty) {
      final dosage = reminder.dosage?.value ?? 0;
      final type = reminder.medicineType ?? '';
      final unit = reminder.dosage?.unit ?? '';
      switch (type) {
        case 'Tablet':
          return 'Take $dosage ${reminder.medicineNameSafe} tablet${dosage > 1 ? 's' : ''}.';
        case 'Syrup':
        case 'Injection':
        case 'Drops':
          return 'Take $dosage $unit of ${reminder.medicineNameSafe}.';
        default:
          return 'Take ${reminder.medicineNameSafe}.';
      }
    }
    if (notes.isNotEmpty) return notes;
    if (category == 'water') return 'Time to drink water!';
    return '';
  }

  String _beforeBodyForCategory(String category) {
    switch (category) {
      case 'event':
        return 'Your scheduled event will start in';
      case 'medicine':
        return 'It’s almost time to take your medicine in';
      default:
        return 'Reminder in';
    }
  }
}
