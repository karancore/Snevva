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
    debugPrint('🟡 RemindMeBefore value: ${eventRemindMeBefore.value}');

    if (eventRemindMeBefore.value != null) {
      debugPrint('🟢 Entered remindBefore block');

      final rawTime = eventTimeBeforeController.text.trim();
      debugPrint(
        '🕒remind before "$rawTime ${reminderController.selectedValue.value} $scheduledTime"',
      );

      int? time;
      try {
        time = int.parse(rawTime);
        debugPrint('🔢 Parsed time: $time');
      } catch (e) {
        debugPrint('❌ int.parse failed: $e');

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
        debugPrint('🚫 Invalid time (<= 0) detected');

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

      debugPrint('✅ Time valid, creating RemindBefore');
      debugPrint('📏 Unit selected: ${reminderController.selectedValue.value}');

      remindBefore = RemindBefore(
        time: time,
        unit: reminderController.selectedValue.value,
      );

      final timeOfDay = TimeOfDay(
        hour: scheduledTime.hour,
        minute: scheduledTime.minute,
      );

      await reminderController.handleRemindMeBefore(
        option: eventRemindMeBefore,
        timeOfDay: timeOfDay,
        timeController: reminderController.xTimeUnitController,
        unitController: reminderController.selectedValue,
        title: "Reminder before your event",
        body: "Your event is coming in ",
        category: "Event",
      );

      debugPrint('🎯 RemindBefore object created: $remindBefore');
    } else {
      debugPrint('⚠️ eventRemindMeBefore is NULL — block skipped');
    }
    final reminderId = DateTime.now().millisecondsSinceEpoch;

    final eventData = ReminderPayloadModel(
      id: reminderId,
      title: title,
      notes: notes.isNotEmpty ? notes : "",
      category: ReminderCategory.event.toString(),
      customReminder: CustomReminder(
        timesPerDay: TimesPerDay(
          count: 1.toString(),
          list: [scheduledTime.toString()],
        ),
      ),
      remindBefore: remindBefore,
    );
    debugPrint("Event Data: $eventData");
    final alarmSettings = AlarmSettings(
      id: id,
      dateTime: scheduledTime,
      assetAudioPath: alarmSound,
      loopAudio: true,
      volumeSettings: VolumeSettings.fade(
        volume: 0.8,
        fadeDuration: Duration(seconds: 5),
        volumeEnforced: true,
      ),
      notificationSettings: NotificationSettings(
        title: title.isNotEmpty ? title : 'EVENT REMINDER',
        body: notes.isNotEmpty ? notes : '',
        stopButton: 'Stop',
        icon: 'alarm',
        iconColor: AppColors.primaryColor,
      ),
    );

    final success = await Alarm.set(alarmSettings: alarmSettings);
    if (success) {
      // Reload list from Hive to ensure we have the latest data and don't override
      eventList.value = await reminderController.loadReminderList("event_list");
      final displayTitle =
      title.isNotEmpty ? title : 'MEAL REMINDER';



      eventList.add({displayTitle : alarmSettings});

      await reminderController.saveReminderList(eventList, "event_list");
      await reminderController.loadAllReminderLists();

      // Reload the combined list
      await reminderController.loadAllReminderLists();
      reminderController.addRemindertoAPI(eventData, context);

      reminderController.titleController.clear();
      reminderController.notesController.clear();
      eventTimeBeforeController.clear();
      eventRemindMeBefore.value = null;

      CustomSnackbar().showReminderBar(context);
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
