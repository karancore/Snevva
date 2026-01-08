/*
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
*/

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
// 1️⃣ APP PERMISSIONS (NOW NON-BLOCKING)
// ====================================================================
Future<void> requestAllPermissions() async {
  final req = <Permission>[
    Permission.activityRecognition,
    Permission.sensors,
    Permission.locationWhenInUse,
    Permission.ignoreBatteryOptimizations,
    Permission.notification,
  ];

  // ✅ Request permissions without blocking
  final statuses = await req.request();

  // Only show settings if user permanently denied
  if (statuses.values.any((p) => p.isPermanentlyDenied)) {
    print(
      "⚠️ Some permissions permanently denied - user should enable in settings",
    );
    // Don't force open settings immediately - let user use app
  }
}

// ====================================================================
// 2️⃣ HIVE INITIALIZATION (CHECK IF ALREADY INITIALIZED)
// ====================================================================
Future<void> setupHive() async {
  // ✅ Check if Hive is already initialized
  if (Hive.isBoxOpen('step_history') &&
      Hive.isBoxOpen('sleep_log') &&
      Hive.isBoxOpen('reminders_box')) {
    print("✅ Hive already initialized, skipping setup");
    return;
  }

  await Hive.initFlutter();

  if (!Hive.isAdapterRegistered(StepEntryAdapter().typeId)) {
    Hive.registerAdapter(StepEntryAdapter());
  }

  if (!Hive.isAdapterRegistered(SleepLogAdapter().typeId)) {
    Hive.registerAdapter(SleepLogAdapter());
  }

  // ✅ Only open boxes if not already open
  if (!Hive.isBoxOpen('step_history')) {
    await Hive.openBox<StepEntry>('step_history');
  }
  if (!Hive.isBoxOpen('sleep_log')) {
    await Hive.openBox<SleepLog>('sleep_log');
  }
  if (!Hive.isBoxOpen('reminders_box')) {
    await Hive.openBox('reminders_box');
  }

  print("✅ Hive setup complete");
}

// ====================================================================
// 3️⃣ BACKGROUND SERVICE INITIALIZATION (PREVENT DOUBLE START)
// ====================================================================
Future<void> initBackgroundService() async {
  final service = FlutterBackgroundService();

  // ✅ Check if service is already running
  final isRunning = await service.isRunning();
  if (isRunning) {
    print("✅ Background service already running");
    return;
  }

  print("🔄 Configuring background service...");

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: unifiedBackgroundEntry,
      isForegroundMode: true,
      autoStart: false,
      autoStartOnBoot: false,
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
    // ✅ Double-check before starting
    if (!await service.isRunning()) {
      await service.startService();
      print("✅ Background service started successfully");
    }
  } catch (e) {
    print("❌ Failed to start background service: $e");
    // Don't throw - let app continue without background service
  }
}

// ====================================================================
// 4️⃣ MAIN INITIALIZER (NOW NON-BLOCKING & IDEMPOTENT)
// ====================================================================
bool _isInitialized = false;

Future<bool> initializeApp() async {
  // ✅ Prevent double initialization
  if (_isInitialized) {
    print("✅ App already initialized");
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('remember_me') ?? false;
  }

  print("🔄 Starting app initialization...");

  try {
    // Timezone setup (lightweight)
    initializeTimeZones();
    setLocalLocation(getLocation('Asia/Kolkata'));

    // ✅ HIVE setup with safety check
    await setupHive();

    // ✅ Register controllers only if not already registered
    if (!Get.isRegistered<StepCounterController>()) {
      Get.put(StepCounterController(), permanent: true);
    }

    // ✅ Create notification channel
    await createServiceNotificationChannel();

    // ✅ Request permissions (non-blocking)
    await requestAllPermissions();

    // ✅ Start background service (with safety checks)
    await initBackgroundService();

    // ✅ Notification service
    final notifService =
        Get.isRegistered<NotificationService>()
            ? Get.find<NotificationService>()
            : Get.put(NotificationService());

    await notifService.init();

    // ✅ Schedule reminder if needed
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('reminder_scheduled') ?? false)) {
      await notifService.scheduleReminder(id: 100);
      await prefs.setBool('reminder_scheduled', true);
    }

    // ✅ Register other controllers only if not already registered
    if (!Get.isRegistered<ProfileSetupController>()) {
      Get.put(ProfileSetupController());
    }
    if (!Get.isRegistered<SleepController>()) {
      Get.put(SleepController());
    }
    if (!Get.isRegistered<MoodController>()) {
      Get.put(MoodController());
    }
    if (!Get.isRegistered<SignInController>()) {
      Get.put(SignInController());
    }
    if (!Get.isRegistered<VitalsController>()) {
      Get.put(VitalsController());
    }
    if (!Get.isRegistered<WomenHealthController>()) {
      Get.put(WomenHealthController());
    }

    _isInitialized = true;
    print("✅ App initialization complete");

    return prefs.getBool('remember_me') ?? false;
  } catch (e, stackTrace) {
    print("❌ App initialization failed: $e");
    print("Stack trace: $stackTrace");

    // Don't block the app - return false to show login screen
    return false;
  }
}
