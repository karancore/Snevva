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
import '../Controllers/Vitals/vitalsController.dart';
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
