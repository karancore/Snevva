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
import 'package:snevva/services/firebase_init.dart';
import 'package:snevva/services/google_auth.dart';
import 'package:snevva/services/hive_service.dart';
import 'package:snevva/utils/theme_controller.dart';
import 'package:snevva/views/Information/Sleep%20Screen/sleep_tracker_screen.dart';
import 'package:snevva/views/MoodTracker/mood_tracker_screen.dart';
import 'package:snevva/views/ProfileAndQuestionnaire/profile_setup_initial.dart';
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
void main() {
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

      final prefs = await SharedPreferences.getInstance();
      final isRemembered = prefs.getBool('remember_me') ?? false;

      _registerCriticalDependencies();
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      runApp(MyApp(isRemembered: isRemembered));
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

Map<String, int> _mergeSleepHistoryRows(List<Map<String, dynamic>> rows) {
  final merged = <String, int>{};

  for (final row in rows) {
    final key = row['key'];
    final minutes = row['minutes'];
    if (key is! String || minutes is! int) continue;

    final current = merged[key] ?? 0;
    if (minutes > current) {
      merged[key] = minutes;
    }
  }

  return merged;
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

  const MyApp({super.key, required this.isRemembered});

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

  @override
  void initState() {
    super.initState();
    _themeController = Get.find<ThemeController>();

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startTimeout();
      _stage2Future ??= _runStage2AfterFirstFrame();
      _initializeAppAsync();
    });
  }

  Future<void> _runStage2AfterFirstFrame() async {
    try {
      await Future.wait([
        HiveService().initMain(),
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

      final splashDelay = Future.delayed(const Duration(seconds: 3));
      final initFuture = initializeApp().timeout(const Duration(seconds: 10));

      await Future.wait([splashDelay, initFuture]);
      await Future.delayed(const Duration(milliseconds: 200));
      final prefs = await SharedPreferences.getInstance();
      final hasSession = (prefs.getString('auth_token') ?? '').isNotEmpty;

      if (!hasSession) {
        _runStage3BackgroundTasks(hasSession: false);
        Get.offAll(() => SignInScreen());
        return;
      }

      if (!Get.isRegistered<AlertsController>()) {
        Get.lazyPut(() => AlertsController(), fenix: true);
      }

      _timeoutTimer?.cancel();

      if (mounted) {
        setState(() => _initState = AppInitState.success);
      }

      _runStage3BackgroundTasks(hasSession: true);
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
      Future<void>(() async {
        await _cleanupExpiredStartupAlarms();
        await _mergeSleepHistoryInBackground();
        await _scanLargeSharedPreferences();

        if (!hasSession) return;

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

    for (final id in idsToStop) {
      await Alarm.stop(id);
    }
  }

  Future<void> _mergeSleepHistoryInBackground() async {
    final sleepBox = await HiveService().sleepLogBox();
    if (sleepBox.length < 180) return;

    final rows = sleepBox.values
        .map(
          (log) => <String, dynamic>{
            'key':
                '${log.date.year}-'
                '${log.date.month.toString().padLeft(2, '0')}-'
                '${log.date.day.toString().padLeft(2, '0')}',
            'minutes': log.durationMinutes,
          },
        )
        .toList(growable: false);

    if (rows.length >= 180) {
      await compute(_mergeSleepHistoryRows, rows);
      return;
    }
    _mergeSleepHistoryRows(rows);
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
        debugShowCheckedModeBanner: false,
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
        ],
        home:
            _initState == AppInitState.loading
                ? AnimatedOpacity(
                  opacity: _initState == AppInitState.loading ? 1 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: const InitializationSplash(),
                )
                : _initState == AppInitState.success
                ? HomeWrapper()
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
    return const Scaffold(body: Center(child: HeartBeatLoader()));
  }
}

class HeartBeatLoader extends StatefulWidget {
  final Duration duration;

  const HeartBeatLoader({
    super.key,
    this.duration = const Duration(milliseconds: 2400),
  });

  @override
  State<HeartBeatLoader> createState() => _HeartBeatLoaderState();
}

class _HeartBeatLoaderState extends State<HeartBeatLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: widget.duration);

    _controller.forward(); // IMPORTANT → only once (loader)
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      width: 120,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, _) {
          return RepaintBoundary(
            child: CustomPaint(
              painter: _HeartBeatLoaderPainter(progress: _controller.value),
            ),
          );
        },
      ),
    );
  }
}

class _HeartBeatLoaderPainter extends CustomPainter {
  final double progress;

  _HeartBeatLoaderPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.red
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    final path = Path();
    final midY = size.height / 2;
    double x = 0;
    path.moveTo(0, midY);
    // -------- ECG pattern ----------
    while (x < size.width - 20) {

      path.lineTo(x += 15, midY);
      path.lineTo(x += 2, midY - 7);
      path.lineTo(x += 2, midY);

      path.lineTo(x += 12, midY);
      path.lineTo(x += 8, midY - 32);
      path.lineTo(x += 6, midY + 24);
      path.lineTo(x += 6, midY - 10);
      path.lineTo(x += 2, midY);

      path.lineTo(x += 15, midY);
      path.lineTo(x += 2, midY - 7);
      path.lineTo(x += 2, midY);

      path.lineTo(x += 18, midY);
      path.lineTo(x += 4, midY - 16);
      path.lineTo(x += 6, midY + 12);
      path.lineTo(x += 2, midY);

      path.lineTo(x += 8, midY);
      path.lineTo(x += 2, midY - 7);
      path.lineTo(x += 2, midY);

      path.lineTo(x += 10, midY - 32);
      path.lineTo(x += 10, midY + 24);

      path.lineTo(x += 8, midY);

      path.lineTo(x += 16, midY);
    }

    final metrics = path.computeMetrics().first;
    if (metrics.isClosed) return;
    final animatedPath = metrics.extractPath(0, metrics.length * progress);
    final tangent = metrics.getTangentForOffset(metrics.length * progress);

    if (tangent != null) {
      final dotPaint =
          Paint()
            ..color = Colors.red
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      canvas.drawCircle(tangent.position, 4, dotPaint);
    }
    canvas.drawPath(animatedPath, paint);
  }

  @override
  bool shouldRepaint(covariant _HeartBeatLoaderPainter oldDelegate) {
    return oldDelegate.progress != progress;
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
              ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
