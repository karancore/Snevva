import 'package:snevva/Controllers/local_storage_manager.dart';

import 'Controllers/DietPlan/diet_plan_controller.dart';
import 'Controllers/HealthTips/healthtips_controller.dart';
import 'Controllers/Hydration/hydration_stat_controller.dart';
import 'Controllers/MentalWellness/mentalwellnesscontroller.dart';
import 'Controllers/MoodTracker/mood_controller.dart';
import 'Controllers/MoodTracker/mood_questions_controller.dart';
import 'Controllers/SleepScreen/sleep_controller.dart';
import 'Controllers/StepCounter/step_counter_controller.dart';
import 'Controllers/Vitals/vitalsController.dart';
import 'Controllers/language/language_controller.dart';
import 'package:get/get.dart';

class InitialBindings extends Bindings {
  @override
  void dependencies() {
    Get.put(LocalStorageManager(), permanent: true);
    Get.put(LanguageController(), permanent: true);

    Get.lazyPut(() => DietPlanController(), fenix: true);
    Get.lazyPut(() => HealthTipsController(), fenix: true);
    Get.lazyPut(() => HydrationStatController(), fenix: true);
    Get.lazyPut(() => MentalWellnessController(), fenix: true);
    Get.lazyPut(() => MoodController(), fenix: true);
    Get.lazyPut(() => MoodQuestionController(), fenix: true);
    Get.lazyPut(() => SleepController(), fenix: true);
    Get.lazyPut(() => StepCounterController(), fenix: true);
    Get.lazyPut(() => VitalsController(), fenix: true);
  }
}
