import 'package:alarm/alarm.dart';
import 'package:flutter/foundation.dart';

import '../../common/global_variables.dart';
import '../../models/hive_models/reminder_payload_model.dart';
import '../../models/reminder_schedule_metadata.dart';
import 'reminder_schedule_resolver.dart';
import 'reminder_alarm_transaction.dart';
import 'reminder_alarm_platform.dart';
import 'device_timezone_service.dart';
import 'native_alarm_bridge.dart';
import '../../Controllers/Reminder/reminder_controller.dart';
import 'package:get/get.dart';

class ReconciliationEngine {
  final ReminderScheduleResolver _resolver;
  final ReminderSaveCallback _saveReminder;
  final ReminderAlarmTransaction _transaction;

  ReconciliationEngine({
    ReminderScheduleResolver? resolver,
    required ReminderSaveCallback saveReminder,
    ReminderAlarmTransaction? transaction,
  }) : _resolver = resolver ?? const ReminderScheduleResolver(),
       _saveReminder = saveReminder,
       _transaction = transaction ?? ReminderAlarmTransaction(saveReminder: saveReminder);

  Future<void> reconcileReminder(ReminderPayloadModel reminder) async {
    await runWithLock("reminder_${reminder.id}", () async {
      // PHASE C: Sanitization
      final sanitizedMeta = reminder.scheduleMetadata.copyWith(
        alarmIds: sanitizeIds(reminder.scheduleMetadata.alarmIds),
        pendingAlarmIds: sanitizeIds(reminder.scheduleMetadata.pendingAlarmIds),
      );
      var currentReminder = reminder.copyWithScheduleMetadata(sanitizedMeta);
      
      // 1. Crash Recovery
      if (currentReminder.scheduleMetadata.txnStatus == TxnStatus.scheduling) {
        debugPrint('[ReminderTxn] Crash recovery triggered for ${currentReminder.id}');
        for (final id in currentReminder.scheduleMetadata.pendingAlarmIds) {
          try {
            await Alarm.stop(id);
          } catch (_) {}
        }
        currentReminder = currentReminder.copyWithScheduleMetadata(
          currentReminder.scheduleMetadata.copyWith(
            txnStatus: TxnStatus.idle,
            pendingAlarmIds: [],
          ),
        );
        await _saveReminder(currentReminder);
      }

    // 2. Pure Resolve
    final resolved = await _resolver.resolve(currentReminder);
    final expectedIdsMap = <int, AlarmSettings>{};

    for (var index = 0; index < resolved.mainTimes.length; index++) {
      final time = resolved.mainTimes[index];
      final id = computeAlarmId(
        reminderId: currentReminder.id,
        scheduleVersion: currentReminder.scheduleMetadata.scheduleVersion,
        fireTime: time,
        isPreAlarm: false,
      );
      expectedIdsMap[id] = _transaction.buildMainAlarm(
        reminder: currentReminder,
        scheduledTime: time,
        alarmId: id,
      );
    }

    for (var index = 0; index < resolved.preReminderTimes.length; index++) {
      final time = resolved.preReminderTimes[index];
      final id = computeAlarmId(
        reminderId: currentReminder.id,
        scheduleVersion: currentReminder.scheduleMetadata.scheduleVersion,
        fireTime: time,
        isPreAlarm: true,
      );
      final mainTime = index < resolved.mainTimes.length
          ? resolved.mainTimes[index]
          : resolved.mainTimes.first;
          
      expectedIdsMap[id] = _transaction.buildPreAlarm(
        reminder: currentReminder,
        scheduledTime: time,
        mainTime: mainTime,
        alarmId: id,
      );
    }

      // PHASE A: Deterministic Expected Tracking
      final lastExpected = resolved.mainTimes.isNotEmpty ? resolved.mainTimes.last : null;
      currentReminder = currentReminder.copyWithScheduleMetadata(
        currentReminder.scheduleMetadata.copyWith(
          lastExpectedFireAt: lastExpected?.toUtc().toIso8601String(),
        )
      );

      // PHASE A: Missed Detection & Guarded Reschedule
      final now = DateTime.now();
      final lastFiredStr = currentReminder.scheduleMetadata.lastFiredAt;
      final lastFired = lastFiredStr != null ? DateTime.parse(lastFiredStr).toLocal() : null;
      
      final missed = resolved.mainTimes.where((t) => 
        t.isBefore(now.subtract(const Duration(minutes: 2))) &&
        (lastFired == null || lastFired.isBefore(t))
      ).toList();

      final lastResolvedStr = currentReminder.scheduleMetadata.lastResolvedAt;
      final lastResolved = lastResolvedStr != null ? DateTime.parse(lastResolvedStr).toLocal() : DateTime(0);

      final shouldReschedule = missed.length >= 2 || now.difference(lastResolved) > const Duration(minutes: 10);
      
      if (shouldReschedule && missed.isNotEmpty) {
        debugPrint('[ReminderTxn][RECOVERY] reason=missed_fire reminder=${currentReminder.id}');
        // Reschedule Fully
        for (final id in currentReminder.scheduleMetadata.alarmIds) {
          try { await Alarm.stop(id); } catch (_) {}
        }
        await _transaction.schedule(currentReminder);
        return;
      }

      // 3. Diff
      final currentIds = Set<int>.from(currentReminder.scheduleMetadata.alarmIds);
      final expectedIds = expectedIdsMap.keys.toSet();
      final toAdd = expectedIds.difference(currentIds);
      final toRemove = currentIds.difference(expectedIds);

      if (toAdd.isEmpty && toRemove.isEmpty) {
        return; // No drift
      }

      logTxn({
        "reminderId": currentReminder.id,
        "phase": "reconcile",
        "toAdd": toAdd.length,
        "toRemove": toRemove.length,
      });

      // 4. Fix Operations
      for (final id in toRemove) {
        try {
          await Alarm.stop(id);
        } catch (_) {}
      }
      if (usesNativeReminderScheduling && toRemove.isNotEmpty) {
        await NativeAlarmBridge.cancelAlarms(toRemove.toList(growable: false));
      }

      for (final id in toAdd) {
         final alarm = expectedIdsMap[id]!;
         final success = await scheduleReminderAlarm(alarm);
         if (!success) {
           logTxn({
             "phase": "alarm_set_failed",
             "alarmId": id,
           });
           throw StateError('Failed during reconcile to set alarm $id');
         }
      }
      if (usesNativeReminderScheduling && expectedIdsMap.isNotEmpty) {
        await NativeAlarmBridge.saveAndArm(
          expectedIdsMap.values.toList(growable: false),
        );
      }

      // PHASE D: Strict Source of Truth Enforcement
      // NEVER merge partial updates. DB matches resolver output exactly.
      currentReminder = currentReminder.copyWithScheduleMetadata(
        currentReminder.scheduleMetadata.copyWith(
          alarmIds: expectedIds.toList(growable: false),
          lastResolvedAt: DateTime.now().toUtc().toIso8601String(),
          lastResolutionStatus: ReminderResolutionStatus.resolved,
        ),
      );

      // PHASE H: Invariant Enforcement
      assert(currentReminder.scheduleMetadata.alarmIds.length <= 50, '[ReminderTxn][INVARIANT_VIOLATION] Limit exceeded');
      assert(currentReminder.scheduleMetadata.alarmIds.toSet().length == currentReminder.scheduleMetadata.alarmIds.length, '[ReminderTxn][INVARIANT_VIOLATION] Duplicates detected');
      assert(currentReminder.scheduleMetadata.alarmIds.toSet().containsAll(expectedIds), '[ReminderTxn][INVARIANT_VIOLATION] Mismatch expected');

      await _saveReminder(currentReminder);
    });
  }

