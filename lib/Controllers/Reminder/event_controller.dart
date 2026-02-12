import 'dart:convert';

import 'package:get/get.dart';
import 'package:snevva/Controllers/Reminder/reminder_controller.dart';
import 'package:alarm/alarm.dart';
import 'package:alarm/model/alarm_settings.dart';
import 'package:flutter/material.dart';
import 'package:snevva/Controllers/Reminder/water_controller.dart';
import 'package:snevva/models/hive_models/reminder_payload_model.dart';
import '../../common/custom_snackbar.dart';
import '../../common/global_variables.dart';
import '../../consts/colors.dart';
import '../../consts/images.dart';

class EventController extends GetxController {
  ReminderController get reminderController =>
      Get.find<ReminderController>(tag: 'reminder');

  WaterController get waterController => Get.find<WaterController>();

  var eventList = <Map<String, AlarmSettings>>[].obs;

  RxnInt eventRemindMeBefore = RxnInt();
  final eventTimeBeforeController = TextEditingController();
  RxString eventUnit = 'minutes'.obs;

  Future<void> addEventAlarm(
    DateTime scheduledTime,
    BuildContext context,
  ) async {
    final id = alarmsId();
    final title = reminderController.titleController.text.trim();
    final notes = reminderController.notesController.text.trim();
    RemindBefore? remindBefore;

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

      remindBefore = RemindBefore(
        time: time,
        unit: reminderController.selectedValue.value,
      );
      debugPrint('📦 RemindBefore Object created: ${remindBefore.toJson()}');

      final timeOfDay = TimeOfDay(
        hour: scheduledTime.hour,
        minute: scheduledTime.minute,
      );

      // debugPrint('🔄 Calling add event alarm handleRemindMeBefore...');
      // await reminderController.handleRemindMeBefore(
      //   option: eventRemindMeBefore,
      //   timeOfDay: timeOfDay,
      //   timeController: eventTimeBeforeController,
      //   unitController: reminderController.selectedValue,
      //   title: "Reminder before your event",
      //   body: "Your event is coming in ",
      //   category: "event",
      // );
    } else {
      debugPrint(
        '⚠️ eventRemindMeBefore is NULL — skipping remindBefore logic',
      );
    }

    // --- PAYLOAD DEBUGGING ---
    final startDateValue = reminderController.startDateString.value;
    debugPrint('📅 Payload startDate value: "$startDateValue"');

    final payloadData = {
      "startDate": startDateValue,
      "remindBefore": remindBefore?.toJson(),
    };
    final encodedPayload = jsonEncode(payloadData);
    debugPrint('📤 Encoded Payload: $encodedPayload');

    final alarmSettings = AlarmSettings(
      id: id,
      dateTime: scheduledTime,
      assetAudioPath: alarmSound,
      loopAudio: true,
      volumeSettings: VolumeSettings.fade(
        volume: 0.8,
        fadeDuration: const Duration(seconds: 5),
        volumeEnforced: true,
      ),
      payload: encodedPayload,
      notificationSettings: NotificationSettings(
        title: title.isNotEmpty ? title : 'EVENT REMINDER',
        body: notes.isNotEmpty ? notes : '',
        stopButton: 'Stop',
        icon: 'alarm',
        iconColor: AppColors.primaryColor,
      ),
    );

    debugPrint('📡 Setting alarm via Alarm.set...');
    final success = await Alarm.set(alarmSettings: alarmSettings);

    if (success) {
      debugPrint('✅ Alarm set successfully!');

      eventList.value = await reminderController.loadReminderList("event_list");
      debugPrint('📚 Event list loaded. Current count: ${eventList.length}');

      final displayTitle = title.isNotEmpty ? title : 'EVENT REMINDER';
      eventList.add({displayTitle: alarmSettings});

      await reminderController.saveReminderList(eventList, "event_list");
      debugPrint('💾 Event list saved to storage');

      await reminderController.loadAllReminderLists();

      // Cleaning up
      debugPrint('🧹 UI Controllers cleared');

      CustomSnackbar().showReminderBar(context);
      Get.back(result: true);
    } else {
      debugPrint('❌ Alarm.set returned FALSE');
    }
  }

  Future<void> updateEventAlarm(
    DateTime scheduledTime,
    BuildContext context,
    int alarmId,
  ) async {
    // Use same AlarmSettings logic as _addEventAlarm but with alarmId
    final alarmSettings = AlarmSettings(
      id: alarmId,
      dateTime: scheduledTime,
      assetAudioPath: alarmSound,
      loopAudio: true,
      androidFullScreenIntent: true,
      volumeSettings: VolumeSettings.fade(
        volume: 0.8,
        fadeDuration: const Duration(seconds: 5),
        volumeEnforced: true,
      ),
      notificationSettings: NotificationSettings(
        title:
            reminderController.titleController.text.isNotEmpty
                ? reminderController.titleController.text
                : 'EVENT REMINDER',
        body:
            reminderController.notesController.text.isNotEmpty
                ? reminderController.notesController.text
                : '',
        stopButton: 'Stop',
        icon: 'alarm',
        iconColor: AppColors.primaryColor,
      ),
    );

    await Alarm.set(alarmSettings: alarmSettings);

    eventList.value = await reminderController.loadReminderList("event_list");
    int index = -1;
    for (int i = 0; i < eventList.length; i++) {
      if (eventList[i].values.first.id == alarmId) {
        index = i;
        break;
      }
    }

    final newItem = {
      reminderController.titleController.text.trim(): alarmSettings,
    };
    if (index != -1) {
      eventList[index] = newItem;
    } else {
      eventList.add(newItem);
    }

    await reminderController.finalizeUpdate(context, "event_list", eventList);
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
