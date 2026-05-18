import 'package:alarm/alarm.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/instance_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/Controllers/BMI/bmi_updatecontroller.dart';
import 'package:snevva/Controllers/StepCounter/step_counter_controller.dart';
import 'package:snevva/Controllers/local_storage_manager.dart';
import 'package:snevva/common/global_variables.dart';
import 'package:snevva/views/Dashboard/dashboard.dart';
import 'package:snevva/views/Information/menu_screen.dart';
import 'package:snevva/views/ProfileAndQuestionnaire/profile_setup_initial.dart';
import 'package:snevva/views/Reminder/reminder_wrapper.dart';
import 'package:snevva/widgets/navbar.dart';

import '../services/notification_channel.dart';
import '../views/My_Health/my_health_screen.dart';
import 'Drawer/drawer_menu_wigdet.dart';
import 'birthday_popup_dialog.dart';

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
  bool _birthdayShown = false;

  // ✅ One-shot gate: set to true once userMap is confirmed non-empty.
  // Using a plain bool + single setState() avoids rebuilding the Scaffold
  // on every subsequent userMap change (login refresh, FCM, ever watchers).
  bool _userMapReady = false;
  Worker? _userMapWorker;

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

    // ✅ If userMap already has data (cold-start with cached session), go
    // straight to ready state without waiting for an ever() notification.
    if (localStorageManager.userMap.isNotEmpty) {
      _userMapReady = true;
      _ensurePageInitialized(_selectedIndex);
    } else {
      // ✅ Fresh login: wait for the first non-empty userMap, flip the flag
      // exactly once, then cancel the worker so future userMap changes
      // (FCM, profile updates, etc.) never trigger a rebuild here.
      _userMapWorker = ever<Map<String, dynamic>>(
        localStorageManager.userMap,
        (map) {
          if (map.isNotEmpty && !_userMapReady && mounted) {
            _userMapWorker?.dispose();
            _userMapWorker = null;
            _ensurePageInitialized(_selectedIndex);
            setState(() => _userMapReady = true);
          }
        },
      );
    }

    bmiController.loadUserBMI();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (_redirectToProfileSetupIfNeeded()) return;
      await _ensureStartupSequence();

      // ── Birthday popup ────────────────────────────────────────────────
      if (!_birthdayShown && mounted) {
        _birthdayShown = true;
        final today = DateTime.now();
        debugPrint("2027 ${DateTime.now().year + 1}");
        final lastShownKey =
            'birthday_shown_${today.year}_${today.month}_${today.day}';
        final prefs = await SharedPreferences.getInstance();
        final alreadyShownToday = prefs.getBool(lastShownKey) ?? false;

        if (!alreadyShownToday && mounted) {
          await BirthdayPopupHelper.showIfBirthday(
            context,
            localStorageManager.userMap,
          );
          // Mark as shown so reloading the app mid-day doesn't repeat it
          await prefs.setBool(lastShownKey, true);
        }
      }
      // ─────────────────────────────────────────────────────────────────
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
      stepController.activateRealtimeTracking();
    } else {
      stepController.deactivateRealtimeTracking();
    }
  }

  @override
  void dispose() {
    _userMapWorker?.dispose();
    _setStepRealtimeTracking(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Show a plain loading screen until userMap is ready.
    // This is a normal StatefulWidget build — no Obx here — so subsequent
    // userMap changes (FCM, ever watchers, profile refresh) never cause
    // the IndexedStack/Dashboard to be re-mounted, eliminating the ghost UI.
    if (!_userMapReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

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
