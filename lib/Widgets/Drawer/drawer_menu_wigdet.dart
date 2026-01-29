import 'package:flutter_svg/svg.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/Controllers/DietPlan/diet_plan_controller.dart';
import 'package:snevva/Controllers/HealthTips/healthtips_controller.dart';
import 'package:snevva/Controllers/Hydration/hydration_stat_controller.dart';
import 'package:snevva/Controllers/MentalWellness/mental_wellness_controller.dart';
import 'package:snevva/Controllers/MoodTracker/mood_controller.dart';
import 'package:snevva/Controllers/MoodTracker/mood_questions_controller.dart';
import 'package:snevva/Controllers/ProfileSetupAndQuestionnare/profile_setup_controller.dart';
import 'package:snevva/Controllers/SleepScreen/sleep_controller.dart';
import 'package:snevva/Controllers/StepCounter/step_counter_controller.dart';
import 'package:snevva/Controllers/Vitals/vitalsController.dart';
import 'package:snevva/Controllers/local_storage_manager.dart';
import 'package:snevva/Controllers/signupAndSignIn/otp_verification_controller.dart';
import 'package:snevva/Controllers/signupAndSignIn/sign_in_controller.dart';
import 'package:snevva/env/env.dart';
import 'package:http/http.dart' as http;
import 'package:snevva/bindings/initial_bindings.dart';
import 'package:snevva/services/api_service.dart';
import 'package:snevva/services/auth_service.dart';
import 'package:snevva/views/ProfileAndQuestionnaire/edit_profile_screen.dart';
import 'package:snevva/views/Settings/settings_screen.dart';
import 'package:snevva/views/SignUp/sign_in_screen.dart';
import '../../Controllers/BMI/bmi_controller.dart';
import '../../Controllers/ProfileSetupAndQuestionnare/editprofile_controller.dart';
import '../../Controllers/Reminder/event_controller.dart';
import '../../Controllers/Reminder/meal_controller.dart';
import '../../Controllers/Reminder/medicine_controller.dart';
import '../../Controllers/Reminder/water_controller.dart';
import '../../Controllers/WomenHealth/bottom_sheet_controller.dart';
import '../../Controllers/WomenHealth/women_health_controller.dart';
import '../../Controllers/alerts/alerts_controller.dart';
import '../../Controllers/signupAndSignIn/create_password_controller.dart';
import '../../Controllers/signupAndSignIn/forgot_password_controller.dart';
import '../../Controllers/signupAndSignIn/sign_up_controller.dart';
import '../../Controllers/signupAndSignIn/update_old_password_controller.dart';
import '../../consts/consts.dart';
import '../../models/hive_models/steps_model.dart';
import '../home_wrapper.dart';
import 'drawer_menu_item.dart';

class DrawerMenuWidget extends StatelessWidget {
  const DrawerMenuWidget({super.key, this.height, this.width});

  final double? height;
  final double? width;

  Future<void> performLogout() async {
    debugPrint('🚪 Logout started');

    try {
      debugPrint('📡 Calling logout API...');
      final response = await ApiService.post(
        logout,
        null,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response) {
        debugPrint('❌ Logout API failed: ${response.statusCode}');
        throw Exception('API Error: ${response.statusCode}');
      }

      debugPrint('✅ Logout API success');
    } catch (e, st) {
      debugPrint('🔥 Exception during logout API');
      debugPrint('Error: $e');
      debugPrint('StackTrace: $st');
      rethrow;
    }

    debugPrint('🧹 Clearing SharedPreferences...');
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    debugPrint('✅ SharedPreferences cleared');

    debugPrint('🗄️ Clearing Hive step_history...');
    try {
      await Hive.box<StepEntry>('step_history').clear();
      debugPrint('✅ step_history cleared');
    } catch (e) {
      debugPrint('❌ Failed to clear step_history: $e');

      try {
        debugPrint('🔁 Retrying step_history clear...');
        await Hive.box<StepEntry>('step_history').clear();
        debugPrint('✅ step_history cleared on retry');
      } catch (e2) {
        debugPrint('❌ Second attempt failed: $e2');
      }
    }

    debugPrint('🧠 Resetting LocalStorageManager...');
    final localStorageManager = Get.find<LocalStorageManager>();

    localStorageManager.userMap.value = {};
    localStorageManager.userMap.refresh();

    localStorageManager.userGoalDataMap.value = {};
    localStorageManager.userGoalDataMap.refresh();

    debugPrint('✅ LocalStorageManager reset');

    debugPrint('🗑️ Deleting GetX controllers...');
    Get.delete<DietPlanController>();
    Get.delete<HealthTipsController>();
    Get.delete<HydrationStatController>();
    Get.delete<OTPVerificationController>();
    Get.delete<MentalWellnessController>();
    Get.delete<MoodController>();
    Get.delete<SignInController>();
    Get.delete<MoodQuestionController>();
    Get.delete<SleepController>();
    Get.delete<StepCounterController>();
    Get.delete<VitalsController>();
    debugPrint('✅ Controllers deleted');

    debugPrint('➡️ Navigating to SignInScreen');
    Get.offAll(() => SignInScreen());

    debugPrint('🏁 Logout completed successfully');
  }


