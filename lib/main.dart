import 'dart:async';
import 'dart:convert';

import 'package:alarm/alarm.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
import 'package:snevva/Controllers/Reminder/reminder_controller.dart';
import 'package:snevva/Controllers/Vitals/vitalsController.dart';
import 'package:snevva/Controllers/WomenHealth/women_health_controller.dart';
import 'package:snevva/Controllers/signupAndSignIn/otp_verification_controller.dart';
import 'package:snevva/Controllers/signupAndSignIn/sign_in_controller.dart';
import 'package:snevva/Controllers/signupAndSignIn/sign_up_controller.dart';
import 'package:snevva/Controllers/signupAndSignIn/update_old_password_controller.dart';
import 'package:snevva/services/connectivity_service.dart';
import 'package:snevva/services/firebase_init.dart';
import 'package:snevva/services/google_auth.dart';
import 'package:snevva/utils/push_notifications_controller.dart';
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
import 'common/agent_debug_logger.dart';
import 'common/global_variables.dart';
import 'common/no_internet_banner.dart';
import 'consts/consts.dart';
import 'firebase_options.dart';
import 'performance/frame_timing_monitor.dart';
import 'performance/refresh_rate_bootstrap.dart';
import 'services/app_initializer.dart';
import 'services/notification_channel.dart';
import 'services/reminder/reconciliation_engine.dart' as snevva_reconciliation;
import 'utils/theme.dart';
import 'views/Reminder/reminder_screen.dart';
import 'views/SignUp/sign_in_screen.dart';
import 'views/debug/high_fps_demo_screen.dart';
import 'widgets/home_wrapper.dart';

//Test User - 7814254444
//Admin@1234
const bool _kShowPerformanceOverlay = bool.fromEnvironment(
  'SHOW_PERFORMANCE_OVERLAY',
  defaultValue: false,
);

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<bool> _hasValidSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return token != null && token.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasValidSession(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const InitializationSplash();
        }

        if (snapshot.data == false) {
          return SignInScreen(); // ❌ No token → ONLY LOGIN
        }

        return HomeWrapper(); // ✅ Valid session
      },
    );
  }
}

Future<void> ensureFirebaseInitialized() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // await ensureFirebaseInitialized();
  await FirebaseInit.init();
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
void main() {
  ErrorWidget.builder = (FlutterErrorDetails details) {
    ExceptionLogger.log(
      exception: details.exception,
      stackTrace: details.stack,
    );

    return Builder(
      builder: (context) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final overlay = Overlay.of(context);
          overlay?.insert(
            OverlayEntry(
              builder: (context) {
                return Material(
                  color: white,
                  child: Center(
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
                );
              },
            ),
          );
        });

        return const SizedBox(); // 👈 REQUIRED return
      },
    );
  };

  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Register the step MethodChannel so the native StepCounterService can
      // deliver step counts to this Flutter engine via onStepDetected.
      const stepChannel = MethodChannel('com.coretegra.snevvaa/step_detector');
      stepChannel.setMethodCallHandler((call) async {
        if (call.method == 'onStepDetected') {
          // Write directly to SharedPrefs so the controller poller picks it up
          // even if the background service isolate isn't running yet.
          final p = await SharedPreferences.getInstance();
          final steps = call.arguments as int;
          await p.setInt('today_steps', steps);
          FlutterBackgroundService().invoke('onStepDetected', {
            'steps': call.arguments,
          });
        } else if (call.method == 'onAlarmWakeup') {
          FlutterBackgroundService().invoke('onAlarmWakeup');
        }
      });

      final refreshRateProfile = await RefreshRateBootstrap.initialize();

      if (kDebugMode || kProfileMode) {
        FrameTimingMonitor.instance.start(
          targetFrameRateHz: refreshRateProfile.targetFrameRateHz,
        );
      }

      final prefs = await SharedPreferences.getInstance();
      final isRemembered = prefs.getBool('remember_me') ?? false;

      _registerCriticalDependencies();
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      runApp(
        MyApp(
          isRemembered: isRemembered,
          refreshRateProfile: refreshRateProfile,
        ),
      );
    },
    (error, stack) async {
      await ExceptionLogger.log(exception: error, stackTrace: stack);
    },
  );
}

void _registerCriticalDependencies() {
  if (!Get.isRegistered<ThemeController>()) {
    Get.put(ThemeController(), permanent: true);
  }
  if (!Get.isRegistered<PushNotificationsController>()) {
    Get.put(PushNotificationsController(), permanent: true);
  }

  _registerLazyDependencies();
}

