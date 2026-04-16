import 'dart:async';

import 'dart:convert';

import 'package:alarm/alarm.dart';
import 'package:snevva/Controllers/Reminder/reminder_controller.dart';
import 'package:snevva/Controllers/Reminder/water_controller.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/models/hive_models/reminder_payload_model.dart';
import 'package:snevva/models/reminder_schedule_metadata.dart';
import 'package:snevva/services/reminder/reminder_identity.dart';
import 'package:snevva/services/reminder/reminder_schedule_resolver.dart';

import '../../common/custom_snackbar.dart';
import '../../common/global_variables.dart';

class MealController extends GetxController {
  ReminderController get reminderController =>
      Get.find<ReminderController>(tag: 'reminder');

  WaterController get waterController => Get.find<WaterController>();

  final timeController = TextEditingController();
  var mealsList = <Map<String, AlarmSettings>>[].obs;

  Future<void> addMealAlarm(
    DateTime scheduledTime,
    BuildContext context, {
    int? reminderIdOverride,
  }) async {
    final id = reminderIdOverride ?? alarmsId();
    final title = reminderController.titleController.text.trim();
    final notes = reminderController.notesController.text.trim();
    final metadata = await reminderController.buildScheduleMetadata(
      category: 'meal',
      semantics: ScheduleSemantics.wallClock,
    );
    final mealData = ReminderPayloadModel(
      id: id,
      category: "meal",
      title: title,
      notes: notes.isNotEmpty ? notes : "",
      customReminder: CustomReminder(
        type: Option.times,
        timesPerDay: TimesPerDay(
          count: 1.toString(),
          list: [canonicalLocalTime(scheduledTime.toIso8601String())],
        ),
      ),
      startDate: canonicalLocalDate(scheduledTime.toIso8601String()),
      scheduleMetadata: metadata,
    );
    final transaction = await reminderController.scheduleReminderLocally(
      mealData,
    );
    final scheduledReminder = transaction.reminder;

    mealsList.value = await reminderController.loadReminderList("meals_list");
    final displayTitle =
        title.isNotEmpty
            ? title
            : transaction.mainAlarms.first.notificationSettings.title;

    mealsList.add({displayTitle: transaction.mainAlarms.first});

    await reminderController.saveReminderList(mealsList, "meals_list");
    await reminderController.loadAllReminderLists();
    unawaited(
      reminderController
          .addRemindertoAPI(scheduledReminder, context)
          .catchError((_) {}),
    );

    reminderController.titleController.clear();
    reminderController.notesController.clear();
    CustomSnackbar().showReminderBar(context);
    Get.back(result: true);
  }

  Future<void> updateMealAlarm(
    DateTime scheduledTime,
    BuildContext context,
    int reminderId,
  ) async {
    mealsList.value = await reminderController.loadReminderList("meals_list");

    final title = reminderController.titleController.text.trim();
    final notes = reminderController.notesController.text.trim();
    final matchedEntries = mealsList
        .where(
          (entry) => ReminderIdentity.matchesReminderId(
            entry.values.first,
            reminderId,
          ),
        )
        .toList(growable: false);
    final existingAlarm =
        matchedEntries.isEmpty ? null : matchedEntries.last.values.first;
    final payload =
        existingAlarm?.payload == null
            ? null
            : jsonDecode(existingAlarm!.payload!) as Map<String, dynamic>;
    final existingMetadata = ReminderScheduleMetadata.fromJson(
      payload?['scheduleMetadata'] is Map
          ? Map<String, dynamic>.from(payload!['scheduleMetadata'] as Map)
          : null,
      timezoneIdFallback: 'UTC',
      semanticsFallback: ScheduleSemantics.wallClock,
    );

    final newModel = ReminderPayloadModel(
      id: reminderId,
      category: "meal",
      title: title,
      notes: notes.isNotEmpty ? notes : "",
      customReminder: CustomReminder(
        type: Option.times,
        timesPerDay: TimesPerDay(
          count: 1.toString(),
          list: [canonicalLocalTime(scheduledTime.toIso8601String())],
        ),
      ),
      startDate: canonicalLocalDate(scheduledTime.toIso8601String()),
      scheduleMetadata: await reminderController.buildScheduleMetadata(
        category: 'meal',
        semantics: ScheduleSemantics.wallClock,
        existing: existingMetadata,
      ),
    );

    final staleAlarmIds =
        matchedEntries.map((entry) => entry.values.first.id).toSet()
          ..addAll(existingMetadata.alarmIds)
          ..addAll(existingMetadata.preAlarmIds);
    for (final staleAlarmId in staleAlarmIds) {
      await Alarm.stop(staleAlarmId);
    }
    mealsList.removeWhere(
      (entry) =>
          ReminderIdentity.matchesReminderId(entry.values.first, reminderId),
    );
    final transaction = await reminderController.scheduleReminderLocally(
      newModel,
    );

    final newItem = {title: transaction.mainAlarms.first};
    mealsList.add(newItem);

    await reminderController.finalizeUpdate(context, "meals_list", mealsList);

    reminderController.updateReminder(transaction.reminder, context).catchError(
      (e) {
        debugPrint('⚠️ Background meal update API failed: $e');
      },
    );
  }

  void resetForm() {
    timeController.clear();
    reminderController.titleController.clear();
    reminderController.notesController.clear();

    debugPrint('🔄 Meal form reset completed');
  }

  @override
  void onClose() {
    timeController.dispose();
    super.onClose();
  }
}
