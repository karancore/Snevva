import 'package:snevva/Controllers/Reminder/event_controller.dart';
import 'package:snevva/Controllers/Reminder/meal_controller.dart';
import 'package:snevva/Controllers/Reminder/medicine_controller.dart';
import 'package:snevva/Controllers/Reminder/water_controller.dart';
import 'package:snevva/Controllers/WomenHealth/bottom_sheet_controller.dart';
import 'package:snevva/Controllers/local_storage_manager.dart';
import 'package:snevva/Controllers/signupAndSignIn/sign_up_controller.dart';
import 'package:snevva/services/notification_service.dart';
import 'Controllers/BMI/bmi_controller.dart';
import 'Controllers/DietPlan/diet_plan_controller.dart';
import 'Controllers/HealthTips/healthtips_controller.dart';
import 'Controllers/Hydration/hydration_stat_controller.dart';
import 'Controllers/MentalWellness/mental_wellness_controller.dart';
import 'Controllers/MoodTracker/mood_controller.dart';
import 'Controllers/MoodTracker/mood_questions_controller.dart';
import 'Controllers/ProfileSetupAndQuestionnare/profile_setup_controller.dart';
import 'Controllers/Reminder/reminder_controller.dart';
import 'Controllers/SleepScreen/sleep_controller.dart';
import 'Controllers/StepCounter/step_counter_controller.dart';
import 'Controllers/Vitals/vitalsController.dart';
import 'Controllers/WomenHealth/women_health_controller.dart';
import 'Controllers/alerts/alerts_controller.dart';
import 'Controllers/language/language_controller.dart';
import 'package:get/get.dart';
import 'Controllers/signupAndSignIn/sign_in_controller.dart';
import 'utils/theme_controller.dart';

class InitialBindings extends Bindings {
  @override
  void dependencies() {

    // 🌐 Core / App-wide
    Get.put(LocalStorageManager(), permanent: true);
    Get.put(NotificationService(), permanent: true);
    Get.put(LanguageController(), permanent: true);
    Get.put(AlertsController(), permanent: true);
    Get.put(ThemeController(), permanent: true);

    // 🧠 Health Core (permanent)
    Get.put(StepCounterController(), permanent: true);
    Get.put(SleepController(), permanent: true);
    Get.put(MoodController(), permanent: true);
    Get.put(VitalsController(), permanent: true);
    Get.put(WomenHealthController(), permanent: true);

    // 👤 User / Auth
    Get.put(SignInController(), permanent: true);
    Get.put(SignUpController() , permanent: true);
    Get.put(ProfileSetupController(), permanent: true);

    // 💧 Reminders (fenix = recreate if disposed)
    Get.lazyPut(() => ReminderController(), fenix: true);
    Get.lazyPut(() => WaterController(), fenix: true);
    Get.lazyPut(() => MedicineController(), fenix: true);
    Get.lazyPut(() => MealController(), fenix: true);
    Get.lazyPut(() => EventController(), fenix: true);

    // 📊 Feature controllers (screen-driven)
    Get.lazyPut(() => BmiController(), fenix: true);
    Get.lazyPut(() => DietPlanController(), fenix: true);
    Get.lazyPut(() => HealthTipsController(), fenix: true);
    Get.lazyPut(() => HydrationStatController(), fenix: true);
    Get.lazyPut(() => MentalWellnessController(), fenix: true);
    Get.lazyPut(() => MoodQuestionController(), fenix: true);
    Get.lazyPut(() => WomenHealthController() , fenix: true);

    // 🩺 UI helpers
    Get.lazyPut(() => BottomSheetController(), fenix: true);
  }
}

