import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:get/get.dart';
import 'package:snevva/common/global_variables.dart';
import 'package:snevva/models/hive_models/reminder_payload_model.dart';
import 'package:snevva/models/reminders/medicine_reminder_model.dart';
import 'package:snevva/models/reminders/water_reminder_model.dart';
import 'package:timezone/data/latest.dart';
import 'package:timezone/timezone.dart';

import 'package:snevva/services/unified_background_service.dart';
import 'package:snevva/services/notification_service.dart';

import '../models/hive_models/sleep_log.dart';
import '../models/hive_models/sleep_log_g.dart';
import '../models/hive_models/steps_model.dart';
import '../common/agent_debug_logger.dart';

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
  try {
    // ✅ Check if already initialized (across isolates, but mainly for main)
    if (Hive.isBoxOpen('step_history') &&
        Hive.isBoxOpen('sleep_log') &&
        Hive.isBoxOpen('medicine_list') &&
        Hive.isBoxOpen('reminders_box')) {
      print("✅ Hive already initialized, skipping setup");
      return;
    }

    var directory = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(directory.path);  // This must be called once per isolate

    print("🧪 Initializing Hive at: ${directory.path}");

    // Register adapters (only if not already registered)
    if (!Hive.isAdapterRegistered(StepEntryAdapter().typeId)) {
      Hive.registerAdapter(StepEntryAdapter());
    }

  // 🔑 OPEN BOXES HERE
  // await Hive.openBox('sleepBox');
  // await Hive.openBox('deepSleepBox');
  // // await Hive.box('medicine_list').clear();

  if (!Hive.isAdapterRegistered(StepEntryAdapter().typeId)) {
    Hive.registerAdapter(StepEntryAdapter());
  }
  if (!Hive.isAdapterRegistered(SleepLogAdapter().typeId)) {
    Hive.registerAdapter(SleepLogAdapter());
  }
  if (!Hive.isAdapterRegistered(ReminderPayloadModelAdapter().typeId)) {
    Hive.registerAdapter(ReminderPayloadModelAdapter());
  }
  if (!Hive.isAdapterRegistered(DosageAdapter().typeId)) {
    Hive.registerAdapter(DosageAdapter());
  }

  if (!Hive.isAdapterRegistered(CustomReminderAdapter().typeId)) {
    Hive.registerAdapter(CustomReminderAdapter());
  }

  if (!Hive.isAdapterRegistered(TimesPerDayAdapter().typeId)) {
    Hive.registerAdapter(TimesPerDayAdapter());
  }

  if (!Hive.isAdapterRegistered(EveryXHoursAdapter().typeId)) {
    Hive.registerAdapter(EveryXHoursAdapter());
  }

  if (!Hive.isAdapterRegistered(RemindBeforeAdapter().typeId)) {
    Hive.registerAdapter(RemindBeforeAdapter());
  }

  // ✅ Only open boxes if not already open
  if (!Hive.isBoxOpen('step_history')) {
    await Hive.openBox<StepEntry>('step_history');
  }

  print("✅ Hive setup complete - boxes opened");

  if (!Hive.isBoxOpen('sleep_log')) {
    await Hive.openBox<SleepLog>('sleep_log');
  }
  if (!Hive.isBoxOpen(reminderBox)) {
    await Hive.openBox(reminderBox);
  }
  if (!Hive.isBoxOpen("medicine_list")) {
    await Hive.openBox('medicine_list');
  }

    print("✅ Hive setup complete - boxes opened");
  } catch (e, stackTrace) {
    print("❌ Hive setup failed: $e");
    print(stackTrace);
    // Optionally rethrow or handle (e.g., show error UI)
    rethrow;  // Let main.dart handle it
  }
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

