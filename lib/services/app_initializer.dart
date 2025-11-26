import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/Controllers/MoodTracker/mood_controller.dart';
import 'package:snevva/Controllers/ProfileSetupAndQuestionnare/profile_setup_controller.dart';
import 'package:snevva/Controllers/SleepScreen/sleep_controller.dart';
import 'package:snevva/Controllers/StepCounter/step_counter_controller.dart';
import 'package:snevva/Controllers/Vitals/vitalsController.dart';
import 'package:snevva/Controllers/WomenHealth/women_health_controller.dart';
import 'package:snevva/Controllers/localStorageManager.dart';
import 'package:snevva/Controllers/signupAndSignIn/sign_in_controller.dart';
import 'package:snevva/models/steps_model.dart';
import 'package:snevva/services/notification_service.dart';
import 'package:snevva/views/WomenHealth/women_health_screen.dart';
import 'package:timezone/data/latest.dart';
import 'package:timezone/timezone.dart';
import '../consts/consts.dart';

/// ✅ Requests all required runtime permissions
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

/// ✅ Initializes Hive database
Future<void> setupHive() async {
  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(StepEntryAdapter().typeId)) {
    Hive.registerAdapter(StepEntryAdapter());
  }
  await Hive.openBox<StepEntry>('step_history');
}

/// ✅ Configures background service (used for app maintenance / sync tasks)
Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
  androidConfiguration: AndroidConfiguration(
    onStart: onBackgroundStart,
    isForegroundMode: true,
    autoStart: true,
    autoStartOnBoot: true,
    initialNotificationTitle: "Step Tracking Enabled",
    initialNotificationContent: "Service running…",
  ),
  iosConfiguration: IosConfiguration(),
);


  await service.startService();
}

bool onIosBackground(ServiceInstance service) => true;

/// ✅ Background isolate entry point
/// (Removed Pedometer listener since step tracking is handled natively)
@pragma('vm:entry-point')
void onBackgroundStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  // REQUIRED: Put service in foreground mode
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
  }

  // Step listener
  Pedometer.stepCountStream.listen(
    (StepCount event) async {
      int steps = event.steps;
      await prefs.setInt("todaySteps", steps);

      print("📌 Background Steps: $steps");
      
      // ⚠️ Your version doesn't support updating notification text
    },
    onError: (e) => print("❌ Step error: $e"),
  );
}


/// ✅ Initializes the app (controllers, services, notifications)
Future<bool> initializeApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Setup timezone
  initializeTimeZones();
  setLocalLocation(getLocation('Asia/Kolkata'));

  // Initialize Hive
  await setupHive();

  // Request permissions (optional: you can enable this if needed)
  // await requestAllPermissions();

  // Initialize background service (optional if only native service handles steps)
  // await initializeService();

  // Setup notifications
  final notiff = Get.put(NotificationService());
  await notiff.init();

  final prefs = await SharedPreferences.getInstance();
  final alreadyScheduled = prefs.getBool('reminder_scheduled') ?? false;
  if (!alreadyScheduled) {
    await notiff.scheduleReminder(id: 100);
    await prefs.setBool('reminder_scheduled', true);
  }

  // Register controllers
  Get.put(ProfileSetupController());
  Get.put(SleepController());
  Get.put(StepCounterController());
  Get.put(MoodController());
  Get.put(SignInController());
  Get.put(VitalsController());
  Get.put(LocalStorageManager());
  Get.put(WomenHealthController());

  return prefs.getBool('remember_me') ?? false;
}
