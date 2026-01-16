import 'package:alarm/alarm.dart';
import 'package:alarm/model/alarm_settings.dart';
import 'package:snevva/Controllers/Reminder/reminder_controller.dart';
import 'package:snevva/consts/consts.dart';

import '../../common/custom_snackbar.dart';
import '../../common/global_variables.dart';

class MealController extends GetxController {
  ReminderController get reminderController => Get.find<ReminderController>();
  var mealsList = <Map<String, AlarmSettings>>[].obs;
  Future<void> addMealAlarm(
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
                : 'MEAL REMINDER',
        body: reminderController.notesController.text,
        stopButton: 'Stop',
        icon: 'alarm',
        iconColor: AppColors.primaryColor,
      ),
    );

    final success = await Alarm.set(alarmSettings: alarmSettings);
    if (success) {
      // Reload list from Hive to ensure we have the latest data and don't override
      mealsList.value = await reminderController.loadReminderList("meals_list");

      mealsList.add({
        reminderController.titleController.text.trim(): alarmSettings,
      });
      reminderController.titleController.clear();
      reminderController.notesController.clear();
      await reminderController.saveReminderList(mealsList, "meals_list");

      // Reload the combined list
      await reminderController.loadAllReminderLists();

      // CustomSnackbar.showSuccess(
      //   context: context,
      //   title: 'Success',
      //   message: 'Meal reminder set successfully!',
      // );
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
    final alarmSettings = AlarmSettings(
      id: alarmId,
      dateTime: scheduledTime,
      assetAudioPath: alarmSound,
      loopAudio: true,
      volumeSettings: VolumeSettings.fade(
        volume: 0.8,
        fadeDuration: const Duration(seconds: 5),
        volumeEnforced: true,
      ),
      notificationSettings: NotificationSettings(
        title:
            reminderController.titleController.text.isNotEmpty
                ? reminderController.titleController.text
                : 'MEAL REMINDER',
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
}
