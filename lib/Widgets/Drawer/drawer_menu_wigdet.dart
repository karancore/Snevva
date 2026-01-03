import 'package:flutter_svg/svg.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/AuthBinding.dart';
import 'package:snevva/Controllers/DietPlan/diet_plan_controller.dart';
import 'package:snevva/Controllers/HealthTips/healthtips_controller.dart';
import 'package:snevva/Controllers/Hydration/hydration_stat_controller.dart';
import 'package:snevva/Controllers/MentalWellness/mentalwellnesscontroller.dart';
import 'package:snevva/Controllers/MoodTracker/mood_controller.dart';
import 'package:snevva/Controllers/MoodTracker/mood_questions_controller.dart';
import 'package:snevva/Controllers/ProfileSetupAndQuestionnare/profile_setup_controller.dart';
import 'package:snevva/Controllers/SleepScreen/sleep_controller.dart';
import 'package:snevva/Controllers/StepCounter/step_counter_controller.dart';
import 'package:snevva/Controllers/Vitals/vitalsController.dart';
import 'package:snevva/Controllers/local_storage_manager.dart';
import 'package:snevva/Controllers/signupAndSignIn/sign_in_controller.dart';
import 'package:snevva/Controllers/signupAndSignIn/sign_up_controller.dart';
import 'package:snevva/Widgets/home_wrapper.dart';
import 'package:snevva/initial_bindings.dart';
import 'package:snevva/models/steps_model.dart';
import 'package:snevva/views/ProfileAndQuestionnaire/edit_profile_screen.dart';
import 'package:snevva/views/Settings/settings_screen.dart';
import 'package:snevva/views/SignUp/sign_in_screen.dart';
import '../../consts/consts.dart';
import 'drawer_menu_item.dart';

class DrawerMenuWidget extends StatelessWidget {
  const DrawerMenuWidget({
    super.key,
    required this.height,
    required this.width,
  });

  final double height;
  final double width;

  Future<void> performLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    try {
      if (!Hive.isBoxOpen('step_history'))
        await Hive.openBox<StepEntry>('step_history');
      await Hive.box<StepEntry>('step_history').clear();
    } catch (e) {
      print('❌ Failed to clear step_history on logout: $e');
      // attempt reopen once
      try {
        await Hive.openBox<StepEntry>('step_history');
        await Hive.box<StepEntry>('step_history').clear();
      } catch (e2) {
        print('❌ Second attempt to clear step_history failed: $e2');
      }
    }

    final localStorageManager = Get.find<LocalStorageManager>();
    localStorageManager.userMap.value = {};
    localStorageManager.userMap.refresh();

    localStorageManager.userGoalDataMap.value = {};
    localStorageManager.userGoalDataMap.refresh();

    // ❌ REMOVE THIS
    // Get.deleteAll(force: true);

    // ✅ Delete only app controllers
    Get.delete<DietPlanController>();
    Get.delete<HealthTipsController>();
    Get.delete<HydrationStatController>();
    Get.delete<MentalWellnessController>();
    Get.delete<MoodController>();
    Get.delete<MoodQuestionController>();
    Get.delete<SleepController>();
    Get.delete<StepCounterController>();
    Get.delete<VitalsController>();

    Get.offAll(() => SignInScreen(), binding: AuthBinding());
  }

  @override
  Widget build(BuildContext context) {
    final localStorageManager = Get.put(LocalStorageManager());
    final initialProfileController = Get.put(ProfileSetupController());

    return Column(
      children: [
        Container(
          padding: EdgeInsets.only(left: 20),
          height: height / 4,
          width: double.infinity,
          decoration: BoxDecoration(gradient: AppColors.primaryGradient),
          child: Padding(
            padding: const EdgeInsets.only(top: 50),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
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
                        fixedSize: Size(width, 40),
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
