import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/common/global_variables.dart';
import 'package:snevva/models/hive_models/reminder_payload_model.dart';
import 'package:snevva/services/notification_service.dart';
import 'package:snevva/services/unified_background_service.dart';
import 'package:timezone/data/latest.dart';
import 'package:timezone/timezone.dart';

import '../common/agent_debug_logger.dart';
import '../consts/consts.dart';


// ====================================================================
// 0️⃣ NOTIFICATION CHANNEL SETUP (CRITICAL FOR ANDROID 12+)
// ====================================================================
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> createServiceNotificationChannel() async {
  // Single unified channel used by BOTH the native StepCounterService and the
  // Dart flutter_background_service isolate. Creating it here ensures it exists
  // before either service tries to post notifications.
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'tracker_channel',
    'Health Tracking',
    description: 'Step & sleep tracking',
    importance: Importance.low,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  debugPrint("✅ Notification channel created for foreground service");
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

  // For reliable background step counting, battery optimization must be ignored.
  if (statuses[Permission.ignoreBatteryOptimizations]?.isDenied ?? true) {
    print(
      "⚠️ Ignoring battery optimizations is NOT granted, background isolate might drop.",
    );
    // Note: If you want 100% 24/7 reliability, you must prompt the user
    // to disable battery optimizations for Snevva in Android Settings.
  }

  // Only show settings if user permanently denied
  if (statuses.values.any((p) => p.isPermanentlyDenied)) {
    debugPrint(
      "⚠️ Some permissions permanently denied - user should enable in settings",
    );
    // Don't force open settings immediately - let user use app
  }
}

// ====================================================================
// 2️⃣ HIVE INITIALIZATION — reminders and medicine boxes only
// ====================================================================
Future<void> setupHive() async {
  try {
    if (Hive.isBoxOpen('medicine_list') && Hive.isBoxOpen('reminders_box')) {
      debugPrint("✅ Hive already initialized, skipping setup");
      return;
    }

    var directory = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(directory.path);

    debugPrint("🧪 Initializing Hive at: ${directory.path}");

    // Register adapters for reminder types only
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

    // Open only reminders and medicine — step/sleep are file-based now
    if (!Hive.isBoxOpen(reminderBox)) {
      await Hive.openBox(reminderBox);
    }
    if (!Hive.isBoxOpen('medicine_list')) {
      await Hive.openBox('medicine_list');
    }

    debugPrint("✅ Hive setup complete — reminders/medicine boxes opened");
  } catch (e, stackTrace) {
    debugPrint("❌ Hive setup failed: $e");
    debugPrint(stackTrace as String?);
    rethrow;
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
    debugPrint("✅ Background service already running");
    return;
  }

  debugPrint("🔄 Configuring background service...");

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: unifiedBackgroundEntry,
      // ✅ FIX: foreground mode so the Dart isolate holds a foreground lock and
      // cannot be silently killed by OEM battery savers. This is required for
      // reliable sleep tracking via the screen_state stream.
      isForegroundMode: true,
      autoStart: true,
      autoStartOnBoot: true,
      notificationChannelId: 'tracker_channel',
      initialNotificationTitle: 'Snevva Active',
      initialNotificationContent: '👟 Steps: 0',
      // ✅ FIX: Same notification ID as StepCounterService.kt (ID = 1)
      // so Android shows only ONE notification for both services.
      foregroundServiceNotificationId: 1,
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
      debugPrint("✅ Background service started successfully");
    }
  } catch (e) {
    debugPrint("❌ Failed to start background service: $e");
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

  debugPrint("🔄 Starting app initialization...");

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
    debugPrint("✅ App initialization complete");

    return prefs.getBool('remember_me') ?? false;
  } catch (e, stackTrace) {
    debugPrint("❌ App initialization failed: $e");
    debugPrint(stackTrace as String?);
    return false;
  }
}

// Future<bool> initializeApp() async {
//   // ✅ Prevent double initialization
//   if (_isInitialized) {
//     debugPrint("✅ App already initialized");
//     final prefs = await SharedPreferences.getInstance();
//     return prefs.getBool('remember_me') ?? false;
//   }
//
//   debugPrint("🔄 Starting app initialization...");
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
//     debugPrint("✅ App initialization complete");
//
//     return prefs.getBool('remember_me') ?? false;
//   } catch (e, stackTrace) {
//     debugPrint("❌ App initialization failed: $e");
//     debugPrint("Stack trace: $stackTrace");
//
//     // Don't block the app - return false to show login screen
//     return false;
//   }
// }