void _registerLazyDependencies() {
  _lazyPut<LocalStorageManager>(() => LocalStorageManager());

  _lazyPut<SignInController>(() => SignInController());
  _lazyPut<SignUpController>(() => SignUpController());
  _lazyPut<OTPVerificationController>(() => OTPVerificationController());
  _lazyPut<UpdateOldPasswordController>(() => UpdateOldPasswordController());
  _lazyPut<CreatePasswordController>(() => CreatePasswordController());
  _lazyPut<ProfileSetupController>(() => ProfileSetupController());
  _lazyPut<EditprofileController>(() => EditprofileController());

  _lazyPut<VitalsController>(() => VitalsController());
  _lazyPut<HydrationStatController>(() => HydrationStatController());
  _lazyPut<MoodController>(() => MoodController());
  _lazyPut<WomenHealthController>(() => WomenHealthController());
  _lazyPut<BottomSheetController>(() => BottomSheetController());

  _lazyPut<BmiController>(() => BmiController());
  _lazyPut<BmiUpdateController>(() => BmiUpdateController());
  _lazyPut<GoogleAuthService>(() => GoogleAuthService());
  _lazyPut<DietPlanController>(() => DietPlanController());
  _lazyPut<HealthTipsController>(() => HealthTipsController());
  _lazyPut<MentalWellnessController>(() => MentalWellnessController());

  _lazyPut<SleepController>(() => SleepController());
  _lazyPut<StepCounterController>(() => StepCounterController());
  _lazyPutTagged<ReminderController>(
    () => ReminderController(),
    tag: 'reminder',
  );

  _lazyPut<WaterController>(() => WaterController());
  _lazyPut<MedicineController>(() => MedicineController());
  _lazyPut<EventController>(() => EventController());
  _lazyPut<MealController>(() => MealController());
  _lazyPut<AlertsController>(() => AlertsController());
}

void _lazyPut<T>(T Function() builder) {
  if (Get.isRegistered<T>()) return;
  Get.lazyPut<T>(builder, fenix: true);
}

void _lazyPutTagged<T>(T Function() builder, {required String tag}) {
  if (Get.isRegistered<T>(tag: tag)) return;
  Get.lazyPut<T>(builder, tag: tag, fenix: true);
}

List<int> _findExpiredBeforeAlarmIdsForStartup(Map<String, dynamic> payload) {
  final now = DateTime.fromMillisecondsSinceEpoch(payload['nowEpochMs'] as int);
  final alarms = (payload['alarms'] as List).cast<Map<String, dynamic>>();
  final expiredIds = <int>[];

  for (final alarm in alarms) {
    final raw = alarm['payload'];
    if (raw is! String) continue;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) continue;
      if (decoded['type'] != 'before') continue;

      final mainTimeRaw = decoded['mainTime'];
      if (mainTimeRaw is! String) continue;

      final mainTime = DateTime.tryParse(mainTimeRaw);
      final id = alarm['id'];
      if (mainTime != null && id is int && now.isAfter(mainTime)) {
        expiredIds.add(id);
      }
    } catch (_) {}
  }

  return expiredIds;
}



int _countLargePrefsCandidates(List<String> keys) {
  var count = 0;
  for (final key in keys) {
    if (key.startsWith('sleep_') ||
        key.startsWith('notification_') ||
        key.contains('history')) {
      count++;
    }
  }
  return count;
}

/// ------------------------------------------------------------
/// 🏠 APP ROOT
/// ------------------------------------------------------------
class MyApp extends StatefulWidget {
  final bool isRemembered;
  final RefreshRateProfile refreshRateProfile;

