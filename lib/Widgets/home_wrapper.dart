import 'package:alarm/alarm.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/instance_manager.dart';
import 'package:snevva/Controllers/local_storage_manager.dart';
import 'package:snevva/views/Dashboard/dashboard.dart';
import 'package:snevva/views/Information/menu_screen.dart';
import 'package:snevva/views/Reminder/reminder_screen.dart';
import 'package:snevva/widgets/navbar.dart';
import 'package:snevva/Controllers/Reminder/event_controller.dart';
import 'package:snevva/Controllers/Reminder/meal_controller.dart';
import 'package:snevva/Controllers/Reminder/medicine_controller.dart';
import 'package:snevva/Controllers/Reminder/water_controller.dart';
import 'package:snevva/Controllers/WomenHealth/bottom_sheet_controller.dart';
import '../Controllers/DietPlan/diet_plan_controller.dart';
import '../Controllers/Hydration/hydration_stat_controller.dart';

import '../Controllers/HealthTips/healthtips_controller.dart';
import '../Controllers/MentalWellness/mental_wellness_controller.dart';
import '../Controllers/MoodTracker/mood_controller.dart';
import '../Controllers/MoodTracker/mood_questions_controller.dart';
import '../Controllers/SleepScreen/sleep_controller.dart';
import '../Controllers/Vitals/vitalsController.dart';
import '../Controllers/WomenHealth/women_health_controller.dart';

import '../Controllers/BMI/bmi_controller.dart';
import '../Controllers/StepCounter/step_counter_controller.dart';
import '../services/app_initializer.dart';
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
  Future<void> _startupSequence() async {
    // 1️⃣ Permissions first
    await requestAllPermissions();

    // 2️⃣ Wait for app to fully resume
    await Future.delayed(const Duration(seconds: 1));

    // 3️⃣ THEN start background service
    await initBackgroundService();



    await FirebaseMessaging.instance.requestPermission();
    await setupNotificationChannel();
    await Alarm.init();





    // 4️⃣ Device info LAST
    await getDeviceInfo();
  }


  Future<void> getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;

    debugPrint('Device ID: ${androidInfo.id}');
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
      ReminderScreen(),
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
