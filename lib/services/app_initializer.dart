import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:get/get.dart';
import 'package:timezone/data/latest.dart';
import 'package:timezone/timezone.dart';

import 'package:snevva/models/steps_model.dart';
import 'package:snevva/models/sleep_log.dart';
import 'package:snevva/services/unified_background_service.dart';
import 'package:snevva/services/notification_service.dart';

import 'package:snevva/Controllers/ProfileSetupAndQuestionnare/profile_setup_controller.dart';
import 'package:snevva/Controllers/SleepScreen/sleep_controller.dart';
import 'package:snevva/Controllers/StepCounter/step_counter_controller.dart';
import 'package:snevva/Controllers/MoodTracker/mood_controller.dart';
import 'package:snevva/Controllers/signupAndSignIn/sign_in_controller.dart';
import 'package:snevva/Controllers/Vitals/vitalsController.dart';
import 'package:snevva/Controllers/local_storage_manager.dart';
import 'package:snevva/Controllers/WomenHealth/women_health_controller.dart';
import 'package:snevva/Controllers/Reminder/reminder_controller.dart';
import 'package:snevva/Controllers/Reminder/water_controller.dart';

// ====================================================================
// 0️⃣ NOTIFICATION CHANNEL SETUP (CRITICAL FOR ANDROID 12+)
// ====================================================================
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> createServiceNotificationChannel() async {
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'flutter_background_service',
    'Background Service',
    description: 'Health tracking service (steps & sleep)',
    importance: Importance.low,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  print("✅ Notification channel created for foreground service");
}

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
// 3️⃣ BACKGROUND SERVICE INITIALIZATION (UNIFIED: STEPS + SLEEP)
// ====================================================================
Future<void> initBackgroundService() async {
  final service = FlutterBackgroundService();

  // Check if service is already running
  final isRunning = await service.isRunning();
  if (isRunning) {
    print("⚠️ Background service already running, skipping initialization");
    return;
  }

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: unifiedBackgroundEntry,
      isForegroundMode: true,
      autoStart: false, // 🔥 Critical: prevent double-start
      autoStartOnBoot: false, // 🔥 Prevent auto-restart issues
      notificationChannelId: "flutter_background_service",
      initialNotificationTitle: "Health Tracking",
      initialNotificationContent: "Monitoring steps & sleep...",
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: unifiedBackgroundEntry,
      onBackground: unifiedBackgroundEntry,
    ),
  );

  try {
    if (!await service.isRunning()) {
      await service.startService();
      print(
        "✅ Unified background service (steps + sleep) started successfully",
      );
    } else {
      print("⚠️ Service already running, skipping start");
    }
  } catch (e) {
    print("❌ Failed to start background service: $e");
  }
}

// ====================================================================
// 4️⃣ MAIN INITIALIZER
// ====================================================================
Future<bool> initializeApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Timezone setup
  initializeTimeZones();
  setLocalLocation(getLocation('Asia/Kolkata'));

  // ✅ HIVE FIRST (CRITICAL)
  await setupHive();

  // ✅ Register StepCounterController EARLY & PERMANENT
  Get.put(StepCounterController(), permanent: true);

  // 🔥 Create notification channel BEFORE starting service (Android 8+)
  await createServiceNotificationChannel();

  // 🔥 Request permissions BEFORE service (Android 13+)
  await requestAllPermissions();

  // Start pedometer + sleep background service
  await initBackgroundService();

  // Notifications
  final notifService = Get.put(NotificationService());
  await notifService.init();

  final prefs = await SharedPreferences.getInstance();
  if (!(prefs.getBool('reminder_scheduled') ?? false)) {
    await notifService.scheduleReminder(id: 100);
    await prefs.setBool('reminder_scheduled', true);
  }

  // Other controllers
  Get.put(ProfileSetupController());
  Get.put(SleepController());
  Get.put(MoodController());
  Get.put(SignInController());
  Get.put(VitalsController());
  Get.put(WomenHealthController());

  // Login status
  return prefs.getBool('remember_me') ?? false;
}
