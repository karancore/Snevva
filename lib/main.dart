import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/Controllers/BMI/bmi_controller.dart';
import 'package:snevva/Controllers/BMI/bmi_updatecontroller.dart';
import 'package:snevva/Controllers/DietPlan/diet_plan_controller.dart';
import 'package:snevva/Controllers/HealthTips/healthtips_controller.dart';
import 'package:snevva/Controllers/Hydration/hydration_stat_controller.dart';
import 'package:snevva/Controllers/MoodTracker/mood_controller.dart';
import 'package:snevva/Controllers/Reminder/event_controller.dart';
import 'package:snevva/Controllers/Reminder/meal_controller.dart';
import 'package:snevva/Controllers/Reminder/medicine_controller.dart';
import 'package:snevva/Controllers/Vitals/vitalsController.dart';
import 'package:snevva/Controllers/WomenHealth/women_health_controller.dart';
import 'package:snevva/Controllers/signupAndSignIn/otp_verification_controller.dart';
import 'package:snevva/Controllers/signupAndSignIn/sign_in_controller.dart';
import 'package:snevva/Controllers/signupAndSignIn/sign_up_controller.dart';
import 'package:snevva/Controllers/signupAndSignIn/update_old_password_controller.dart';
import 'package:snevva/services/firebase_init.dart';
import 'package:snevva/services/hive_service.dart';
import 'package:snevva/utils/theme_controller.dart';
import 'package:snevva/views/Information/Sleep%20Screen/sleep_tracker_screen.dart';
import 'package:snevva/views/MoodTracker/mood_tracker_screen.dart';
import 'Controllers/MentalWellness/mental_wellness_controller.dart';
import 'Controllers/ProfileSetupAndQuestionnare/editprofile_controller.dart';
import 'Controllers/ProfileSetupAndQuestionnare/profile_setup_controller.dart';
import 'Controllers/Reminder/water_controller.dart';
import 'Controllers/SleepScreen/sleep_controller.dart';
import 'Controllers/StepCounter/step_counter_controller.dart';
import 'Controllers/WomenHealth/bottom_sheet_controller.dart';
import 'Controllers/alerts/alerts_controller.dart';
import 'Controllers/local_storage_manager.dart';

import 'Controllers/signupAndSignIn/create_password_controller.dart';

import 'common/ExceptionLogger.dart';
import 'common/global_variables.dart';
import 'common/loader.dart';

import 'consts/consts.dart';

import 'firebase_options.dart';
import 'models/app_notification.dart';
import 'services/app_initializer.dart';
import 'services/notification_channel.dart';
import 'services/notification_service.dart';
import 'common/agent_debug_logger.dart';
import 'utils/theme.dart';
import 'views/Reminder/reminder_screen.dart';
import 'views/SignUp/sign_in_screen.dart';
import 'widgets/home_wrapper.dart';
Future<void> ensureFirebaseInitialized() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}

/// ------------------------------------------------------------
/// 🔔 Notification action handler
/// ------------------------------------------------------------
// @pragma('vm:entry-point')
// Future<void> notificationBackgroundHandler(
//   NotificationResponse response,
// ) async {
//   // Use the ID from the response if available, otherwise fallback to constant
//   final int notificationId = response.id ?? WAKE_NOTIFICATION_ID;
//   final fln = FlutterLocalNotificationsPlugin();
//   await fln.cancel(notificationId);
//
//   // if (response.actionId == 'STOP_ALARM') {
//   //   // 1. Mark as stopped for the main app to see later
//   //   final prefs = await SharedPreferences.getInstance();
//   //   await prefs.setBool('stop_alarm_pending', true);
//   //
//   //   // 2. Manual cancel (as a safety backup to cancelNotification: true)
//   //
//   //
//   //   debugPrint('🛑 Alarm $notificationId stopped in background');
//   // }
// }

/// ------------------------------------------------------------
/// 🔔 Firebase background handler (separate isolate)
/// ------------------------------------------------------------
///
///
///
class SleepLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Get.find<SleepController>().reloadSleep();
    }
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // await ensureFirebaseInitialized();
  await FirebaseInit.init();


  final prefs = await SharedPreferences.getInstance();
  final List existing = jsonDecode(
    prefs.getString('notifications_list') ?? '[]',
  );

  existing.insert(0, AppNotification.fromRemoteMessage(message).toJson());

  await prefs.setString('notifications_list', jsonEncode(existing));

  final fln = FlutterLocalNotificationsPlugin();

  const androidDetails = AndroidNotificationDetails(
    'high_importance_channel',
    'High Importance Notifications',
    importance: Importance.max,
    priority: Priority.high,
    icon: 'snevva_elly',
  );

  await fln.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    message.notification?.title ?? message.data['title'],
    message.notification?.body ?? message.data['body'],
    const NotificationDetails(android: androidDetails),
  );
}

