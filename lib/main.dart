// import 'package:alarm/alarm.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:snevva/Widgets/home_wrapper.dart';
// import 'package:snevva/consts/consts.dart';
// import 'package:snevva/initial_bindings.dart';
// import 'package:snevva/services/app_initializer.dart';
// import 'package:snevva/services/notification_channel.dart';
// import 'package:snevva/utils/theme.dart';
// import 'package:snevva/views/SignUp/sign_in_screen.dart';
// import 'package:firebase_core/firebase_core.dart';
//
// import 'firebase_options.dart';
//
// @pragma('vm:entry-point')
// Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
//
//   final FlutterLocalNotificationsPlugin fln = FlutterLocalNotificationsPlugin();
//
//   const androidDetails = AndroidNotificationDetails(
//     'high_importance_channel',
//     'High Importance Notifications',
//     importance: Importance.max,
//     priority: Priority.high,
//   );
//
//   await fln.show(
//     DateTime.now().millisecondsSinceEpoch ~/ 1000,
//     message.notification?.title ?? message.data['title'],
//     message.notification?.body ?? message.data['body'],
//     const NotificationDetails(android: androidDetails),
//   );
// }
//
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//
//   if (Firebase.apps.isEmpty) {
//     await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
//   }
//   FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
//
//   await FirebaseMessaging.instance.requestPermission();
//   await setupNotificationChannel();
//   await Alarm.init();
//   final isRemembered = await initializeApp();
//
//   runApp(MyApp(isRemembered: isRemembered));
// }
//
// class MyApp extends StatefulWidget {
//   final bool isRemembered;
//
//   const MyApp({super.key, required this.isRemembered});
//
//   @override
//   State<MyApp> createState() => _MyAppState();
// }
//
// class _MyAppState extends State<MyApp> {
//   @override
//   void initState() {
//     super.initState();
//     PushNotificationService().initialize();
//
//     // Handle when the app is opened from a background notification tap
//     FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
//       print(
//         'App opened from background via notification: ${message.messageId}',
//       );
//       // Navigate based on message data...
//     });
//
//     // Handle when the app is opened from a terminated state
//     _handleInitialMessage();
//   }
//
//   Future<void> _handleInitialMessage() async {
//     RemoteMessage? initialMessage =
//         await FirebaseMessaging.instance.getInitialMessage();
//
//     if (initialMessage != null) {
//       print(
//         'App opened from terminated state via notification: ${initialMessage.messageId}',
//       );
//       // Navigate based on initial message data...
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return GetMaterialApp(
//       initialBinding: InitialBindings(),
//       debugShowCheckedModeBanner: false,
//       title: "Snevva",
//       theme: SnevvaTheme.lightTheme,
//       darkTheme: SnevvaTheme.darkTheme,
//       themeMode: ThemeMode.system,
//       localizationsDelegates: AppLocalizations.localizationsDelegates,
//       supportedLocales: AppLocalizations.supportedLocales,
//       locale: const Locale('en'),
//
//       home: widget.isRemembered ? HomeWrapper() : SignInScreen(),
//     );
//   }
// }
import 'dart:convert';

import 'package:alarm/alarm.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

import 'package:snevva/common/global_variables.dart';
import 'package:snevva/common/loader.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/initial_bindings.dart';
import 'package:snevva/services/app_initializer.dart';
import 'package:snevva/services/notification_channel.dart';
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
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final prefs = await SharedPreferences.getInstance();
  final List existing = jsonDecode(
    prefs.getString('notifications_list') ?? '[]',
  );

  existing.insert(0, AppNotification.fromRemoteMessage(message).toJson());

  final FlutterLocalNotificationsPlugin fln = FlutterLocalNotificationsPlugin();

  const androidDetails = AndroidNotificationDetails(
    'high_importance_channel',
    'High Importance Notifications',
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

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await FirebaseMessaging.instance.requestPermission();
  await setupNotificationChannel();
  await Alarm.init();



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

    // ✅ Initialize push notifications immediately (lightweight)
    PushNotificationService().initialize();

    // Handle when the app is opened from a background notification tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      logLong("Notifications", message.toString());
      final notification = AppNotification.fromRemoteMessage(message);
      logLong("Remote Message", notification.title);

      Get.find<AlertsController>().addNotification(notification);
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
      print('🔄 Starting app initialization...');
      await initializeApp();
      print('✅ App initialization complete');

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('❌ App initialization failed: $e');
      // Show error dialog or retry option
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Initialization failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleInitialMessage() async {
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();

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

      // ✅ Show splash while initializing, then navigate
      home:
          _isInitialized
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
