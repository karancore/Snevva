import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../../common/global_variables.dart';
import '../../models/hive_models/reminder_payload_model.dart';
import '../../models/reminder_schedule_metadata.dart';
import '../../models/reminders/medicine_reminder_model.dart' as med;
import '../../models/reminders/water_reminder_model.dart';
import '../app_initializer.dart';
import '../hive_service.dart';
import 'reconciliation_engine.dart';

/// Unique task name used by WorkManager to identify our periodic reminder job.
const String kReminderReconcileTask = 'com.coretegra.snevvaa.reminderReconcile';

/// One-shot task triggered by BootReceiver or manual request.
const String kReminderOneShotTask = 'com.coretegra.snevvaa.reminderOneShot';

/// The top-level callback dispatcher required by WorkManager.
/// Must be a top-level function (not a class method).
@pragma('vm:entry-point')
void reminderWorkerCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    debugPrint('[ReminderWorker] Task started: $taskName');

    try {
      WidgetsFlutterBinding.ensureInitialized();

      // Initialize minimal infrastructure needed for rescheduling
      await HiveService().initBackground();
      await ensureAlarmInitialized();

      // Build a save callback that persists to Hive directly
      // (we can't rely on GetX controllers in background isolate)
      final engine = ReconciliationEngine(
        saveReminder: (reminder) async {
          await _persistReminderToHive(reminder);
        },
        // Provide a Hive-based loader so reconcileAllReminders() works in
        // background isolates where GetX controllers are not registered.
        loadReminders: _loadRemindersFromHive,
      );

      await engine.reconcileAllReminders();

      debugPrint('[ReminderWorker] Task completed successfully: $taskName');
      return true;
    } catch (e, s) {
      debugPrint('[ReminderWorker] Task failed: $taskName — $e');
      debugPrint('[ReminderWorker] Stack: $s');
      return false;
    }
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// _loadRemindersFromHive — builds ReminderPayloadModel list from Hive without
// requiring GetX controllers or the full ReminderController infrastructure.
// ─────────────────────────────────────────────────────────────────────────────

Future<List<ReminderPayloadModel>> _loadRemindersFromHive() async {
  final box = await HiveService().remindersBox();
  // Use a map keyed by groupId to deduplicate (e.g. meals with multiple times)
  final reminders = <int, ReminderPayloadModel>{};

  // Medicine
  try {
    final raw = box.get('medicine_list');
    if (raw is List) {
      for (final item in raw) {
        if (item is! String) continue;
        try {
          final json = jsonDecode(item) as Map<String, dynamic>;
          final model = med.MedicineReminderModel.fromJson(
            json,
            timezoneIdFallback: 'local',
          );
          reminders[model.id] = _medicineToPayload(model);
        } catch (_) {}
      }
    }
  } catch (_) {}

  // Water
  try {
    final raw = box.get('water_list');
    if (raw is List) {
      for (final item in raw) {
        if (item is! String) continue;
        try {
          final json = jsonDecode(item) as Map<String, dynamic>;
          final model = WaterReminderModel.fromJson(json);
          if (!reminders.containsKey(model.id)) {
            reminders[model.id] = _waterToPayload(model);
          }
        } catch (_) {}
      }
    }
  } catch (_) {}

  // Meals and Events — stored as Map<title, AlarmSettings> JSON strings.
  // scheduleMetadata is embedded in the alarm payload field.
  for (final entry in [
    ('meals_list', 'meal'),
    ('event_list', 'event'),
  ]) {
    final (key, category) = entry;
    try {
      final raw = box.get(key);
      if (raw is! List) continue;
      for (final item in raw) {
        if (item is! String) continue;
        try {
          final outer = jsonDecode(item) as Map<String, dynamic>;
          final alarmJson = outer.values.firstOrNull;
          if (alarmJson is! Map<String, dynamic>) continue;
          final payloadStr = alarmJson['payload'] as String?;
          if (payloadStr == null) continue;
          final payload = jsonDecode(payloadStr) as Map<String, dynamic>;
          final groupId = int.tryParse(payload['groupId']?.toString() ?? '');
          if (groupId == null || reminders.containsKey(groupId)) continue;
          final rawMeta = payload['scheduleMetadata'];
          final meta = ReminderScheduleMetadata.fromJson(
            rawMeta is Map<String, dynamic>
                ? rawMeta
                : rawMeta is Map
                ? Map<String, dynamic>.from(rawMeta)
                : null,
            timezoneIdFallback: 'local',
            semanticsFallback: ScheduleSemantics.wallClock,
          );
          final alarmId = (alarmJson['id'] as num?)?.toInt();
          final dateTimeRaw = alarmJson['dateTime']?.toString();
          reminders[groupId] = ReminderPayloadModel(
            id: groupId,
            category: category,
            title: outer.keys.first,
            scheduleMetadata: meta.copyWith(
              alarmIds: alarmId != null ? [alarmId] : [],
            ),
            customReminder: CustomReminder(
              type: Option.times,
              timesPerDay: TimesPerDay(
                count: '1',
                list: dateTimeRaw != null ? [dateTimeRaw] : [],
              ),
            ),
          );
        } catch (_) {}
      }
    } catch (_) {}
  }

  debugPrint('[ReminderWorker] Loaded ${reminders.length} reminders from Hive');
  return reminders.values.toList();
}

