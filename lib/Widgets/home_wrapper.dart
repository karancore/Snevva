import 'package:alarm/alarm.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/instance_manager.dart';
import 'package:snevva/Controllers/local_storage_manager.dart';
import 'package:snevva/views/Dashboard/dashboard.dart';
import 'package:snevva/views/Information/menu_screen.dart';
import 'package:snevva/views/Reminder/reminder_screen.dart';
import 'package:snevva/views/Reminder/reminder_wrapper.dart';
import 'package:snevva/widgets/navbar.dart';
import '../Controllers/BMI/bmi_controller.dart';
import '../Controllers/DietPlan/diet_plan_controller.dart';
import '../Controllers/HealthTips/healthtips_controller.dart';
import '../Controllers/Hydration/hydration_stat_controller.dart';
import '../Controllers/MentalWellness/mental_wellness_controller.dart';
import '../Controllers/MoodTracker/mood_controller.dart';
import '../Controllers/MoodTracker/mood_questions_controller.dart';
import '../Controllers/ProfileSetupAndQuestionnare/editprofile_controller.dart';
import '../Controllers/ProfileSetupAndQuestionnare/profile_setup_controller.dart';
import '../Controllers/StepCounter/step_counter_controller.dart';
import '../Controllers/Vitals/vitalsController.dart';
import '../Controllers/WomenHealth/bottom_sheet_controller.dart';
import '../Controllers/WomenHealth/women_health_controller.dart';
import '../Controllers/alerts/alerts_controller.dart';
import '../Controllers/signupAndSignIn/create_password_controller.dart';
import '../Controllers/signupAndSignIn/forgot_password_controller.dart';
import '../Controllers/signupAndSignIn/otp_verification_controller.dart';
import '../Controllers/signupAndSignIn/sign_in_controller.dart';
import '../Controllers/signupAndSignIn/sign_up_controller.dart';
import '../Controllers/signupAndSignIn/update_old_password_controller.dart';
import '../services/app_initializer.dart';
import '../services/notification_channel.dart';
import '../utils/theme_controller.dart';
import '../views/My_Health/my_health_screen.dart';
import 'Drawer/drawer_menu_wigdet.dart';

// 👈 make sure you have this

class HomeWrapper extends StatefulWidget {
  const HomeWrapper({super.key});

  @override
  State<HomeWrapper> createState() => _HomeWrapperState();
}

class _HomeWrapperState extends State<HomeWrapper> {
  int _selectedIndex = 0;
  final localStorageManager = Get.find<LocalStorageManager>();
  final bmiController = Get.find<BmiController>();

  void onTabSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    bmiController.loadUserBMI();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _startupSequence();
    });

    //fetchFCMToken();
    // checksession();
    // localStorageManager.checksession();
  }
  // void initialiseControllers(){
  //   Get.put(LocalStorageManager(), permanent: true);
  //
  //   if (!Get.isRegistered<AlertsController>()) {
  //     Get.put(AlertsController(), permanent: true);
  //   }
  //
  //   // Auth
  //   if (!Get.isRegistered<SignInController>()) {
  //     Get.lazyPut(() => SignInController(), fenix: true);
  //   }
  //   if (!Get.isRegistered<SignUpController>()) {
  //     Get.lazyPut(() => SignUpController(), fenix: true);
  //   }
  //   if (!Get.isRegistered<OTPVerificationController>()) {
  //     Get.lazyPut(() => OTPVerificationController(), fenix: true);
  //   }
  //   if (!Get.isRegistered<UpdateOldPasswordController>()) {
  //     Get.lazyPut(() => UpdateOldPasswordController(), fenix: true);
  //   }
  //   if (!Get.isRegistered<CreatePasswordController>()) {
  //     Get.lazyPut(() => CreatePasswordController(), fenix: true);
  //   }
  //   if (!Get.isRegistered<ForgotPasswordController>()) {
  //     Get.lazyPut(() => ForgotPasswordController(), fenix: true);
  //   }
  //   if (!Get.isRegistered<ProfileSetupController>()) {
  //     Get.lazyPut(() => ProfileSetupController(), fenix: true);
  //   }
  //
  //
  //   if (!Get.isRegistered<WomenHealthController>()) {
  //     Get.lazyPut(() => WomenHealthController(), fenix: true);
  //   }
  //
  //   Get.put(VitalsController(), permanent: true);
  //   Get.put(HydrationStatController(), permanent: true);
  //   Get.put(MoodController(), permanent: true);
  //   Get.put(EditprofileController(), permanent: true);
  //
  //   if (!Get.isRegistered<StepCounterController>()) {
  //     Get.put(StepCounterController(), permanent: true);
  //   }
  //
  //   // Feature
  //   if (!Get.isRegistered<BmiController>()) {
  //     Get.lazyPut(() => BmiController(), fenix: true);
  //   }
  //   if (!Get.isRegistered<DietPlanController>()) {
  //     Get.lazyPut(() => DietPlanController(), fenix: true);
  //   }
  //   if (!Get.isRegistered<HealthTipsController>()) {
  //     Get.lazyPut(() => HealthTipsController(), fenix: true);
  //   }
  //
  //   if (!Get.isRegistered<MentalWellnessController>()) {
  //     Get.lazyPut(() => MentalWellnessController(), fenix: true);
  //   }
  //
  //   Get.lazyPut(() => MoodQuestionController(), fenix: true);
  //
  //   if (!Get.isRegistered<BottomSheetController>()) {
  //     Get.lazyPut(() => BottomSheetController(), fenix: true);
  //   }
  //   if (!Get.isRegistered<ThemeController>()) {
  //     Get.lazyPut(() => ThemeController(), fenix: true);
  //   }
  //
  // }

  Future<void> _startupSequence() async {
    // 1️⃣ Permissions first
    await requestAllPermissions();

    // 2️⃣ Wait for app to fully resume
    // await Future.delayed(const Duration(seconds: 1));

    // 3️⃣ THEN start background service
    // await initBackgroundService();autoStart

    await FirebaseMessaging.instance.requestPermission();
    await setupNotificationChannel();
    await Alarm.init();

    // Get.put(ThemeController(), permanent: true);
    //
    //
    // Get.put(VitalsController(), permanent: true);
  }

  // Future<void> checksession() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final token = prefs.getString('auth_token');
  //   if(token == null){
  //     Get.to(SignInScreen());
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

    List<Widget> pages = [
      Dashboard(onTabSelected: onTabSelected),
      MyHealthScreen(),
      ReminderScreenWrapper(),
      MenuScreen(),
    ];

    return Scaffold(
      key: scaffoldKey,
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      body: GestureDetector(
        onHorizontalDragUpdate: (details) {
          if (details.delta.dx > 10) {
            // Swipe Right - Open drawer
            scaffoldKey.currentState?.openDrawer();
          } else if (details.delta.dx < -10) {
            // Swipe Left - Close drawer
            if (scaffoldKey.currentState?.isDrawerOpen == true) {
              Navigator.of(context).pop(); // Close the drawer
            }
          }
        },
        child: pages[_selectedIndex],
      ),
      bottomNavigationBar: Navbar(
        selectedIndex: _selectedIndex,
        onTabSelected: onTabSelected,
      ),
    );
  }
}