/// ------------------------------------------------------------
/// 🚀 MAIN
/// ------------------------------------------------------------
void main() async {
  ErrorWidget.builder = (FlutterErrorDetails details) {
    // fire-and-forget
    ExceptionLogger.log(
      exception: details.exception,
      stackTrace: details.stack,
    );

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(errorIcon, scale: 2),
                    const SizedBox(height: 10),
                    const Text(
                      'Oops! Something went wrong.',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  };

  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      WidgetsBinding.instance.addObserver(SleepLifecycleObserver());

      // await ensureFirebaseInitialized();
      await FirebaseInit.init();

      // await setupHive();
      await HiveService().initMain();
      await initialiseGetxServicesAndControllers();

      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      final prefs = await SharedPreferences.getInstance();
      final isRemembered = prefs.getBool('remember_me') ?? false;

      runApp(MyApp(isRemembered: isRemembered));
    },
    (error, stack) async {
      await ExceptionLogger.log(exception: error, stackTrace: stack);
    },
  );
}

Future<void> initialiseGetxServicesAndControllers() async {
  if (!Hive.isBoxOpen('step_history')) {
    print("❌ Hive boxes not ready during controller init - retrying setup");
    await setupHive();  // Fallback retry
  }

  // Parallel async controllers
  await Future.wait([
    Get.putAsync<LocalStorageManager>(() async {
      final service = LocalStorageManager();
      await service
          .reloadUserMap(); // ensure data is loaded before anyone uses it
      return service;
    }, permanent: true),
    // Get.putAsync<AlertsController>(
    //   () async => AlertsController(),
    //   permanent: true,
    // ),
    Get.putAsync<SignInController>(
      () async => SignInController(),
      permanent: false,
    ),
    Get.putAsync<SleepController>(
      () async => SleepController(),
      permanent: false,
    ),
    Get.putAsync<SignUpController>(
      () async => SignUpController(),
      permanent: false,
    ),
    Get.putAsync<OTPVerificationController>(
      () async => OTPVerificationController(),
      permanent: false,
    ),
    Get.putAsync<UpdateOldPasswordController>(
      () async => UpdateOldPasswordController(),
      permanent: false,
    ),
    Get.putAsync<CreatePasswordController>(
      () async => CreatePasswordController(),
      permanent: false,
    ),
    Get.putAsync<ProfileSetupController>(
      () async => ProfileSetupController(),
      permanent: false,
    ),
    Get.putAsync<VitalsController>(
      () async => VitalsController(),
      permanent: false,
    ),
    Get.putAsync<HydrationStatController>(
      () async => HydrationStatController(),
      permanent: false,
    ),
    Get.putAsync<MoodController>(
      () async => MoodController(),
      permanent: false,
    ),
    Get.putAsync<EditprofileController>(
      () async => EditprofileController(),
      permanent: true,
    ),
    Get.putAsync<BmiUpdateController>(
      () async => BmiUpdateController(),
      permanent: true,
    ),
    Get.putAsync<BmiController>(() async => BmiController(), permanent: true),

    Get.putAsync<DietPlanController>(
      () async => DietPlanController(),
      permanent: true,
    ),
    Get.putAsync<HealthTipsController>(
      () async => HealthTipsController(),
      permanent: true,
    ),
  ]);

  // Synchronous controllers, lazy-loaded if not registered
  if (!Get.isRegistered<MentalWellnessController>()) {
    Get.lazyPut(() => MentalWellnessController(), fenix: true);
  }


  if (!Get.isRegistered<BottomSheetController>()) {
    Get.lazyPut(() => BottomSheetController(), fenix: true);
  }
  if (!Get.isRegistered<ThemeController>()) {
    Get.lazyPut(() => ThemeController(), fenix: true);
  }
  if (!Get.isRegistered<WomenHealthController>()) {
    Get.lazyPut(() => WomenHealthController(), fenix: true);
  }

  // Permanent controllers not async
  if (!Get.isRegistered<StepCounterController>()) {
    Get.put(StepCounterController(), permanent: true);
  }
  if (!Get.isRegistered<WaterController>()) {
    Get.put(WaterController(), permanent: true);
  }
  if (!Get.isRegistered<MedicineController>()) {
    Get.put(MedicineController(), permanent: true);
  }
  if (!Get.isRegistered<EventController>()) {
    Get.put(EventController(), permanent: true);
  }
  if (!Get.isRegistered<MealController>()) {
    Get.put(MealController(), permanent: true);
  }
}