Future<void> stopUnifiedBackgroundService() async {
  final service = FlutterBackgroundService();

  // #region agent log
  AgentDebugLogger.log(
    runId: 'auth-bg',
    hypothesisId: 'C',
    location: 'app_initializer.dart:stopUnifiedBackgroundService:entry',
    message: 'Stopping unified background service',
    data: const {},
  );
  // #endregion

  final isRunning = await service.isRunning();
  if (!isRunning) {
    // #region agent log
    AgentDebugLogger.log(
      runId: 'auth-bg',
      hypothesisId: 'C',
      location: 'app_initializer.dart:stopUnifiedBackgroundService:not_running',
      message: 'Unified background service not running',
      data: const {},
    );
    // #endregion
    return;
  }

  service.invoke('stopService');

  // #region agent log
  AgentDebugLogger.log(
    runId: 'auth-bg',
    hypothesisId: 'C',
    location: 'app_initializer.dart:stopUnifiedBackgroundService:invoked',
    message: 'Invoked stopService on unified background service',
    data: const {},
  );
  // #endregion
}

bool _isInitialized = false;
Future<bool> initializeApp() async {
  if (_isInitialized) {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('remember_me') ?? false;
  }

  print("🔄 Starting app initialization...");

  try {
    // 🌍 Timezone
    initializeTimeZones();
    setLocalLocation(getLocation('Asia/Kolkata'));

    // 🔔 Notification channel
    await createServiceNotificationChannel();

    // 🔔 Notification service (SERVICE, not controller)
    final notifService = NotificationService();
    await notifService.init();

    // ⏰ One-time reminder
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('reminder_scheduled') ?? false)) {
      await notifService.scheduleReminder(id: 100);
      await prefs.setBool('reminder_scheduled', true);
    }

    _isInitialized = true;
    print("✅ App initialization complete");

    return prefs.getBool('remember_me') ?? false;
  } catch (e, stackTrace) {
    print("❌ App initialization failed: $e");
    print(stackTrace);
    return false;
  }
}

// Future<bool> initializeApp() async {
//   // ✅ Prevent double initialization
//   if (_isInitialized) {
//     print("✅ App already initialized");
//     final prefs = await SharedPreferences.getInstance();
//     return prefs.getBool('remember_me') ?? false;
//   }
//
//   print("🔄 Starting app initialization...");
//
//   try {
//     // Timezone setup (lightweight)
//     initializeTimeZones();
//     setLocalLocation(getLocation('Asia/Kolkata'));
//
//     // ✅ HIVE setup with safety check
//     await setupHive();
//
//     // ✅ Register controllers only if not already registered
//     if (!Get.isRegistered<StepCounterController>()) {
//       Get.put(StepCounterController(), permanent: true);
//     }
//
//     // ✅ Create notification channel
//     await createServiceNotificationChannel();
//
//
//     // ✅ Notification service
//     final notifService =
//         Get.isRegistered<NotificationService>()
//             ? Get.find<NotificationService>()
//             : Get.put(NotificationService());
//
//     await notifService.init();
//
//     // ✅ Schedule reminder if needed
//     final prefs = await SharedPreferences.getInstance();
//     if (!(prefs.getBool('reminder_scheduled') ?? false)) {
//       await notifService.scheduleReminder(id: 100);
//       await prefs.setBool('reminder_scheduled', true);
//     }
//
//     // ✅ Register other controllers only if not already registered
//     if (!Get.isRegistered<ProfileSetupController>()) {
//       Get.put(ProfileSetupController());
//     }
//     if (!Get.isRegistered<SleepController>()) {
//       Get.put(SleepController());
//     }
//     if (!Get.isRegistered<MoodController>()) {
//       Get.put(MoodController());
//     }
//     if (!Get.isRegistered<SignInController>()) {
//       Get.put(SignInController());
//     }
//     if (!Get.isRegistered<VitalsController>()) {
//       Get.put(VitalsController());
//     }
//     if (!Get.isRegistered<WomenHealthController>()) {
//       Get.put(WomenHealthController());
//     }
//
//     _isInitialized = true;
//     print("✅ App initialization complete");
//
//     return prefs.getBool('remember_me') ?? false;
//   } catch (e, stackTrace) {
//     print("❌ App initialization failed: $e");
//     print("Stack trace: $stackTrace");
//
//     // Don't block the app - return false to show login screen
//     return false;
//   }
// }