  @override
  Widget build(BuildContext context) {
    final localStorageManager = Get.find<LocalStorageManager>();
    final initialProfileController = Get.put(ProfileSetupController());

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          width: double.infinity,
          decoration: BoxDecoration(gradient: AppColors.primaryGradient),
          child: Padding(
            padding: const EdgeInsets.only(top: 50),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Obx(() {
                  final pickedFile = initialProfileController.pickedImage.value;

                  return ClipOval(
                    child:
                        pickedFile != null
                            ? Image.file(
                              pickedFile,
                              height: 80,
                              width: 80,
                              fit: BoxFit.cover,
                            )
                            : Image.asset(
                              profileMainImg,
                              height: 80,
                              width: 80,
                              fit: BoxFit.cover,
                            ),
                  );
                }),
                const SizedBox(height: 8),
                Text(
                  localStorageManager.userMap['Name']?.toString() ?? 'User',
                  style: const TextStyle(color: Colors.white, fontSize: 24),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 40),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        DrawerMenuItem(
                          menuIcon: homeIcon,
                          itemName: 'Home',
                          onWidgetTap:
                              () => {
                                Get.back(),
                                Get.to(
                                  () => HomeWrapper(),
                                  binding: InitialBindings(),
                                ),
                              },
                        ),

                        DrawerMenuItem(
                          menuIcon: profileIcon,
                          itemName: 'Profile',
                          onWidgetTap:
                              () => {
                                Get.back(),
                                Get.to(() => EditProfileScreen()),
                              },
                        ),

                        // DrawerMenuItem(
                        //   menuIcon: addEmergencyContactIcon,
                        //   itemName: 'Emergency Contact',
                        //   onWidgetTap:
                        //       () => {Get.back(), Get.to(()=>EmergencyContact())},
                        // ),
                        DrawerMenuItem(
                          menuIcon: scannerIcon,
                          itemName: 'Scan Report ',
                          isDisabled: true,
                          onWidgetTap: () {}, // ignored because disabled
                        ),

                        // DrawerMenuItem(
                        //   menuIcon: appointmentIcon,
                        //   itemName: 'Appointment',
                        //   onWidgetTap:
                        //       () => {Get.back(), Get.to(()=>DocHaveAppointment())},
                        // ),
                        DrawerMenuItem(
                          menuIcon: gearIcon,
                          itemName: 'Settings',
                          onWidgetTap:
                              () => {
                                Get.back(),
                                Get.to(() => SettingsScreen()),
                              },
                        ),

                        DrawerMenuItem(
                          menuIcon:
                              invitefriend, // or another icon if not added yet
                          itemName: 'Invite a Friend',
                          onWidgetTap: () async {
                            Get.back();
                            const shareMessage =
                                '🎉 Hey! Check out this awesome app — Snevva! Download it here: https://play.google.com/store/apps/details?id=com.yourapp.id';
                            await Share.share(
                              shareMessage,
                              subject: 'Join me on Snevva!',
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                SafeArea(
                  child: Container(
                    margin: EdgeInsets.only(top: 20, bottom: 10),
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepPurple.withOpacity(0.18),
                          blurRadius: 12,
                          offset: Offset(0, 0),
                        ),
                      ],
                    ),
                    child: OutlinedButton(
                      onPressed: () async {
                        await performLogout();
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Color(0xFFF0E5FF),
                        side: BorderSide(color: Colors.transparent),
                        fixedSize: Size(width!, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset(logoutIcon, width: 24, height: 24),
                          SizedBox(width: 10),
                          Text(
                            "Log Out",
                            style: TextStyle(
                              fontSize: 18,
                              foreground:
                                  Paint()
                                    ..shader = AppColors.primaryGradient
                                        .createShader(
                                          Rect.fromLTWH(0, 0, 200, 70),
                                        ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