ReminderPayloadModel _medicineToPayload(med.MedicineReminderModel model) {
  final isInterval = model.customReminder.type == Option.interval;
  return ReminderPayloadModel(
    id: model.id,
    category: 'medicine',
    title: model.title,
    medicineName: model.medicineName,
    medicineType: model.medicineType,
    whenToTake: model.whenToTake,
    dosage: Dosage(value: model.dosage.value, unit: model.dosage.unit),
    medicineFrequencyPerDay: model.medicineFrequencyPerDay,
    reminderFrequencyType: model.reminderFrequencyType,
    customReminder: CustomReminder(
      type: model.customReminder.type,
      timesPerDay:
      !isInterval && model.customReminder.timesPerDay != null
          ? TimesPerDay(
        count: model.customReminder.timesPerDay!.count,
        list: model.customReminder.timesPerDay!.list,
      )
          : null,
      everyXHours:
      isInterval && model.customReminder.everyXHours != null
          ? EveryXHours(
        hours:
        int.tryParse(
          model.customReminder.everyXHours!.hours,
        ) ??
            0,
        startTime: model.customReminder.everyXHours!.startTime,
        endTime: model.customReminder.everyXHours!.endTime,
      )
          : null,
    ),
    remindBefore:
    model.remindBefore != null
        ? RemindBefore(
      time: model.remindBefore!.time,
      unit: model.remindBefore!.unit,
    )
        : null,
    startDate: model.startDate,
    endDate: model.endDate,
    notes: model.notes,
    scheduleMetadata: model.scheduleMetadata,
  );
}

