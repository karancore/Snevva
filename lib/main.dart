// main.dart - fixed Firebase initialization
// Key fixes:
// 1. Initialize Firebase in main() before runApp so any code in initState that
//    accesses FirebaseMessaging.instance (like PushNotificationService) doesn't
//    throw [core/no-app].
// 2. Guard Firebase.initializeApp calls with Firebase.apps.isEmpty to avoid
//    duplicate initialization.
// 3. Keep background handler initialization (required for background isolate)
//    but guard it as well.

import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:snevva/common/global_variables.dart';
import 'package:snevva/common/loader.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/initial_bindings.dart';
import 'package:snevva/services/app_initializer.dart';
import 'package:snevva/services/notification_channel.dart';
import 'package:snevva/services/notification_service.dart';
import 'package:snevva/utils/theme.dart';
import 'package:snevva/views/SignUp/sign_in_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'Controllers/alerts/alerts_controller.dart';
import 'firebase_options.dart';
import 'models/app_notification.dart';
import 'widgets/home_wrapper.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // This handler runs in its own background isolate; Firebase must be
  // initialized for that isolate too.
  WidgetsFlutterBinding.ensureInitialized();

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }

  final prefs = await SharedPreferences.getInstance();
  final List existing = jsonDecode(prefs.getString('notifications_list') ?? '[]');
  existing.insert(0, AppNotification.fromRemoteMessage(message).toJson());
  await prefs.setString('notifications_list', jsonEncode(existing));

  final FlutterLocalNotificationsPlugin fln = FlutterLocalNotificationsPlugin();

  const androidDetails = AndroidNotificationDetails(
    'high_importance_channel',
    'High Importance Notifications',
    icon: 'snevva_elly',
    importance: Importance.max,
    priority: Priority.high,
  );

  await fln.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    message.notification?.title ?? message.data['title'],
    message.notification?.body ?? message.data['body'],
    const NotificationDetails(android: androidDetails),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await setupHive();

  // Ensure Firebase is available synchronously before any widget's initState
  // runs and attempts to access FirebaseMessaging.instance.
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      logLong('INIT', 'Firebase initialized in main()');
    } else {
      logLong('INIT', 'Firebase already initialized');
    }
  } catch (e, s) {
    // Log but continue so app can still run (you might choose to rethrow)
    logLong('INIT ERROR', 'Firebase.initializeApp failed: $e\n$s');
  }

  // Register background handler after Firebase is (attempted to be) initialized.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ✅ Only check login status - don't do heavy init
  final prefs = await SharedPreferences.getInstance();
  final isRemembered = prefs.getBool('remember_me') ?? false;

  // ✅ Run app immediately - don't block
  runApp(MyApp(isRemembered: isRemembered));
}

class MyApp extends StatefulWidget {
  final bool isRemembered;

  const MyApp({super.key, required this.isRemembered});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();

    // Safe now: Firebase was initialized in main(). It's still a good idea to
    // make PushNotificationService initialization lightweight and resilient
    // if Firebase is unavailable.
    try {
      PushNotificationService().initialize();
    } catch (e, s) {
      logLong('PUSH INIT ERROR', '$e\n$s');
      // fallthrough - app will continue and _initializeAppAsync will handle
    }

    // Handle when the app is opened from a background notification tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      logLong("Notifications", message.toString());
      final notification = AppNotification.fromRemoteMessage(message);
      logLong("Remote Message", notification.title);
      if (Get.isRegistered<AlertsController>()) {
        Get.find<AlertsController>().addNotification(notification);
      }
    });

    // Handle when the app is opened from a terminated state
    _handleInitialMessage();

    // ✅ Do heavy initialization AFTER first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAppAsync();
    });
  }

  Future<void> _initializeAppAsync() async {
    try {
      logLong("INIT", "Starting app initialization");

      await initializeApp().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception("initializeApp() timed out");
        },
      );

      final notificationService = NotificationService();
      await notificationService.init();

      logLong("INIT", "Initialization finished");

      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e, s) {
      logLong("INIT ERROR", "$e\n$s");

      if (mounted) {
        setState(() => _isInitialized = true); // allow app to continue
      }
    }
  }

  Future<void> _handleInitialMessage() async {
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      print(
        'App opened from terminated state via notification: ${initialMessage.messageId}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      initialBinding: InitialBindings(),
      debugShowCheckedModeBanner: false,
      title: "Snevva",
      theme: SnevvaTheme.lightTheme,
      darkTheme: SnevvaTheme.darkTheme,
      themeMode: ThemeMode.system,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),

      home: _isInitialized
          ? (widget.isRemembered ? HomeWrapper() : SignInScreen())
          : const InitializationSplash(),
    );
  }
}

// ✅ Simple splash screen during initialization
class InitializationSplash extends StatelessWidget {
  const InitializationSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Your app logo here
            const Loader(),
            const SizedBox(height: 24),
            Text('Loading...', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
