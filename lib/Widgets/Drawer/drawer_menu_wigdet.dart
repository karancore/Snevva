import 'dart:async';
import 'package:alarm/alarm.dart';
import 'package:flutter_svg/svg.dart';
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
import 'package:snevva/services/background_pedometer_service.dart';
import 'package:snevva/services/decisiontree_service.dart';
import 'package:snevva/services/app_initializer.dart';
import 'package:snevva/common/agent_debug_logger.dart';
import 'package:snevva/services/hive_service.dart';
import 'package:snevva/views/ProfileAndQuestionnaire/edit_profile_screen.dart';
import 'package:snevva/views/Settings/settings_screen.dart';
import 'package:snevva/views/SignUp/sign_in_screen.dart';
import '../../consts/consts.dart';
import '../home_wrapper.dart';
import 'drawer_menu_item.dart';

class DrawerMenuWidget extends StatefulWidget {
  const DrawerMenuWidget({super.key, this.height, this.width});

  final double? height;
  final double? width;

  @override
  State<DrawerMenuWidget> createState() => _DrawerMenuWidgetState();
}

class _DrawerMenuWidgetState extends State<DrawerMenuWidget> {
  bool isLoading = false;

  Future<void> _stopServicesAndClearHive() async {
    try {
      debugPrint('🛑 Stopping background services...');
      AgentDebugLogger.log(
        runId: 'auth-bg',
        hypothesisId: 'C',
        location: 'drawer_menu_wigdet.dart:performLogout:before_stop',
        message: 'Logout requested, stopping unified background service',
        data: const {},
      );

      await Future.wait([
        stopUnifiedBackgroundService(),
        stopBackgroundService(),
      ]);

      AgentDebugLogger.log(
        runId: 'auth-bg',
        hypothesisId: 'C',
        location: 'drawer_menu_wigdet.dart:performLogout:after_stop',
        message: 'Stop background service calls completed',
        data: const {},
      );
      debugPrint('✅ Background services stopped');
    } catch (e) {
      debugPrint('⚠️ Failed to stop background service: $e');
    }

    try {
      debugPrint('🗄️ Clearing Hive step_history...');
      await HiveService().resetAppData();
    } catch (e) {
      debugPrint('⚠️ Failed to clear Hive on logout: $e');
    }
  }

  Future<bool> _callLogoutApiBestEffort() async {
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
        return false;
      }

      debugPrint('✅ Logout API success');
      return true;
    } catch (e, st) {
      debugPrint('🔥 Exception during logout API');
      debugPrint('Error: $e');
      debugPrint('StackTrace: $st');
      // Keep legacy behavior: do not block logout on exception.
      return true;
    }
  }

  Future<void> _clearAuthPrefs() async {
    debugPrint('🧹 Clearing SharedPreferences...');
    final prefs = await SharedPreferences.getInstance();

    // Explicit auth flags first (prevents service restart)
    await prefs.setBool('remember_me', false);
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');

    // Then wipe rest
    await prefs.clear();
    debugPrint('✅ SharedPreferences cleared');
  }

  void _resetLocalStorageManager() {
    debugPrint('🧠 Resetting LocalStorageManager...');
    if (Get.isRegistered<LocalStorageManager>()) {
      final localStorageManager = Get.find<LocalStorageManager>();
      localStorageManager.userMap.value = {};
      localStorageManager.userGoalDataMap.value = {};
      localStorageManager.userMap.refresh();
      localStorageManager.userGoalDataMap.refresh();
    }
    debugPrint('✅ LocalStorageManager reset');
  }

  void _deleteControllerIfRegistered<T>({bool force = false}) {
    if (!Get.isRegistered<T>()) return;
    Get.delete<T>(force: force);
  }

  Future<void> _runPostNavigationCleanup() async {
    try {
      debugPrint('🧠 Clearing DecisionTreeService...');
      await DecisionTreeService().clearAll();
    } catch (e) {
      debugPrint('⚠️ DecisionTree cleanup failed: $e');
    }

    try {
      await Alarm.stopAll();
    } catch (e) {
      debugPrint('⚠️ Alarm stopAll failed: $e');
    }

    debugPrint('🗑️ Deleting GetX controllers...');
    _deleteControllerIfRegistered<DietPlanController>(force: true);
    _deleteControllerIfRegistered<HealthTipsController>(force: true);
    _deleteControllerIfRegistered<HydrationStatController>(force: true);
    _deleteControllerIfRegistered<OTPVerificationController>(force: true);
    _deleteControllerIfRegistered<MentalWellnessController>(force: true);
    _deleteControllerIfRegistered<MoodController>(force: true);
    _deleteControllerIfRegistered<SignInController>(force: true);
    _deleteControllerIfRegistered<MoodQuestionController>(force: true);
    _deleteControllerIfRegistered<SleepController>(force: true);
    _deleteControllerIfRegistered<StepCounterController>(force: true);
    _deleteControllerIfRegistered<VitalsController>(force: true);
    debugPrint('✅ Controllers deleted');
  }

  Future<void> performLogout() async {
    debugPrint('🚪 Logout started');

    if (isLoading) return;

    setState(() => isLoading = true);

    try {
      // Start slow cleanup immediately, but don't block UI navigation on it.
      final stopAndHiveFuture = _stopServicesAndClearHive();
      final apiSuccess = await _callLogoutApiBestEffort();

      await _clearAuthPrefs();
      _resetLocalStorageManager();

      if (apiSuccess) {
        debugPrint('➡️ Navigating to SignInScreen');
        Get.offAll(() => SignInScreen());

        // Finish the heavy cleanup in background after navigation.
        unawaited(
          Future.wait([stopAndHiveFuture, _runPostNavigationCleanup()]),
        );
      } else {
        await stopAndHiveFuture;
        debugPrint('⚠️ Skipping navigation due to logout API failure');
      }
      debugPrint('🏁 Logout completed successfully');
    } catch (e) {
      debugPrint('🔥 Logout failed: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localStorageManager = Get.find<LocalStorageManager>();
    final initialProfileController = Get.find<ProfileSetupController>();

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
                      onPressed: isLoading ? null : performLogout,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFFF0E5FF),
                        side: const BorderSide(color: Colors.transparent),
                        minimumSize: const Size(double.infinity, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child:
                            isLoading
                                ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.deepPurple,
                                  ),
                                )
                                : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SvgPicture.asset(
                                      logoutIcon,
                                      width: 24,
                                      height: 24,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      "Log Out",
                                      style: TextStyle(
                                        fontSize: 18,
                                        foreground:
                                            Paint()
                                              ..shader = AppColors
                                                  .primaryGradient
                                                  .createShader(
                                                    const Rect.fromLTWH(
                                                      0,
                                                      0,
                                                      200,
                                                      70,
                                                    ),
                                                  ),
                                      ),
                                    ),
                                  ],
                                ),
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