ReminderPayloadModel _waterToPayload(WaterReminderModel model) {
  final isInterval = model.type == Option.interval;
  return ReminderPayloadModel(
    id: model.id,
    category: 'water',
    title: model.title,
    notes: model.notes,
    startWaterTime: model.waterReminderStartTime,
    endWaterTime: model.waterReminderEndTime,
    customReminder: CustomReminder(
      type: model.type,
      everyXHours:
      isInterval && model.interval != null
          ? EveryXHours(
        hours: int.tryParse(model.interval!) ?? 0,
        startTime: model.waterReminderStartTime,
        endTime: model.waterReminderEndTime,
      )
          : null,
      timesPerDay:
      !isInterval
          ? TimesPerDay(count: model.timesPerDay, list: const [])
          : null,
    ),
    scheduleMetadata: model.scheduleMetadata,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _persistReminderToHive — updates scheduleMetadata on the matching Hive entry.
// ─────────────────────────────────────────────────────────────────────────────

Future<void> _persistReminderToHive(ReminderPayloadModel reminder) async {
  try {
    final box = await HiveService().remindersBox();
    final category = reminder.category.trim().toLowerCase();
    final keyName = _hiveKeyForCategory(category);
    if (keyName == null) return;

    final List<dynamic>? storedList = box.get(keyName);
    if (storedList == null) return;

    bool found = false;
    final updated = storedList.map((e) {
      if (e is! String) return e;
      try {
        final decoded = jsonDecode(e) as Map<String, dynamic>;
        // For medicine/water, the top-level 'id' field matches.
        // For meal/event stored as Map<title, AlarmSettings>, check inside the
        // alarm payload's groupId field.
        final directId = decoded['id'];
        if (directId != null) {
          final itemId =
          directId is int
              ? directId
              : int.tryParse(directId.toString());
          if (itemId == reminder.id) {
            found = true;
            return jsonEncode({
              ...decoded,
              'scheduleMetadata': reminder.scheduleMetadata.toJson(),
            });
          }
        } else {
          // meal/event: {"Title": {AlarmSettings JSON with payload}}
          final alarmVal = decoded.values.firstOrNull;
          if (alarmVal is Map<String, dynamic>) {
            final payloadStr = alarmVal['payload'] as String?;
            if (payloadStr != null) {
              final payload =
              jsonDecode(payloadStr) as Map<String, dynamic>;
              final groupId = int.tryParse(
                payload['groupId']?.toString() ?? '',
              );
              if (groupId == reminder.id) {
                found = true;
                final updatedPayload = jsonEncode({
                  ...payload,
                  'scheduleMetadata': reminder.scheduleMetadata.toJson(),
                });
                final updatedAlarm = {
                  ...alarmVal,
                  'payload': updatedPayload,
                };
                return jsonEncode({decoded.keys.first: updatedAlarm});
              }
            }
          }
        }
      } catch (_) {}
      return e;
    }).toList();

    if (!found) {
      debugPrint(
        '[ReminderWorker] ⚠️ Reminder ${reminder.id} not found in $keyName — skipping persist',
      );
      return;
    }

    await box.put(keyName, updated);
    debugPrint(
      '[ReminderWorker] ✅ Persisted reminder ${reminder.id} to Hive key "$keyName"',
    );
  } catch (e) {
    debugPrint('[ReminderWorker] _persistReminderToHive failed: $e');
  }
}

String? _hiveKeyForCategory(String category) {
  switch (category) {
    case 'medicine':
      return 'medicine_list';
    case 'meal':
      return 'meals_list';
    case 'event':
      return 'event_list';
    case 'water':
      return 'water_list';
    default:
      return null;
  }
}

/// Call this once during app initialization to register the periodic worker.
Future<void> initReminderWorker() async {
  await Workmanager().initialize(
    reminderWorkerCallbackDispatcher,
    isInDebugMode: false,
  );

  // Register a periodic task that runs approximately every 6 hours.
  // WorkManager guarantees execution even if the app is killed.
  await Workmanager().registerPeriodicTask(
    kReminderReconcileTask,
    kReminderReconcileTask,
    frequency: const Duration(hours: 6),
    constraints: Constraints(
      networkType: NetworkType.notRequired,
      requiresBatteryNotLow: false,
      requiresCharging: false,
      requiresDeviceIdle: false,
      requiresStorageNotLow: false,
    ),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    backoffPolicy: BackoffPolicy.exponential,
    backoffPolicyDelay: const Duration(minutes: 10),
  );

  debugPrint('[ReminderWorker] Periodic reconciliation worker registered (6h)');
}

/// Enqueue a one-shot immediate reconciliation (e.g., after boot).
Future<void> triggerImmediateReconciliation() async {
  await Workmanager().registerOneOffTask(
    kReminderOneShotTask,
    kReminderOneShotTask,
    constraints: Constraints(
      networkType: NetworkType.notRequired,
      requiresBatteryNotLow: false,
      requiresCharging: false,
      requiresDeviceIdle: false,
      requiresStorageNotLow: false,
    ),
    existingWorkPolicy: ExistingWorkPolicy.replace,
  );

  debugPrint('[ReminderWorker] One-shot reconciliation task enqueued');
}