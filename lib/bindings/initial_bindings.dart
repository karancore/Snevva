import 'package:snevva/Controllers/local_storage_manager.dart';
import 'package:snevva/Controllers/signupAndSignIn/create_password_controller.dart';
import 'package:snevva/Controllers/signupAndSignIn/otp_verification_controller.dart';
import 'package:snevva/Controllers/signupAndSignIn/sign_up_controller.dart';
import '../Controllers/BMI/bmi_controller.dart';
import '../Controllers/DietPlan/diet_plan_controller.dart';
import '../Controllers/HealthTips/healthtips_controller.dart';
import '../Controllers/Hydration/hydration_stat_controller.dart';
import '../Controllers/MentalWellness/mental_wellness_controller.dart';
import '../Controllers/MoodTracker/mood_controller.dart';
import '../Controllers/MoodTracker/mood_questions_controller.dart';
import '../Controllers/ProfileSetupAndQuestionnare/profile_setup_controller.dart';
import '../Controllers/Reminder/event_controller.dart';
import '../Controllers/Reminder/meal_controller.dart';
import '../Controllers/Reminder/medicine_controller.dart';
import '../Controllers/Reminder/water_controller.dart';
import '../Controllers/SleepScreen/sleep_controller.dart';
import '../Controllers/StepCounter/step_counter_controller.dart';
import '../Controllers/Vitals/vitalsController.dart';
import '../Controllers/WomenHealth/bottom_sheet_controller.dart';
import '../Controllers/WomenHealth/women_health_controller.dart';
import '../Controllers/alerts/alerts_controller.dart';

import 'package:get/get.dart';
import '../Controllers/signupAndSignIn/forgot_password_controller.dart';
import '../Controllers/signupAndSignIn/sign_in_controller.dart';
import '../Controllers/signupAndSignIn/update_old_password_controller.dart';
import '../utils/theme_controller.dart';

class InitialBindings extends Bindings {
  @override
  void dependencies() {

    Get.put(LocalStorageManager(), permanent: true);

    Get.put(AlertsController(), permanent: true);



    // Auth
    if (!Get.isRegistered<SignInController>()) {
      Get.lazyPut(() => SignInController(), fenix: true);
    }
    if (!Get.isRegistered<SignUpController>()) {
      Get.lazyPut(() => SignUpController(), fenix: true);
    }
    if (!Get.isRegistered<OTPVerificationController>()) {
      Get.lazyPut(() => OTPVerificationController(), fenix: true);
    }
    if (!Get.isRegistered<UpdateOldPasswordController>()) {
      Get.lazyPut(() => UpdateOldPasswordController(), fenix: true);
    }
    if (!Get.isRegistered<CreatePasswordController>()) {
      Get.lazyPut(() => CreatePasswordController(), fenix: true);
    }
    if (!Get.isRegistered<ForgotPasswordController>()) {
      Get.lazyPut(() => ForgotPasswordController(), fenix: true);
    }
    if (!Get.isRegistered<ProfileSetupController>()) {
      Get.lazyPut(() => ProfileSetupController(), fenix: true);
    }

    // Health core (lazy, durable)
    if (!Get.isRegistered<MoodController>()) {
      Get.lazyPut(() => MoodController(), fenix: true);
    }
    if (!Get.isRegistered<WomenHealthController>()) {
      Get.lazyPut(() => WomenHealthController(), fenix: true);
    }




    if (!Get.isRegistered<StepCounterController>()) {
      Get.put(StepCounterController(), permanent: true);
    }

    // Feature
    if (!Get.isRegistered<BmiController>()) {
      Get.lazyPut(() => BmiController(), fenix: true);
    }
    if (!Get.isRegistered<DietPlanController>()) {
      Get.lazyPut(() => DietPlanController(), fenix: true);
    }
    if (!Get.isRegistered<HealthTipsController>()) {
      Get.lazyPut(() => HealthTipsController(), fenix: true);
    }
    if (!Get.isRegistered<HydrationStatController>()) {
      Get.lazyPut(() => HydrationStatController(), fenix: true);
    }
    if (!Get.isRegistered<MentalWellnessController>()) {
      Get.lazyPut(() => MentalWellnessController(), fenix: true);
    }

    Get.lazyPut(() => MoodQuestionController(), fenix: true);


    // UI
    //WOmen
    if (!Get.isRegistered<BottomSheetController>()) {
      Get.lazyPut(() => BottomSheetController(), fenix: true);
    }

    if (!Get.isRegistered<SleepController>()) {
      Get.put(SleepController(), permanent: true);
    }
  }
}