/// ------------------------------------------------------------
/// 🏠 APP ROOT
/// ------------------------------------------------------------
class MyApp extends StatefulWidget {
  final bool isRemembered;

  const MyApp({super.key, required this.isRemembered});

  @override
  State<MyApp> createState() => _MyAppState();
}

enum AppInitState { loading, success, error }

class _MyAppState extends State<MyApp> {
  AppInitState _initState = AppInitState.loading;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();

    _safeInit();
    _handlePendingNavigation();
  }

  Future<void> _handlePendingNavigation() async {
    final prefs = await SharedPreferences.getInstance();

    if (prefs.getBool('navigate_to_sleep_tracker') == true) {
      prefs.remove('navigate_to_sleep_tracker');

      Get.to(() => SleepTrackerScreen());
    }
  }

  Future<void> _safeInit() async {
    // await ensureFirebaseInitialized();

    await FirebaseInit.init();

    try {
      PushNotificationService().initialize();
    } catch (_) {}

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      // await ensureFirebaseInitialized();
      await FirebaseInit.init();

    });

    _handleInitialMessage();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startTimeout();
      _initializeAppAsync();
    });
  }

  Future<void> _handleInitialMessage() async {
    // await ensureFirebaseInitialized();
    await FirebaseInit.init();


    final message = await FirebaseMessaging.instance.getInitialMessage();

    if (message != null) {
      logLong('NOTIFICATION', 'Opened from terminated: ${message.messageId}');
    }
  }

  void _startTimeout() {
    _timeoutTimer?.cancel();

    _timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && _initState == AppInitState.loading) {
        setState(() => _initState = AppInitState.error);
      }
    });
  }

  Future<void> _initializeAppAsync() async {
    try {
      setState(() => _initState = AppInitState.loading);

      await initializeApp().timeout(const Duration(seconds: 10));

      final hasSession =
          await Get.find<LocalStorageManager>().hasValidSession();

      if (hasSession) {
        if (!Get.isRegistered<AlertsController>()) {
          Get.lazyPut(() => AlertsController(), fenix: true);
        }
      }

      if (!hasSession) {
        Get.offAll(() => SignInScreen());
        return;
      }

      // If user session exists (auto-login), ensure background tracking is running.
      // #region agent log
      AgentDebugLogger.log(
        runId: 'auth-bg',
        hypothesisId: 'A',
        location: 'main.dart:_initializeAppAsync:hasSession_true',
        message: 'Valid session detected, starting unified background service',
        data: const {},
      );
      // #endregion
      await initBackgroundService();

      _timeoutTimer?.cancel();

      if (mounted) {
        setState(() => _initState = AppInitState.success);
      }
    } catch (e, s) {
      logLong('INIT ERROR', '$e\n$s');

      if (mounted) {
        setState(() => _initState = AppInitState.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      //initialBinding: InitialBindings(),
      title: 'Snevva',
      theme: SnevvaTheme.lightTheme,
      darkTheme: SnevvaTheme.darkTheme,
      themeMode: ThemeMode.system,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      locale: const Locale('en'),
      getPages: [
        GetPage(name: '/home', page: () => HomeWrapper()),
        GetPage(name: '/reminder', page: () => ReminderScreen()),
        GetPage(name: '/mood', page: () => MoodTrackerScreen()),
      ],
      home:
          _initState == AppInitState.loading
              ? const InitializationSplash()
              : _initState == AppInitState.success
              ? HomeWrapper()
              : ErrorPlaceholder(
                onRetry: () {
                  _startTimeout();
                  _initializeAppAsync();
                },
                details: '',
              ),
    );
  }
}

/// ------------------------------------------------------------
/// ⏳ Splash
/// ------------------------------------------------------------
class InitializationSplash extends StatelessWidget {
  const InitializationSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Loader()));
  }
}

/// ------------------------------------------------------------
/// ❌ Error UI
/// ------------------------------------------------------------
class ErrorPlaceholder extends StatelessWidget {
  final VoidCallback? onRetry;
  final String details;

  const ErrorPlaceholder({super.key, this.onRetry, required this.details});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(errorIcon, scale: 2),
            const SizedBox(height: 10),
            const Text(
              'Oops! Something went wrong.',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            // Optionally show a basic message for the user,
            // or log the full details to a service.
            Text(
              'An error occurred: ${details.toString()}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
