import 'package:snevva/Controllers/local_storage_manager.dart';

import 'Controllers/DietPlan/diet_plan_controller.dart';
import 'Controllers/HealthTips/healthtips_controller.dart';
import 'Controllers/Hydration/hydration_stat_controller.dart';
import 'Controllers/MentalWellness/mentalwellnesscontroller.dart';
import 'Controllers/MoodTracker/mood_controller.dart';
import 'Controllers/MoodTracker/mood_questions_controller.dart';
import 'Controllers/ProfileSetupAndQuestionnare/editprofile_controller.dart';
import 'Controllers/ProfileSetupAndQuestionnare/height_and_weight_controller.dart';
import 'Controllers/ProfileSetupAndQuestionnare/profile_setup_controller.dart';
import 'Controllers/ProfileSetupAndQuestionnare/question_screen_controller.dart';
import 'Controllers/SleepScreen/sleep_controller.dart';
import 'Controllers/StepCounter/step_counter_controller.dart';
import 'Controllers/Vitals/vitalsController.dart';
import 'Controllers/language/language_controller.dart';
import 'Controllers/signupAndSignIn/otp_verification_controller.dart';
import 'Controllers/signupAndSignIn/update_old_password_controller.dart';
import 'package:get/get_instance/src/bindings_interface.dart';
import 'package:snevva/Controllers/Reminder/reminder_controller.dart';
import 'package:snevva/Controllers/ReportScan/scan_report_controller.dart';
import 'package:snevva/Controllers/signupAndSignIn/create_password_controller.dart';
import 'package:snevva/Controllers/signupAndSignIn/forgot_password_controller.dart';
import 'package:snevva/Controllers/signupAndSignIn/sign_in_controller.dart';
import 'package:snevva/Controllers/signupAndSignIn/sign_up_controller.dart';
import 'package:get/get.dart';

class InitialBindings extends Bindings {
  @override
  void dependencies() {
    // Lazy load ALL controllers - created only when needed
    // This prevents overlay errors and improves app startup time
    Get.lazyPut(() => SignUpController());
    Get.lazyPut(() => SignInController());
    Get.lazyPut(() => LocalStorageManager());

    Get.lazyPut(() => CreatePasswordController());
    Get.lazyPut(() => ForgotPasswordController());
    Get.lazyPut(() => OTPVerificationController());
    Get.lazyPut(() => UpdateOldPasswordController());
    Get.lazyPut(() => ReminderController());
    Get.lazyPut(() => DietPlanController());
    Get.lazyPut(() => HealthTipsController());
    Get.lazyPut(() => HydrationStatController());
    Get.lazyPut(() => MentalWellnesscontroller());
    Get.lazyPut(() => MoodController());
    Get.lazyPut(() => MoodQuestionController());
    Get.lazyPut(() => LanguageController());
    Get.lazyPut(() => EditprofileController());
    Get.lazyPut(() => HeightWeightController());
    Get.lazyPut(() => ProfileSetupController());
    Get.lazyPut(() => QuestionScreenController());
    Get.lazyPut(() => SleepController());
    Get.lazyPut(() => StepCounterController());
    Get.lazyPut(() => VitalsController());
  }
}