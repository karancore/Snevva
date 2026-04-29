import 'dart:async';

import 'dart:convert';

import 'package:alarm/alarm.dart';
import 'package:snevva/services/reminder/native_alarm_bridge.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:snevva/Controllers/Reminder/reminder_controller.dart';
import 'package:snevva/Controllers/Reminder/water_controller.dart';
import 'package:snevva/models/hive_models/reminder_payload_model.dart';
import 'package:snevva/models/reminder_schedule_metadata.dart';
import 'package:snevva/services/reminder/reminder_identity.dart';
import 'package:snevva/services/reminder/reminder_schedule_resolver.dart';

import '../../common/custom_snackbar.dart';
import '../../common/global_variables.dart';
import '../../consts/colors.dart';

class EventController extends GetxController {
  ReminderController get reminderController =>
      Get.find<ReminderController>(tag: 'reminder');

  WaterController get waterController => Get.find<WaterController>();

  var eventList = <Map<String, AlarmSettings>>[].obs;

  RxnInt eventRemindMeBefore = RxnInt();
  final eventTimeBeforeController = TextEditingController();
  RxString eventUnit = 'minutes'.obs;

  String _resolvedStartDate(DateTime scheduledTime) {
    final startDateValue = reminderController.startDateString.value.trim();
    final source =
        (startDateValue.isEmpty || startDateValue == "Start Date")
            ? scheduledTime.toIso8601String()
            : startDateValue;
    return canonicalLocalDate(source) ??
        canonicalLocalDate(scheduledTime.toIso8601String())!;
  }

  Future<void> addEventAlarm(
    DateTime scheduledTime,
    BuildContext context, {
    int? reminderIdOverride,
  }) async {
    final id = reminderIdOverride ?? alarmsId();
    final title = reminderController.titleController.text.trim();
    final notes = reminderController.notesController.text.trim();
    final remindBefore = buildRemindBefore();

    debugPrint('🚀 Starting addEventAlarm');
    debugPrint('🆔 Generated Alarm ID: $id');
    debugPrint('⏰ Scheduled Time: $scheduledTime');
    debugPrint('🔔 Title: $title');
    debugPrint('🟡 RemindMeBefore value: ${eventRemindMeBefore.value}');

    if (eventRemindMeBefore.value == 0) {
      debugPrint('🟢 Entered remindBefore block');

      final rawTime = eventTimeBeforeController.text.trim();
      debugPrint('🕒 Raw time input: "$rawTime"');
      debugPrint('📏 Selected unit: ${reminderController.selectedValue.value}');

      int? time;
      try {
        time = int.parse(rawTime);
        debugPrint('🔢 Parsed time integer: $time');
      } catch (e) {
        debugPrint('❌ int.parse failed for "$rawTime": $e');

        Get.snackbar(
          'Invalid Input',
          'Please enter a valid remainder time',
          snackPosition: SnackPosition.TOP,
          colorText: white,
          backgroundColor: AppColors.primaryColor,
          duration: const Duration(seconds: 2),
        );
        return;
      }

      if (time <= 0) {
        debugPrint('🚫 Invalid time (<= 0) detected: $time');

        Get.snackbar(
          "Almost there",
          "Reminder time should be greater than zero",
          snackPosition: SnackPosition.TOP,
          colorText: white,
          backgroundColor: AppColors.primaryColor,
          duration: const Duration(seconds: 2),
        );
        return;
      }

      debugPrint('📦 RemindBefore Object created: ${remindBefore?.toJson()}');
    } else {
      debugPrint(
        '⚠️ eventRemindMeBefore is NULL — skipping remindBefore logic',
      );
    }

    // --- PAYLOAD DEBUGGING ---
    final startDateValue = reminderController.startDateString.value;
    debugPrint('📅 Payload startDate value: "$startDateValue"');

    final metadata = await reminderController.buildScheduleMetadata(
      category: 'event',
      semantics: ScheduleSemantics.absolute,
    );

    print("Resolved startDate: ${_resolvedStartDate(scheduledTime)}");
    final eventData = ReminderPayloadModel(
      id: id,
      category: "event",
      title: title,
      notes: notes,
      customReminder: CustomReminder(
        type: Option.times,
        timesPerDay: TimesPerDay(
          count: '1',
          list: [canonicalLocalTime(scheduledTime.toIso8601String())],
        ),
      ),
      remindBefore: remindBefore,
      startDate: _resolvedStartDate(scheduledTime),
      scheduleMetadata: metadata,
    );
    final transaction = await reminderController.scheduleReminderLocally(
      eventData,
    );

    eventList.value = await reminderController.loadReminderList("event_list");
    final displayTitle =
        title.isNotEmpty
            ? title
            : transaction.mainAlarms.first.notificationSettings.title;
    eventList.add({displayTitle: transaction.mainAlarms.first});

    await reminderController.saveReminderList(eventList, "event_list");
    await reminderController.loadAllReminderLists();
    unawaited(
      reminderController
          .addRemindertoAPI(transaction.reminder, context)
          .catchError((e) {
            debugPrint('⚠️ Background event add API failed: $e');
          }),
    );

    debugPrint('🧹 UI Controllers cleared');
    CustomSnackbar().showReminderBar(context);
    Get.back(result: true);
  }

