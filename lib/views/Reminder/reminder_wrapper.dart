import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../Controllers/Reminder/event_controller.dart';
import '../../Controllers/Reminder/meal_controller.dart';
import '../../Controllers/Reminder/medicine_controller.dart';
import '../../Controllers/Reminder/reminder_controller.dart';
import '../../Controllers/Reminder/water_controller.dart';
import 'reminder_screen.dart';

class ReminderScreenWrapper extends StatelessWidget {
  const ReminderScreenWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<WaterController>()) {
      Get.put(WaterController(), permanent: true);
    }

    if (!Get.isRegistered<MealController>()) {
      Get.put(MealController(), permanent: true);
    }

    if (!Get.isRegistered<EventController>()) {
      Get.put(EventController(), permanent: true);
    }

    if (!Get.isRegistered<MedicineController>()) {
      Get.put(MedicineController(), permanent: true);
    }

    if (!Get.isRegistered<ReminderController>(tag: 'reminder')) {
      Get.put(ReminderController(), tag: 'reminder', permanent: true);
    } else {
      Get.find<ReminderController>(tag: 'reminder');
    }

    return ReminderScreen();
  }
}