  const MyApp({
    super.key,
    required this.isRemembered,
    required this.refreshRateProfile,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

enum AppInitState { loading, success, error }

class _MyAppState extends State<MyApp> {
  AppInitState _initState = AppInitState.loading;
  Timer? _timeoutTimer;
  Future<void>? _stage2Future;
  bool _stage3Started = false;
  late final ThemeController _themeController;

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<bool>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _themeController = Get.find<ThemeController>();


    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final updatedProfile = RefreshRateBootstrap.updateFromContext(context);
      if (updatedProfile == null) return;

      if (kDebugMode || kProfileMode) {
        FrameTimingMonitor.instance.updateTargetFrameRate(
          updatedProfile.targetFrameRateHz,
        );
      }
    });

    _safeInit();
    _handlePendingNavigation();

    ConnectivityService().init();

    // 👇 Check current state immediately on launch
    Connectivity().checkConnectivity().then((results) {
      final isConnected = results.any((r) => r != ConnectivityResult.none);
      if (!isConnected) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final context = Get.overlayContext;
          if (context != null) NoInternetBanner.show(context);
        });
      }
    });

    _connectivitySub =
        ConnectivityService().onConnectivityChanged.listen((isConnected) {
          final context = Get.overlayContext;
          if (context == null) return;
          if (!isConnected) {
            NoInternetBanner.show(context);
          } else {
            debugPrint('Connectivity restored, hiding banner');
            NoInternetBanner.hide();
          }
        });
  }


  @override
  void dispose() {
    _connectivitySub?.cancel();
    NoInternetBanner.hide();
    super.dispose();
  }

  Future<void> _handlePendingNavigation() async {
    final prefs = await SharedPreferences.getInstance();

    if (prefs.getBool('navigate_to_sleep_tracker') == true) {
      prefs.remove('navigate_to_sleep_tracker');

      Get.to(() => SleepTrackerScreen());
    }
  }

  Future<void> _safeInit() async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startTimeout();
      _stage2Future ??= _runStage2AfterFirstFrame();
      _initializeAppAsync();
    });
  }

  Future<void> _runStage2AfterFirstFrame() async {
    try {
      await Future.wait([
        ensureFirebaseInitialized(),
        _warmCriticalPostFrameServices(),
      ]);

      try {
        PushNotificationService().initialize();
      } catch (_) {}

      FirebaseMessaging.onMessageOpenedApp.listen((_) {});
      await _handleInitialMessage();
      await _runDeferredFeatureWarmups();
    } catch (e, s) {
      logLong('STAGE2 INIT ERROR', '$e\n$s');
    }
  }

  Future<void> _warmCriticalPostFrameServices() async {
    final localStorage = Get.find<LocalStorageManager>();
    await localStorage.reloadUserMap();
  }

  Future<void> _runDeferredFeatureWarmups() async {
    final deferredWarmups = <Future<void>>[];

    if (_isTaggedControllerInstantiated<ReminderController>('reminder')) {
      deferredWarmups.add(
        Get.find<ReminderController>(tag: 'reminder').loadAllReminderLists(),
      );
    }
    if (_isControllerInstantiated<ProfileSetupController>()) {
      deferredWarmups.add(Get.find<ProfileSetupController>().loadSavedImage());
    }
    if (_isControllerInstantiated<HealthTipsController>()) {
      deferredWarmups.add(
        Get.find<HealthTipsController>().GetCustomHealthTips(),
      );
    }

    if (deferredWarmups.isNotEmpty) {
      await Future.wait(deferredWarmups);
    }
  }

  bool _isControllerInstantiated<T>() =>
      Get.isRegistered<T>() && !Get.isPrepared<T>();

  bool _isTaggedControllerInstantiated<T>(String tag) =>
      Get.isRegistered<T>(tag: tag) && !Get.isPrepared<T>(tag: tag);

  Future<void> _handleInitialMessage() async {
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

      final splashDelay = Future.delayed(const Duration(milliseconds: 1500));
      final initFuture = initializeApp().timeout(const Duration(seconds: 10));

      await Future.wait([splashDelay, initFuture]);
      await Future.delayed(const Duration(milliseconds: 200));
      final prefs = await SharedPreferences.getInstance();
      final hasSession = (prefs.getString('auth_token') ?? '').isNotEmpty;

      _timeoutTimer?.cancel();

      if (mounted) {
        setState(() => _initState = AppInitState.success);
      }

      // 🚀 Only control background tasks here
      _runStage3BackgroundTasks(hasSession: hasSession);

      if (!Get.isRegistered<AlertsController>()) {
        Get.lazyPut(() => AlertsController(), fenix: true);
      }

      _timeoutTimer?.cancel();

      if (mounted) {
        setState(() => _initState = AppInitState.success);
      }

      // ⚠️ Removed second _runStage3BackgroundTasks(hasSession: true) call that
      // was dead code (blocked by _stage3Started guard) but had a dangerous
      // hardcoded hasSession=true which could start the background service
      // for logged-out users if the guard was ever removed.

    } catch (e, s) {
      logLong('INIT ERROR', '$e\n$s');

      if (mounted) {
        setState(() => _initState = AppInitState.error);
      }
    }
  }

  void _runStage3BackgroundTasks({required bool hasSession}) {
    if (_stage3Started) return;
    _stage3Started = true;

    unawaited(
      // ✅ Delay 1 s so the splash→home transition renders at full FPS
      // before the background-isolate JIT spike hits.
      Future<void>.delayed(const Duration(seconds: 1), () async {
        // ✅ Run independent prep tasks in parallel instead of sequentially.
        await Future.wait([
          _cleanupExpiredStartupAlarms(),
          _mergeSleepHistoryInBackground(),
          _scanLargeSharedPreferences(),
        ]);

        if (!hasSession) return;

        try {
          // ✅ Use batch mode so all per-reminder saves during reconciliation
          // are accumulated in memory and flushed in a single Hive pass at
          // the end, instead of N × (4 reads + 4 writes) on the event loop.
          final controller = Get.isRegistered<ReminderController>(tag: 'reminder')
              ? Get.find<ReminderController>(tag: 'reminder')
              : null;

          controller?.beginBatchUpdate();
          try {
            final engine = snevva_reconciliation.ReconciliationEngine(
              saveReminder: (reminder) async {
                if (Get.isRegistered<ReminderController>(tag: 'reminder')) {
                  Get.find<ReminderController>(tag: 'reminder')
                      .updateReminderLocalOnly(reminder);
                }
              },
            );
            await engine.handleTimezoneStartupChecks();
          } finally {
            // Always flush, even if reconciliation threw an error.
            await controller?.endBatchUpdate();
          }
        } catch (e, s) {
          logLong('RECONCILIATION ERROR', '$e\n$s');
        }

        AgentDebugLogger.log(
          runId: 'auth-bg',
          hypothesisId: 'A',
          location: 'main.dart:_runStage3BackgroundTasks',
          message: 'Stage 3 started - configuring unified background service',
          data: const {},
        );
        await initBackgroundService();
      }),
    );
  }

  Future<void> _cleanupExpiredStartupAlarms() async {
    final alarms = await Alarm.getAlarms();
    if (alarms.isEmpty) return;

    final payload = <String, dynamic>{
      'nowEpochMs': DateTime.now().millisecondsSinceEpoch,
      'alarms': alarms
          .where((alarm) => alarm.payload != null)
          .map(
            (alarm) => <String, dynamic>{
              'id': alarm.id,
              'payload': alarm.payload!,
            },
          )
          .toList(growable: false),
    };

    final alarmPayload = (payload['alarms'] as List);
    if (alarmPayload.isEmpty) return;

    final idsToStop =
        alarmPayload.length >= 100
            ? await compute(_findExpiredBeforeAlarmIdsForStartup, payload)
            : _findExpiredBeforeAlarmIdsForStartup(payload);

    // \u2705 Stop all expired alarms concurrently instead of one-at-a-time.
    if (idsToStop.isNotEmpty) {
      await Future.wait(
        idsToStop.map((id) => Alarm.stop(id).catchError((_) => false)),
      );
    }
  }

  Future<void> _mergeSleepHistoryInBackground() async {
    // Sleep history is now stored in daily JSON files — no Hive box needed.
    // This method is a no-op; the file-based store never grows unbounded.
    debugPrint('ℹ️ _mergeSleepHistoryInBackground: file-based store, skipping');
  }

  Future<void> _scanLargeSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().toList(growable: false);
    if (keys.length < 250) return;

    await compute(_countLargePrefsCandidates, keys);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => GetMaterialApp(
        navigatorKey: _navigatorKey,
        debugShowCheckedModeBanner: false,
        showPerformanceOverlay:
            _kShowPerformanceOverlay && (kDebugMode || kProfileMode),
        //initialBinding: InitialBindings(),
        title: 'Snevva',
        theme: SnevvaTheme.lightTheme,
        darkTheme: SnevvaTheme.darkTheme,
        themeMode: _themeController.themeMode,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        locale: const Locale('en'),
        getPages: [
          GetPage(name: '/home', page: () => HomeWrapper()),
          GetPage(name: '/reminder', page: () => ReminderScreen()),
          GetPage(name: '/mood', page: () => MoodTrackerScreen()),
          GetPage(name: '/perf-120', page: () => const HighFpsDemoScreen()),
        ],
        home:
            _initState == AppInitState.loading
                ? AnimatedOpacity(
                  opacity: _initState == AppInitState.loading ? 1 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: const InitializationSplash(),
                )
                : _initState == AppInitState.success
                ? const AuthGate()
                : ErrorPlaceholder(
                  onRetry: () {
                    _startTimeout();
                    _initializeAppAsync();
                  },
                  details: '',
                ),
      ),
    );
  }
}

class InitializationSplash extends StatelessWidget {
  const InitializationSplash({super.key});

  @override
  Widget build(BuildContext context) {
    const double splashContentWidth = 220;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color splashBackground = isDarkMode ? black : white;
    final Color subtitleColor = isDarkMode ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: splashBackground,

      body: Center(
        child: SizedBox(
          width: splashContentWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const AppLoader(),
              const SizedBox(height: 24),
              Text(
                "Monitoring What Matters",
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: 16,
                  letterSpacing: 0.5,
                  color: subtitleColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
