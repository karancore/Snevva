import 'package:get/get.dart';
import 'package:snevva/Controllers/Reminder/reminder_controller.dart';
import 'package:alarm/alarm.dart';
import 'package:alarm/model/alarm_settings.dart';
import 'package:flutter/material.dart';
import '../../common/custom_snackbar.dart';
import '../../common/global_variables.dart';
import '../../consts/colors.dart';
import '../../consts/images.dart';

class EventController extends GetxController {
  ReminderController get reminderController => Get.find<ReminderController>();
  var eventList = <Map<String, AlarmSettings>>[].obs;
  Future<void> addEventAlarm(
    DateTime scheduledTime,
    BuildContext context,
  ) async {
    final alarmSettings = AlarmSettings(
      id: alarmsId(),
      dateTime: scheduledTime,
      assetAudioPath: alarmSound,
      loopAudio: true,
      volumeSettings: VolumeSettings.fade(
        volume: 0.8,
        fadeDuration: Duration(seconds: 5),
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

    final success = await Alarm.set(alarmSettings: alarmSettings);
    if (success) {
      // Reload list from Hive to ensure we have the latest data and don't override
      eventList.value = await reminderController.loadReminderList("event_list");

      eventList.add({
        reminderController.titleController.text.trim(): alarmSettings,
      });
      reminderController.titleController.clear();
      reminderController.notesController.clear();
      await reminderController.saveReminderList(eventList, "event_list");

      // Reload the combined list
      await reminderController.loadAllReminderLists();

      CustomSnackbar.showSuccess(
        context: context,
        title: 'Success',
        message: 'Event reminder set successfully!',
      );
      Get.back(result: true);
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
}