  RemindBefore? buildRemindBefore() {
    if (eventRemindMeBefore.value != 0) return null;

    final rawTime = eventTimeBeforeController.text.trim();

    final time = int.tryParse(rawTime);
    if (time == null || time <= 0) return null;

    return RemindBefore(
      time: time,
      unit: reminderController.selectedValue.value,
    );
  }

  Future<void> updateEventAlarm(
    DateTime scheduledTime,
    BuildContext context,
    int reminderId,
  ) async {
    if (eventRemindMeBefore.value != null && eventRemindMeBefore.value == 0) {
      debugPrint('🟢 Entered remindBefore block');

      final rawTime = eventTimeBeforeController.text.trim();
      debugPrint('🕒 Raw time input: "$rawTime"');
      debugPrint('📏 Selected unit: ${reminderController.selectedValue.value}');

      int? time;
      try {
        time = int.parse(rawTime);
        debugPrint('🔢 Parsed time integer: $time');
      } catch (e) {
        debugPrint('❌ int.parse failed for "$rawTime": $e');

        Get.snackbar(
          'Invalid Input',
          'Please enter a valid remainder time',
          snackPosition: SnackPosition.TOP,
          colorText: white,
          backgroundColor: AppColors.primaryColor,
          duration: const Duration(seconds: 2),
        );
        return;
      }

      if (time <= 0) {
        debugPrint('🚫 Invalid time (<= 0) detected: $time');

        Get.snackbar(
          "Almost there",
          "Reminder time should be greater than zero",
          snackPosition: SnackPosition.TOP,
          colorText: white,
          backgroundColor: AppColors.primaryColor,
          duration: const Duration(seconds: 2),
        );
        return;
      }

      final remindBefore = buildRemindBefore();
      debugPrint('📦 RemindBefore Object created: ${remindBefore?.toJson()}');
    } else {
      debugPrint(
        '⚠️ eventRemindMeBefore is NULL — skipping remindBefore logic',
      );
    }
    eventList.value = await reminderController.loadReminderList("event_list");

    final title = reminderController.titleController.text.trim();
    final notes = reminderController.notesController.text.trim();
    final matchedEntries = eventList
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
      semanticsFallback: ScheduleSemantics.absolute,
    );

    final newModel = ReminderPayloadModel(
      id: reminderId,
      category: "event",
      title: title,
      notes: notes.isNotEmpty ? notes : "",
      customReminder: CustomReminder(
        type: Option.times,
        timesPerDay: TimesPerDay(
          count: 1.toString(),
          list: [canonicalLocalTime(scheduledTime.toIso8601String())],
        ),
      ),
      remindBefore: buildRemindBefore(),
      startDate: _resolvedStartDate(scheduledTime),
      scheduleMetadata: await reminderController.buildScheduleMetadata(
        category: 'event',
        semantics: ScheduleSemantics.absolute,
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
    eventList.removeWhere(
      (entry) =>
          ReminderIdentity.matchesReminderId(entry.values.first, reminderId),
    );
    final transaction = await reminderController.scheduleReminderLocally(
      newModel,
    );

    final newItem = {
      reminderController.titleController.text.trim():
          transaction.mainAlarms.first,
    };
    eventList.add(newItem);

    await reminderController.finalizeUpdate(context, "event_list", eventList);

    reminderController.updateReminder(transaction.reminder, context).catchError(
      (e) {
        debugPrint('⚠️ Background event update API failed: $e');
      },
    );
  }

  void resetForm() {
    // Clear text fields
    reminderController.titleController.clear();
    reminderController.notesController.clear();
    eventTimeBeforeController.clear();

    // Reset remind-before state
    eventRemindMeBefore.value = null;
    eventUnit.value = 'minutes';

    // Reset shared reminder controller state
    reminderController.selectedValue.value = 'minutes';
    reminderController.xTimeUnitController.clear();

    debugPrint('🔄 Event form reset completed');
  }

  @override
  void onClose() {
    resetForm();
    super.onClose();
  }
}
