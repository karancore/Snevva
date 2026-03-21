import 'dart:convert';

import 'package:alarm/alarm.dart';
import 'package:alarm/model/alarm_settings.dart';
import 'package:snevva/Controllers/Reminder/reminder_controller.dart';
import 'package:snevva/Controllers/Reminder/water_controller.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/models/hive_models/reminder_payload_model.dart';
import 'package:snevva/services/reminder/reminder_notification_profile.dart';

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
    BuildContext context,
  ) async {
    final reminderGroupId = alarmsId();
    final alarmId = buildAlarmId(
      groupId: reminderGroupId,
      time: scheduledTime,
      salt: 'meal',
    );
    final title = reminderController.titleController.text.trim();
    final notes = reminderController.notesController.text.trim();
    // Map<String, dynamic> mealData = {
    //   "alarmId": id,
    //   "category": "MEAL",
    //   "title": title.isNotEmpty ? title : "MEAL REMINDER",
    //   "notes": notes.isNotEmpty ? notes : "",
    //   "scheduledTime": scheduledTime.toIso8601String(),
    // };
    final mealData = ReminderPayloadModel(
      id: reminderGroupId,
      category: "meal",
      title: title,
      notes: notes.isNotEmpty ? notes : "",
      reminderFrequencyType: Option.times.name,
      customReminder: CustomReminder(
        type: Option.times,
        timesPerDay: TimesPerDay(
          count: '1',
          list: [scheduledTime.toIso8601String()],
        ),
      ),
    );
    print("Meal Data: $mealData");
    final alarmSettings = buildCriticalReminderAlarmSettings(
      id: alarmId,
      dateTime: scheduledTime,
      assetAudioPath: alarmSound,
      loopAudio: true,
      volumeSettings: VolumeSettings.fade(
        volume: 0.8,
        fadeDuration: const Duration(seconds: 5),
        volumeEnforced: true,
      ),
      payload: jsonEncode({
        "groupId": reminderGroupId.toString(),
        "category": "meal",
        "type": "times",
      }),
      notificationTitle:
          title.isNotEmpty
              ? reminderController.titleController.text
              : 'MEAL REMINDER',
      notificationBody: notes,
      iconColor: AppColors.primaryColor,
    );

    final success = await Alarm.set(alarmSettings: alarmSettings);
    if (success) {
      // Reload list from Hive to ensure we have the latest data and don't override
      mealsList.value = await reminderController.loadReminderList("meals_list");

      final displayTitle = title.isNotEmpty ? title : 'MEAL REMINDER';

      mealsList.add({displayTitle: alarmSettings});

      await reminderController.saveReminderList(mealsList, "meals_list");

      // Reload the combined list
      await reminderController.loadAllReminderLists();
      print("Meal data before API call: ${mealData.toJson()}");
      await reminderController.addRemindertoAPI(mealData, context);

      // CustomSnackbar.showSuccess(
      //   context: context,
      //   title: 'Success',
      //   message: 'Meal reminder set successfully!',
      // );
      reminderController.titleController.clear();
      reminderController.notesController.clear();
      CustomSnackbar().showReminderBar(context);
      Get.back(result: true);
    }
  }

  Future<void> updateMealAlarm(
    DateTime scheduledTime,
    BuildContext context,
    int alarmId,
  ) async {
    // Use same AlarmSettings logic as _addMealAlarm but with alarmId
    final alarmSettings = buildCriticalReminderAlarmSettings(
      id: alarmId,
      dateTime: scheduledTime,
      assetAudioPath: alarmSound,
      loopAudio: true,
      volumeSettings: VolumeSettings.fade(
        volume: 0.8,
        fadeDuration: const Duration(seconds: 5),
        volumeEnforced: true,
      ),
      notificationTitle:
          reminderController.titleController.text.isNotEmpty
              ? reminderController.titleController.text
              : 'MEAL REMINDER',
      notificationBody:
          reminderController.notesController.text.isNotEmpty
              ? reminderController.notesController.text
              : '',
      iconColor: AppColors.primaryColor,
    );

    await Alarm.set(alarmSettings: alarmSettings);

    // Find and replace in List
    mealsList.value = await reminderController.loadReminderList("meals_list");
    int index = -1;
    for (int i = 0; i < mealsList.length; i++) {
      if (mealsList[i].values.first.id == alarmId) {
        index = i;
        break;
      }
    }

    final newItem = {
      reminderController.titleController.text.trim(): alarmSettings,
    };
    if (index != -1) {
      mealsList[index] = newItem;
    } else {
      mealsList.add(newItem);
    }

    await reminderController.finalizeUpdate(context, "meals_list", mealsList);
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
