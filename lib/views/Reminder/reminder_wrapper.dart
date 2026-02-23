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
    Get.find<WaterController>();
    Get.find<MealController>();
    Get.find<EventController>();
    Get.find<MedicineController>();
    Get.find<ReminderController>(tag: 'reminder');

    return ReminderScreen();
  }
}
