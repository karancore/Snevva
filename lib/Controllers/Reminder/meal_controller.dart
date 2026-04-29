import 'dart:async';

import 'dart:convert';

import 'package:alarm/alarm.dart';
import 'package:snevva/services/reminder/native_alarm_bridge.dart';
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
    debugPrint("🍽️ [addMealAlarm] called");
    debugPrint("   ↳ incoming scheduledTime: $scheduledTime");
    debugPrint("   ↳ reminderIdOverride: $reminderIdOverride");

    final id = reminderIdOverride ?? alarmsId();
    debugPrint("   ↳ resolved alarm id: $id");

    final title = reminderController.titleController.text.trim();
    final notes = reminderController.notesController.text.trim();

    debugPrint("   ↳ title: '$title'");
    debugPrint("   ↳ notes: '$notes'");

    debugPrint("📦 [addMealAlarm] building schedule metadata...");
    final metadata = await reminderController.buildScheduleMetadata(
      category: 'meal',
      semantics: ScheduleSemantics.wallClock,
    );
    debugPrint("   ↳ metadata: $metadata");

    final isoString = scheduledTime.toIso8601String();
    final canonicalTime = canonicalLocalTime(isoString);
    final canonicalDate = canonicalLocalDate(isoString);

    debugPrint("   ↳ isoString: $isoString");
    debugPrint("   ↳ canonicalTime: $canonicalTime");
    debugPrint("   ↳ canonicalDate: $canonicalDate");

    final mealData = ReminderPayloadModel(
      id: id,
      category: "meal",
      title: title,
      notes: notes.isNotEmpty ? notes : "",
      customReminder: CustomReminder(
        type: Option.times,
        timesPerDay: TimesPerDay(count: 1.toString(), list: [canonicalTime]),
      ),
      startDate: canonicalDate,
      scheduleMetadata: metadata,
    );

    debugPrint("📤 [addMealAlarm] Meal Data Payload:");
    debugPrint("   ↳ $mealData");

    final alarmSettings = AlarmSettings(
      id: id,
      dateTime: scheduledTime,
      assetAudioPath: mealSound,
      loopAudio: true,
      androidFullScreenIntent: false,
      volumeSettings: VolumeSettings.fade(
        volume: 0.8,
        fadeDuration: Duration(seconds: 5),
        volumeEnforced: true,
      ),
      notificationSettings: NotificationSettings(
        title:
            title.isNotEmpty
                ? reminderController.titleController.text
                : 'MEAL REMINDER',
        body: notes,
        stopButton: 'Stop',
        icon: 'alarm',
        iconColor: AppColors.primaryColor,
      ),
    );

    debugPrint("🔔 [addMealAlarm] AlarmSettings created:");
    debugPrint("   ↳ id: ${alarmSettings.id}");
    debugPrint("   ↳ dateTime: ${alarmSettings.dateTime}");
    debugPrint("   ↳ title: ${alarmSettings.notificationSettings.title}");
    debugPrint("   ↳ body: ${alarmSettings.notificationSettings.body}");

    const success = true;

    if (success) {
      debugPrint("📲 [addMealAlarm] Arming alarm via NativeAlarmBridge...");

      try {
        await NativeAlarmBridge.armAlarm(
          alarmId: alarmSettings.id,
          epochMs: alarmSettings.dateTime.millisecondsSinceEpoch,
          groupId: id.toString(),
          category: 'meal',
          title: alarmSettings.notificationSettings.title,
          body: alarmSettings.notificationSettings.body,
        );

        debugPrint("✅ [addMealAlarm] Native alarm armed successfully");
      } catch (e, stack) {
        debugPrint("❌ [addMealAlarm] Native alarm FAILED");
        debugPrint("   ↳ error: $e");
        debugPrint("   ↳ stack: $stack");
      }

      debugPrint("📂 [addMealAlarm] Updating local meals list...");

      mealsList.value = await reminderController.loadReminderList("meals_list");
      debugPrint("   ↳ loaded mealsList count: ${mealsList.length}");

      final displayTitle = title.isNotEmpty ? title : 'MEAL REMINDER';
      mealsList.add({displayTitle: alarmSettings});

      debugPrint("   ↳ new mealsList count: ${mealsList.length}");

      await reminderController.saveReminderList(mealsList, "meals_list");
      debugPrint("   ↳ meals list saved");

      await reminderController.loadAllReminderLists();
      debugPrint("   ↳ all reminder lists reloaded");

      debugPrint("🌐 [addMealAlarm] Sending to API...");
      unawaited(
        reminderController
            .addRemindertoAPI(mealData, context)
            .then((_) {
              debugPrint("✅ [addMealAlarm] API success");
            })
            .catchError((e) {
              debugPrint("❌ [addMealAlarm] API failed: $e");
            }),
      );

      debugPrint("🧹 [addMealAlarm] Clearing input fields...");
      reminderController.titleController.clear();
      reminderController.notesController.clear();

      debugPrint("📢 [addMealAlarm] Showing snackbar + navigating back");
      CustomSnackbar().showReminderBar(context);
      Get.back(result: true);

      debugPrint("🏁 [addMealAlarm] COMPLETED");
    } else {
      debugPrint("❌ [addMealAlarm] success flag was false — nothing executed");
    }
  }

  Future<void> updateMealAlarm(
    DateTime scheduledTime,
    BuildContext context,
    int reminderId,
  ) async {
    debugPrint("══════════════════════════════════════════");
    debugPrint("🍽️ [MealAlarmUpdate] START");
    debugPrint("📌 Reminder ID: $reminderId");
    debugPrint("⏰ Scheduled Time (raw): $scheduledTime");
    debugPrint("⏰ Scheduled ISO: ${scheduledTime.toIso8601String()}");

    // 📥 LOAD LIST
    debugPrint("📥 Loading meals_list...");
    mealsList.value = await reminderController.loadReminderList("meals_list");
    debugPrint("📊 Meals list count: ${mealsList.length}");

    // 📝 INPUT FIELDS
    final title = reminderController.titleController.text.trim();
    final notes = reminderController.notesController.text.trim();

    debugPrint("📝 Title: '$title'");
    debugPrint("📝 Notes: '$notes'");

    // 🔍 FIND MATCHING ENTRIES
    debugPrint("🔍 Searching for existing reminder in meals list...");
    final matchedEntries = mealsList
        .where((entry) {
          final match = ReminderIdentity.matchesReminderId(
            entry.values.first,
            reminderId,
          );
          debugPrint("   ↳ Checking entry → Match: $match");
          return match;
        })
        .toList(growable: false);

    debugPrint("🔍 Matched entries count: ${matchedEntries.length}");

    final existingAlarm =
        matchedEntries.isEmpty ? null : matchedEntries.last.values.first;

    debugPrint("🔔 Existing Alarm Found: ${existingAlarm != null}");
    debugPrint("🔔 Existing Alarm ID: ${existingAlarm?.id}");

    // 📦 PAYLOAD PARSE
    Map<String, dynamic>? payload;
    try {
      payload =
          existingAlarm?.payload == null
              ? null
              : jsonDecode(existingAlarm!.payload!) as Map<String, dynamic>;

      debugPrint("📦 Payload parsed successfully");
    } catch (e) {
      debugPrint("❌ ERROR parsing payload: $e");
    }

    debugPrint("📦 Payload: $payload");

    // 🧠 METADATA
    final rawMetadata = payload?['scheduleMetadata'];
    debugPrint("🧠 Raw Metadata: $rawMetadata");

    final existingMetadata = ReminderScheduleMetadata.fromJson(
      rawMetadata is Map ? Map<String, dynamic>.from(rawMetadata) : null,
      timezoneIdFallback: 'UTC',
      semanticsFallback: ScheduleSemantics.wallClock,
    );

    debugPrint("🧠 Parsed Metadata:");
    debugPrint("   ↳ alarmIds: ${existingMetadata.alarmIds}");
    debugPrint("   ↳ preAlarmIds: ${existingMetadata.preAlarmIds}");
    debugPrint("   ↳ timezone: ${existingMetadata.timezoneId}");
    debugPrint("   ↳ scheduleSemantics: ${existingMetadata.scheduleSemantics}");

    // 🧱 BUILD NEW MODEL
    debugPrint("🧱 Building new ReminderPayloadModel...");

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

    debugPrint("🧱 New Model Built:");
    debugPrint("   ↳ ID: ${newModel.id}");
    debugPrint("   ↳ Category: ${newModel.category}");
    debugPrint("   ↳ Title: ${newModel.title}");
    debugPrint("   ↳ Notes: ${newModel.notes}");
    debugPrint("   ↳ Start Date: ${newModel.startDate}");
    debugPrint("   ↳ Times: ${newModel.customReminder.timesPerDay?.list}");
    debugPrint(
      "   ↳ Metadata alarmIds: ${newModel.scheduleMetadata?.alarmIds}",
    );

    // 🧨 STOP OLD ALARMS
    debugPrint("🧨 Collecting stale alarm IDs...");

    final staleAlarmIds =
        matchedEntries.map((entry) => entry.values.first.id).toSet()
          ..addAll(existingMetadata.alarmIds)
          ..addAll(existingMetadata.preAlarmIds);

    debugPrint("🧨 Total stale alarms to stop: ${staleAlarmIds.length}");
    debugPrint("🧨 Stale Alarm IDs: $staleAlarmIds");

    await reminderController.stopReminderAlarmIds(staleAlarmIds);

    // 🧹 CLEAN OLD ENTRY
    debugPrint("🧹 Removing old entries from mealsList...");
    final beforeCount = mealsList.length;

    mealsList.removeWhere(
      (entry) =>
          ReminderIdentity.matchesReminderId(entry.values.first, reminderId),
    );

    debugPrint(
      "🧹 Removed ${beforeCount - mealsList.length} entries | New count: ${mealsList.length}",
    );

    // ⏱️ SCHEDULE NEW REMINDER
    debugPrint("⏱️ Scheduling new reminder locally...");

    final transaction = await reminderController.scheduleReminderLocally(
      newModel,
    );

    debugPrint("⏱️ Schedule result:");
    debugPrint("   ↳ Main alarms count: ${transaction.mainAlarms.length}");
    debugPrint(
      "   ↳ Main alarm IDs: ${transaction.mainAlarms.map((a) => a.id).toList()}",
    );

    // ➕ ADD TO LIST
    final newItem = {title: transaction.mainAlarms.first};

    mealsList.add(newItem);

    debugPrint("➕ Added new item to mealsList");
    debugPrint("📊 Updated mealsList count: ${mealsList.length}");

    // 💾 FINALIZE LOCAL UPDATE
    debugPrint("💾 Finalizing local update...");

    await reminderController.finalizeUpdate(context, "meals_list", mealsList);

    debugPrint("✅ Local update finalized");

    // 🌐 BACKGROUND API UPDATE
    debugPrint("🌐 Triggering background API update...");

    reminderController.updateReminder(transaction.reminder, context).catchError(
      (e) {
        debugPrint("❌ API Update FAILED (background): $e");
      },
    );

    debugPrint("🏁 [MealAlarmUpdate] END");
    debugPrint("══════════════════════════════════════════");
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
