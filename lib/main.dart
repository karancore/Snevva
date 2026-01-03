import 'package:alarm/alarm.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:snevva/Widgets/home_wrapper.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/initial_bindings.dart';
import 'package:snevva/services/app_initializer.dart';
import 'package:snevva/services/notification_channel.dart';
import 'package:snevva/utils/theme.dart';
import 'package:snevva/views/SignUp/sign_in_screen.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await FirebaseMessaging.instance.requestPermission();
  await setupNotificationChannel();
  await Alarm.init();
  final isRemembered = await initializeApp();

  runApp(MyApp(isRemembered: isRemembered));
}

class MyApp extends StatefulWidget {
  final bool isRemembered;

  const MyApp({super.key, required this.isRemembered});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    PushNotificationService().initialize();

    // Handle when the app is opened from a background notification tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print(
        'App opened from background via notification: ${message.messageId}',
      );
      // Navigate based on message data...
    });

    // Handle when the app is opened from a terminated state
    _handleInitialMessage();
  }

  Future<void> _handleInitialMessage() async {
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      print(
        'App opened from terminated state via notification: ${initialMessage.messageId}',
      );
      // Navigate based on initial message data...
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

      home: widget.isRemembered ? HomeWrapper() : SignInScreen(),
    );
  }
}
