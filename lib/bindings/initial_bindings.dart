import '../Controllers/MoodTracker/mood_questions_controller.dart';

import 'package:get/get.dart';

class InitialBindings extends Bindings {
  @override
  void dependencies() {
    //   Get.put(LocalStorageManager(), permanent: true);
    //
    // if (!Get.isRegistered<AlertsController>()) {
    //   Get.put(AlertsController(), permanent: true);
    // }
    //
    // // Auth
    // if (!Get.isRegistered<SignInController>()) {
    //   Get.lazyPut(() => SignInController(), fenix: true);
    // }
    // if (!Get.isRegistered<SignUpController>()) {
    //   Get.lazyPut(() => SignUpController(), fenix: true);
    // }
    // if (!Get.isRegistered<OTPVerificationController>()) {
    //   Get.lazyPut(() => OTPVerificationController(), fenix: true);
    // }
    // if (!Get.isRegistered<UpdateOldPasswordController>()) {
    //   Get.lazyPut(() => UpdateOldPasswordController(), fenix: true);
    // }
    // if (!Get.isRegistered<CreatePasswordController>()) {
    //   Get.lazyPut(() => CreatePasswordController(), fenix: true);
    // }
    // if (!Get.isRegistered<ForgotPasswordController>()) {
    //   Get.lazyPut(() => ForgotPasswordController(), fenix: true);
    // }
    // if (!Get.isRegistered<ProfileSetupController>()) {
    //   Get.lazyPut(() => ProfileSetupController(), fenix: true);
    // }
    //
    //
    // if (!Get.isRegistered<WomenHealthController>()) {
    //   Get.lazyPut(() => WomenHealthController(), fenix: true);
    // }
    //
    // Get.put(VitalsController(), permanent: true);
    // Get.put(HydrationStatController(), permanent: true);
    // Get.put(MoodController(), permanent: true);
    // Get.put(EditprofileController(), permanent: true);
    //
    // if (!Get.isRegistered<StepCounterController>()) {
    //   Get.put(StepCounterController(), permanent: true);
    // }
    //
    // // Feature
    // if (!Get.isRegistered<BmiController>()) {
    //   Get.lazyPut(() => BmiController(), fenix: true);
    // }
    // if (!Get.isRegistered<DietPlanController>()) {
    //   Get.lazyPut(() => DietPlanController(), fenix: true);
    // }
    // if (!Get.isRegistered<HealthTipsController>()) {
    //   Get.lazyPut(() => HealthTipsController(), fenix: true);
    // }
    //
    // if (!Get.isRegistered<MentalWellnessController>()) {
    //   Get.lazyPut(() => MentalWellnessController(), fenix: true);
    // }
    //
    Get.lazyPut(() => MoodQuestionController(), fenix: true);
    //
    //
    //
    // // UI
    // //WOmen
    // if (!Get.isRegistered<BottomSheetController>()) {
    //   Get.lazyPut(() => BottomSheetController(), fenix: true);
    // }
    // if (!Get.isRegistered<ThemeController>()) {
    //   Get.lazyPut(() => ThemeController(), fenix: true);
    // }
    //
    //
  }
}
