import 'dart:async';
import 'dart:convert';

import 'package:alarm/alarm.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/Controllers/BMI/bmi_controller.dart';
import 'package:snevva/Controllers/DietPlan/diet_plan_controller.dart';
import 'package:snevva/Controllers/HealthTips/healthtips_controller.dart';
import 'package:snevva/Controllers/Hydration/hydration_stat_controller.dart';
import 'package:snevva/Controllers/MoodTracker/mood_controller.dart';
import 'package:snevva/Controllers/Vitals/vitalsController.dart';
import 'package:snevva/Controllers/signupAndSignIn/otp_verification_controller.dart';
import 'package:snevva/Controllers/signupAndSignIn/sign_in_controller.dart';
import 'package:snevva/Controllers/signupAndSignIn/sign_up_controller.dart';
import 'package:snevva/Controllers/signupAndSignIn/update_old_password_controller.dart';
import 'package:snevva/utils/theme_controller.dart';
import 'package:snevva/views/Information/Sleep%20Screen/sleep_tracker_screen.dart';

import 'Controllers/MentalWellness/mental_wellness_controller.dart';
import 'Controllers/ProfileSetupAndQuestionnare/editprofile_controller.dart';
import 'Controllers/ProfileSetupAndQuestionnare/profile_setup_controller.dart';
import 'Controllers/SleepScreen/sleep_controller.dart';
import 'Controllers/StepCounter/step_counter_controller.dart';
import 'Controllers/WomenHealth/bottom_sheet_controller.dart';
import 'Controllers/alerts/alerts_controller.dart';
import 'Controllers/local_storage_manager.dart';

import 'Controllers/signupAndSignIn/create_password_controller.dart';
import 'bindings/initial_bindings.dart';

import 'common/ExceptionLogger.dart';
import 'common/global_variables.dart';
import 'common/loader.dart';

import 'consts/consts.dart';

import 'firebase_options.dart';

import 'models/app_notification.dart';

import 'services/app_initializer.dart';
import 'services/device_token_service.dart';
import 'services/notification_channel.dart';
import 'services/notification_service.dart';

import 'utils/theme.dart';

import 'views/Reminder/reminder_screen.dart';
import 'views/SignUp/sign_in_screen.dart';

import 'widgets/home_wrapper.dart';

/// ------------------------------------------------------------
/// 🔐 Firebase guard — REQUIRED everywhere
/// ------------------------------------------------------------
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
@pragma('vm:entry-point')
Future<void> notificationBackgroundHandler(
  NotificationResponse response,
) async {
  if (response.actionId == 'STOP_ALARM') {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('navigate_to_sleep_tracker', true);

    print('🛑 STOP_ALARM stored for next app resume');
  }
}

/// ------------------------------------------------------------
/// 🔔 Firebase background handler (separate isolate)
/// ------------------------------------------------------------
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await ensureFirebaseInitialized();

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
  WidgetsFlutterBinding.ensureInitialized();

  await initialiseGetxServicesAndControllers();

  await setupHive();

  await ensureFirebaseInitialized();

  // 🔥 Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    //
    // ExceptionLogger.log(
    //   exception: details.exception,
    //   stackTrace: details.stack,
    //   methodName: 'FlutterError.onError',
    //   className: 'main.dart',
    // );

    if (kReleaseMode) {
      ErrorPlaceholder(details: details.toString());
    } else if (kDebugMode) {
      ErrorPlaceholder(details: details.toString());
    }
  };

  // 🔥 Dart / async / isolate errors
  runZonedGuarded(
    () async {
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      final prefs = await SharedPreferences.getInstance();
      final isRemembered = prefs.getBool('remember_me') ?? false;

      runApp(MyApp(isRemembered: isRemembered));
    },
    (error, stack) {
      // ExceptionLogger.log(
      //   exception: error.toString(),
      //   stackTrace: stack,
      //   methodName: 'FlutterError.onError',
      //   className: 'main.dart',
      // );

      ErrorPlaceholder(details: stack.toString());
    },
  );
}

Future<void> initialiseGetxServicesAndControllers() async {
  await Get.putAsync<LocalStorageManager>(() async {
    final service = LocalStorageManager();
    return service;
  }, permanent: true);
  await Get.putAsync<AlertsController>(() async {
    final service = AlertsController();
    return service;
  }, permanent: true);
  await Get.putAsync<SignInController>(() async {
    final service = SignInController();
    return service;
  }, permanent: false);
  await Get.putAsync<SignUpController>(() async {
    final service = SignUpController();
    return service;
  }, permanent: false);
  await Get.putAsync<OTPVerificationController>(() async {
    final service = OTPVerificationController();
    return service;
  }, permanent: false);
  await Get.putAsync<UpdateOldPasswordController>(() async {
    final service = UpdateOldPasswordController();
    return service;
  }, permanent: false);
  await Get.putAsync<CreatePasswordController>(() async {
    final service = CreatePasswordController();
    return service;
  }, permanent: false);
  await Get.putAsync<ProfileSetupController>(() async {
    final service = ProfileSetupController();
    return service;
  }, permanent: false);
  await Get.putAsync<VitalsController>(() async {
    final service = VitalsController();
    return service;
  }, permanent: false);
  await Get.putAsync<HydrationStatController>(() async {
    final service = HydrationStatController();
    return service;
  }, permanent: false);
  await Get.putAsync<MoodController>(() async {
    final service = MoodController();
    return service;
  }, permanent: false);
  await Get.putAsync<EditprofileController>(() async {
    final service = EditprofileController();
    return service;
  }, permanent: true);
  await Get.putAsync<StepCounterController>(() async {
    final service = StepCounterController();
    return service;
  }, permanent: true);
  await Get.putAsync<BmiController>(() async {
    final service = BmiController();
    return service;
  }, permanent: true);
  await Get.putAsync<DietPlanController>(() async {
    final service = DietPlanController();
    return service;
  }, permanent: true);
  await Get.putAsync<HealthTipsController>(() async {
    final service = HealthTipsController();
    return service;
  }, permanent: true);
  if (!Get.isRegistered<MentalWellnessController>()) {
    Get.lazyPut(() => MentalWellnessController(), fenix: true);
  }
  if (!Get.isRegistered<BottomSheetController>()) {
    Get.lazyPut(() => BottomSheetController(), fenix: true);
  }
  if (!Get.isRegistered<ThemeController>()) {
    Get.lazyPut(() => ThemeController(), fenix: true);
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
    await ensureFirebaseInitialized();

    try {
      PushNotificationService().initialize();
    } catch (_) {}

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      await ensureFirebaseInitialized();

      final notification = AppNotification.fromRemoteMessage(message);

      if (Get.isRegistered<AlertsController>()) {
        Get.find<AlertsController>().addNotification(notification);
      }
    });

    _handleInitialMessage();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startTimeout();
      _initializeAppAsync();
    });
  }

  Future<void> _handleInitialMessage() async {
    await ensureFirebaseInitialized();

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

      if (!hasSession) {
        Get.offAll(() => SignInScreen());
        return;
      }

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
