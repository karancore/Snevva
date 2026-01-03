import 'package:snevva/Controllers/Reminder/event_controller.dart';
import 'package:snevva/Controllers/Reminder/meal_controller.dart';
import 'package:snevva/Controllers/Reminder/medicine_controller.dart';
import 'package:snevva/Controllers/Reminder/water_controller.dart';
import 'package:snevva/Controllers/local_storage_manager.dart';

import 'Controllers/DietPlan/diet_plan_controller.dart';
import 'Controllers/HealthTips/healthtips_controller.dart';
import 'Controllers/Hydration/hydration_stat_controller.dart';
import 'Controllers/MentalWellness/mentalwellnesscontroller.dart';
import 'Controllers/MoodTracker/mood_controller.dart';
import 'Controllers/MoodTracker/mood_questions_controller.dart';
import 'Controllers/Reminder/reminder_controller.dart';
import 'Controllers/Vitals/vitalsController.dart';
import 'Controllers/language/language_controller.dart';
import 'package:get/get.dart';
import 'utils/theme_controller.dart';

class InitialBindings extends Bindings {
  @override
  void dependencies() {
    Get.put(LocalStorageManager(), permanent: true);
    Get.put(LanguageController(), permanent: true);
    Get.put(ThemeController(), permanent: true);
    Get.lazyPut<ReminderController>(() => ReminderController(), fenix: true);
    Get.lazyPut<WaterController>(() => WaterController(), fenix: true);
    Get.lazyPut<MedicineController>(() => MedicineController(), fenix: true);
    Get.lazyPut<MealController>(() => MealController(), fenix: true);
    Get.lazyPut<EventController>(() => EventController(), fenix: true);

    Get.lazyPut(() => DietPlanController(), fenix: true);
    Get.lazyPut(() => HealthTipsController(), fenix: true);
    Get.lazyPut(() => HydrationStatController(), fenix: true);
    Get.lazyPut(() => MentalWellnessController(), fenix: true);
    Get.lazyPut(() => MoodController(), fenix: true);
    Get.lazyPut(() => MoodQuestionController(), fenix: true);
    // SleepController is registered at app initialization (app_initializer)
    // to ensure a single permanent instance is used application-wide.
    // Get.lazyPut(() => SleepController(), fenix: true);
    // StepCounterController is registered early in app initializer to ensure
    // the same permanent instance is used across the app. Avoid duplicate
    // registrations here.
    Get.lazyPut(() => VitalsController(), fenix: true);
  }
}
