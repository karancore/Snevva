import 'package:alarm/alarm.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/instance_manager.dart';
import 'package:snevva/Controllers/BMI/bmi_updatecontroller.dart';
import 'package:snevva/Controllers/local_storage_manager.dart';
import 'package:snevva/views/Dashboard/dashboard.dart';
import 'package:snevva/views/Information/menu_screen.dart';
import 'package:snevva/views/Reminder/reminder_wrapper.dart';
import 'package:snevva/widgets/navbar.dart';
import '../services/notification_channel.dart';
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
  final bmiController = Get.find<BmiUpdateController>();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  static Future<void>? _sharedStartupTask;
  late final List<Widget> _pages;

  void onTabSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    _pages = <Widget>[
      Dashboard(onTabSelected: onTabSelected),
      MyHealthScreen(),
      ReminderScreenWrapper(),
      MenuScreen(),
    ];
    bmiController.loadUserBMI();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _ensureStartupSequence();
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

  Future<void> _ensureStartupSequence() async {
    _sharedStartupTask ??= _startupSequence();
    await _sharedStartupTask;
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

    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      body: GestureDetector(
        onHorizontalDragUpdate: (details) {
          if (details.delta.dx > 10) {
            // Swipe Right - Open drawer
            _scaffoldKey.currentState?.openDrawer();
          } else if (details.delta.dx < -10) {
            // Swipe Left - Close drawer
            if (_scaffoldKey.currentState?.isDrawerOpen == true) {
              Navigator.of(context).pop(); // Close the drawer
            }
          }
        },
        child: IndexedStack(index: _selectedIndex, children: _pages),
      ),
      bottomNavigationBar: Navbar(
        selectedIndex: _selectedIndex,
        onTabSelected: onTabSelected,
      ),
    );
  }
}
