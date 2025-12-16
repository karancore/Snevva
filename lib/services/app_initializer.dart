import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:get/get.dart';
import 'package:timezone/data/latest.dart';
import 'package:timezone/timezone.dart';

import 'package:snevva/models/steps_model.dart';
import 'package:snevva/models/sleep_log.dart';
import 'package:snevva/services/background_pedometer_service.dart';
import 'package:snevva/services/notification_service.dart';

import 'package:snevva/Controllers/ProfileSetupAndQuestionnare/profile_setup_controller.dart';
import 'package:snevva/Controllers/SleepScreen/sleep_controller.dart';
import 'package:snevva/Controllers/StepCounter/step_counter_controller.dart';
import 'package:snevva/Controllers/MoodTracker/mood_controller.dart';
import 'package:snevva/Controllers/signupAndSignIn/sign_in_controller.dart';
import 'package:snevva/Controllers/Vitals/vitalsController.dart';
import 'package:snevva/Controllers/local_storage_manager.dart';
import 'package:snevva/Controllers/WomenHealth/women_health_controller.dart';

// ====================================================================
// 1️⃣ APP PERMISSIONS
// ====================================================================
Future<void> requestAllPermissions() async {
  final req = <Permission>[
    Permission.activityRecognition,
    Permission.sensors,
    Permission.locationWhenInUse,
    Permission.ignoreBatteryOptimizations,
    Permission.notification,
  ];

  final statuses = await req.request();

  if (statuses.values.any((p) => p.isPermanentlyDenied)) {
    openAppSettings();
  }
}

// ====================================================================
// 2️⃣ HIVE INITIALIZATION
// ====================================================================
Future<void> setupHive() async {
  await Hive.initFlutter();

  if (!Hive.isAdapterRegistered(StepEntryAdapter().typeId)) {
    Hive.registerAdapter(StepEntryAdapter());
  }

  if (!Hive.isAdapterRegistered(SleepLogAdapter().typeId)) {
    Hive.registerAdapter(SleepLogAdapter());
  }

  await Hive.openBox<StepEntry>('step_history');
  await Hive.openBox<SleepLog>('sleep_log');
  await Hive.openBox('reminders_box');
}

// ====================================================================
// 3️⃣ BACKGROUND SERVICE ISOLATE ENTRYPOINT
// ====================================================================
bool onIosBackground(ServiceInstance service) => true;

@pragma('vm:entry-point')
void onBackgroundStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  // Required for Android
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
  }

  // Background heartbeat: sync SharedPreferences only
  service.on('refreshSteps').listen((event) async {
    final steps = prefs.getInt("todaySteps") ?? 0;
    print("🔄 Background heartbeat step sync: $steps");
  });
}

// ====================================================================
// 4️⃣ MAIN INITIALIZER
// ====================================================================
Future<bool> initializeApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Timezone setup
  initializeTimeZones();
  setLocalLocation(getLocation('Asia/Kolkata'));

  // Local DB
  await setupHive();

  // Start only pedometer background service
  await initBackgroundService();

  // Optional: runtime permissions
  await requestAllPermissions();

  // Notifications
  final notifService = Get.put(NotificationService());
  await notifService.init();

  final prefs = await SharedPreferences.getInstance();
  if (!(prefs.getBool('reminder_scheduled') ?? false)) {
    await notifService.scheduleReminder(id: 100);
    await prefs.setBool('reminder_scheduled', true);
  }

  // Register Controllers
  Get.put(ProfileSetupController());
  Get.put(SleepController());
  Get.put(StepCounterController());
  Get.put(MoodController());
  Get.put(SignInController());
  Get.put(VitalsController());
  Get.put(LocalStorageManager());
  Get.put(WomenHealthController());

  // Return login status
  return prefs.getBool('remember_me') ?? false;
}
