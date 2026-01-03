import 'dart:convert';

import 'package:alarm/alarm.dart';
import 'package:alarm/model/alarm_settings.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:snevva/Controllers/Reminder/reminder_controller.dart';

import '../../common/custom_snackbar.dart';
import '../../common/global_variables.dart';
import '../../consts/colors.dart';
import '../../consts/images.dart';
import '../../models/medicine_reminder_model.dart';

class MedicineController extends GetxController {
  ReminderController get reminderController => Get.find<ReminderController>();

  final medicineController = TextEditingController();
  var medicineNames = <String>[].obs;
  var medicineList = <MedicineReminderModel>[].obs;

  void addMedicine() {
    if (medicineController.text.isNotEmpty) {
      medicineNames.add(medicineController.text);
      medicineController.clear();
    }
  }

  void removeMedicine(int index) {
    medicineNames.removeAt(index);
  }

  Future<void> addMedicineAlarm(
    DateTime scheduledTime,
    BuildContext context,
  ) async {
    final alarmSettings = AlarmSettings(
      id: alarmsId(),
      dateTime: scheduledTime,
      assetAudioPath: alarmSound,
      loopAudio: true,
      vibrate: true,
      volumeSettings: VolumeSettings.fade(
        volume: 0.8,
        fadeDuration: Duration(seconds: 5),
        volumeEnforced: true,
      ),
      notificationSettings:
          reminderController.enableNotifications.value
              ? NotificationSettings(
                title:
                    reminderController.titleController.text.isNotEmpty
                        ? reminderController.titleController.text
                        : 'MEDICINE REMINDER',
                body:
                    'Take ${medicineNames.isNotEmpty ? medicineNames.join(", ") : "your medicine"}.',
                stopButton: 'Stop',
                icon: 'alarm',
                iconColor: AppColors.primaryColor,
              )
              : NotificationSettings(
                title: 'MEDICINE REMINDER',
                body: 'Take your medicine',
                stopButton: 'Stop',
                icon: 'alarm',
                iconColor: AppColors.primaryColor,
              ),
    );

    print('🔔 Setting alarm:');
    print('   ID: ${alarmSettings.id}');
    print('   Time: $scheduledTime');
    print('   Category: Medicine');
    print('   Title: ${reminderController.titleController.text}');

    final success = await Alarm.set(alarmSettings: alarmSettings);

    if (success) {
      // Reload list from Hive to ensure we have the latest data and don't override
      medicineList.value = await loadMedicineReminderList("medicine_list");

      medicineList.add(
        MedicineReminderModel(
          title: reminderController.titleController.text.trim(),
          note: reminderController.notesController.text.trim(),
          medicines: List<String>.from(medicineNames),
          alarm: alarmSettings,
        ),
      );

      final payload = reminderController.buildReminderPayload(
        category: "Medicine",
        id: alarmSettings.id,
      );

      await reminderController.addRemindertoAPI(payload, context);

      reminderController.titleController.clear();
      reminderController.notesController.clear();
      medicineController.clear();
      medicineNames.clear();
      await reminderController.saveReminderList(medicineList, "medicine_list");

      // Reload the combined list
      await reminderController.loadAllReminderLists();

      // CustomSnackbar.showSuccess(
      //   context: context,
      //   message: 'Success',
      //   title: 'Medicine reminder set successfully!',
      // );
      //
      // if (!mounted) return;

      CustomSnackbar().showReminderBar(context);

      Get.back(result: true);

      final allAlarms = await Alarm.getAlarms();
      print('   Total alarms active: ${allAlarms.length}');
    }
  }

  Future<void> updateMedicineAlarm(
    DateTime scheduledTime,
    BuildContext context,
    int alarmId,
  ) async {
    // 1. Re-set the alarm with the SAME ID
    final alarmSettings = AlarmSettings(
      id: alarmId,
      // <--- Key change: Reuse ID
      dateTime: scheduledTime,
      assetAudioPath: alarmSound,
      loopAudio: true,
      vibrate: true,
      volumeSettings: VolumeSettings.fade(
        volume: 0.8,
        fadeDuration: const Duration(seconds: 5),
        volumeEnforced: true,
      ),
      notificationSettings:
          reminderController.enableNotifications.value
              ? NotificationSettings(
                title:
                    reminderController.titleController.text.isNotEmpty
                        ? reminderController.titleController.text
                        : 'MEDICINE REMINDER',
                body:
                    'Take ${medicineNames.isNotEmpty ? medicineNames.join(", ") : "your medicine"}. ${reminderController.notesController.text}',
                stopButton: 'Stop',
                icon: 'alarm',
                iconColor: AppColors.primaryColor,
              )
              : NotificationSettings(
                title: 'MEDICINE REMINDER',
                body: '',
                stopButton: 'Stop',
                icon: 'alarm',
                iconColor: AppColors.primaryColor,
              ),
    );

    await Alarm.set(alarmSettings: alarmSettings);

    // 2. Update the List in Hive
    medicineList.value = await loadMedicineReminderList("medicine_list");

    await reminderController.updateReminder(
      reminderController.buildReminderPayload(
        category: reminderController.selectedCategory.value,
        id: reminderController.editingId.value,
      ),
      context,
    );

    // Create updated model
    final newModel = MedicineReminderModel(
      title: reminderController.titleController.text.trim(),
      note: reminderController.notesController.text.trim(),
      medicines: List<String>.from(medicineNames),
      alarm: alarmSettings,
    );

    // Find index and replace
    final index = medicineList.indexWhere((e) => e.alarm.id == alarmId);
    if (index != -1) {
      medicineList[index] = newModel;
    } else {
      medicineList.add(newModel); // Fallback if not found
    }

    // 3. Save and Refresh
    await reminderController.finalizeUpdate(
      context,
      "medicine_list",
      medicineList,
    );
  }

  Future<List<MedicineReminderModel>> loadMedicineReminderList(
    String keyName,
  ) async {
    final box = Hive.box('reminders_box');
    final List<dynamic>? storedList = box.get(keyName);

    if (storedList == null) return [];

    final List<String> stringList = storedList.cast<String>();

    List<MedicineReminderModel> loadedList = [];
    for (var item in stringList) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(item);

        // Check if it's the new format (has 'medicines' key)
        if (decoded.containsKey('medicines')) {
          loadedList.add(MedicineReminderModel.fromJson(decoded));
        } else {
          // Fallback for old format: {title: alarm_settings}
          final entry = decoded.entries.first;
          loadedList.add(
            MedicineReminderModel(
              title: entry.key,
              note: '', // Old format didn't have note
              medicines: [], // Old format didn't have medicines list
              alarm: AlarmSettings.fromJson(entry.value),
            ),
          );
        }
      } catch (e) {
        print("Error parsing medicine reminder: $e");
      }
    }
    return loadedList;
  }

  @override
  void onClose() {
    medicineController.dispose();
    medicineNames.clear();
    super.onClose();
  }
}
