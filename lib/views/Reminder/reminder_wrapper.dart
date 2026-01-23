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
    Get.put(WaterController(), permanent: true);
    Get.put(MealController(), permanent: true);
    Get.put(EventController(), permanent: true);
    Get.put(MedicineController(), permanent: true);

    // Lazily create the controller when this widget is first built
    final ReminderController controller = Get.put(
      ReminderController(),
      tag: 'reminder',
      permanent: true,
    );


    return ReminderScreen();
  }
}
