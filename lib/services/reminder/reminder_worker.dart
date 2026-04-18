import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../../models/hive_models/reminder_payload_model.dart';
import '../app_initializer.dart';
import '../hive_service.dart';
import 'reconciliation_engine.dart';

/// Unique task name used by WorkManager to identify our periodic reminder job.
const String kReminderReconcileTask = 'com.coretegra.snevva.reminderReconcile';

/// One-shot task triggered by BootReceiver or manual request.
const String kReminderOneShotTask = 'com.coretegra.snevva.reminderOneShot';

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

/// Persists a single reminder update to the category-specific Hive list.
/// This is a minimal version that updates the schedule metadata without
/// needing the full ReminderController.
Future<void> _persistReminderToHive(ReminderPayloadModel reminder) async {
  try {
    final box = await HiveService().remindersBox();
    final category = reminder.category.trim().toLowerCase();
    final keyName = _hiveKeyForCategory(category);
    if (keyName == null) return;

    // Read existing list, find and update the matching reminder, write back
    final List<dynamic>? storedList = box.get(keyName);
    if (storedList == null) return;

    // For now, just persist the schedule metadata update.
    // The main app will do a full reconciliation on next launch.
    // Find the matching reminder by ID and replace it in-place.
    bool found = false;
    final updated = storedList.map((e) {
      if (e is ReminderPayloadModel && e.id == reminder.id) {
        found = true;
        return reminder;
      }
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
      networkType: NetworkType.not_required,
      requiresBatteryNotLow: false,
      requiresCharging: false,
      requiresDeviceIdle: false,
      requiresStorageNotLow: false,
    ),
    existingWorkPolicy: ExistingWorkPolicy.keep,
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
      networkType: NetworkType.not_required,
      requiresBatteryNotLow: false,
      requiresCharging: false,
      requiresDeviceIdle: false,
      requiresStorageNotLow: false,
    ),
    existingWorkPolicy: ExistingWorkPolicy.replace,
  );

  debugPrint('[ReminderWorker] One-shot reconciliation task enqueued');
}
