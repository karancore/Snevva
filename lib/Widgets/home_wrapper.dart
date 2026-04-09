import 'package:alarm/alarm.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/instance_manager.dart';
import 'package:snevva/Controllers/BMI/bmi_updatecontroller.dart';
import 'package:snevva/Controllers/StepCounter/step_counter_controller.dart';
import 'package:snevva/Controllers/local_storage_manager.dart';
import 'package:snevva/common/global_variables.dart';
import 'package:snevva/views/Dashboard/dashboard.dart';
import 'package:snevva/views/Information/menu_screen.dart';
import 'package:snevva/views/Reminder/reminder_wrapper.dart';
import 'package:snevva/views/ProfileAndQuestionnaire/profile_setup_initial.dart';
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
  late final List<Widget?> _pages;
  bool _hasRedirectedToProfileSetup = false;

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return Dashboard(onTabSelected: onTabSelected);
      case 1:
        return const MyHealthScreen();
      case 2:
        return const ReminderScreenWrapper();
      case 3:
        return const MenuScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  void _ensurePageInitialized(int index) {
    if (_pages[index] != null) return;
    _pages[index] = _buildPage(index);
  }

  void onTabSelected(int index) {
    if (_selectedIndex == index) return;

    _setStepRealtimeTracking(index == 0);
    setState(() {
      _ensurePageInitialized(index);
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    _pages = List<Widget?>.filled(4, null, growable: false);
    _ensurePageInitialized(_selectedIndex);
    bmiController.loadUserBMI();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (_redirectToProfileSetupIfNeeded()) return;
      await _ensureStartupSequence();
    });
  }

  Future<void> _startupSequence() async {
    await FirebaseMessaging.instance.requestPermission();
    await setupNotificationChannel();
    await Alarm.init();
  }

  Future<void> _ensureStartupSequence() async {
    _sharedStartupTask ??= _startupSequence();
    await _sharedStartupTask;
  }

  bool _redirectToProfileSetupIfNeeded() {
    if (_hasRedirectedToProfileSetup) return true;
    if (isProfileSetupInitialComplete(localStorageManager.userMap))
      return false;

    _hasRedirectedToProfileSetup = true;
    Get.offAll(() => const ProfileSetupInitial());
    return true;
  }

  void _setStepRealtimeTracking(bool isDashboardVisible) {
    if (!Get.isRegistered<StepCounterController>()) return;
    final stepController = Get.find<StepCounterController>();
    if (isDashboardVisible) {
      stepController.startTracking();
    } else {
      stepController.stopTracking();
    }
  }

  @override
  void dispose() {
    _setStepRealtimeTracking(false);
    super.dispose();
  }

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
        child: IndexedStack(
          index: _selectedIndex,
          children: List<Widget>.generate(
            _pages.length,
            (index) => TickerMode(
              enabled: _selectedIndex == index,
              child: _pages[index] ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Navbar(
        selectedIndex: _selectedIndex,
        onTabSelected: onTabSelected,
      ),
    );
  }
}