  Future<void> reconcileAllReminders() async {
    debugPrint('[ReminderTxn] Starting reconcileAllReminders...');
    try {
      final controller = Get.find<ReminderController>(tag: 'reminder');
      // Forcing reload to get latest local state
      await controller.loadAllReminderLists();
      final reminders = controller.reminders;
      for (final reminder in reminders) {
        try {
          await reconcileReminder(reminder);
        } catch (e) {
          debugPrint('[ReminderTxn] reconcileReminder failed for ${reminder.id}: $e');
        }
      }
    } catch (e) {
      debugPrint('[ReminderTxn] reconcileAllReminders error: $e');
    }
  }

  Future<void> handleTimezoneStartupChecks() async {
    final currentTz = await DeviceTimezoneService.instance.getTimeZoneId();
    final storedTz = await DeviceTimezoneService.instance.getLastKnownTimezone();
    final currentOffset = DateTime.now().timeZoneOffset.inMinutes;
    final storedOffset = await DeviceTimezoneService.instance.getLastKnownOffsetMinutes();
    
    if ((storedTz != null && currentTz != storedTz) || (storedOffset != null && currentOffset != storedOffset)) {
      debugPrint('[ReminderTxn] Timezone/DST changed: tz($storedTz -> $currentTz), offset($storedOffset -> $currentOffset)');
      await DeviceTimezoneService.instance.saveLastKnownTimezone(currentTz, currentOffset);
      
      final controller = Get.find<ReminderController>(tag: 'reminder');
      await controller.loadAllReminderLists();
      final reminders = List<ReminderPayloadModel>.from(controller.reminders);
      
      for (var reminder in reminders) {
        reminder = reminder.copyWithScheduleMetadata(
          reminder.scheduleMetadata.copyWith(
            timezoneId: currentTz,
            scheduleVersion: reminder.scheduleMetadata.scheduleVersion + 1,
          )
        );
        await _saveReminder(reminder);
      }
      
      await reconcileAllReminders();
    } else if (storedTz == null || storedOffset == null) {
      await DeviceTimezoneService.instance.saveLastKnownTimezone(currentTz, currentOffset);
      await reconcileAllReminders(); 
    } else {
      // Just reconcile locally for any background crashes out of sequence
      await reconcileAllReminders();
    }
  }
}
