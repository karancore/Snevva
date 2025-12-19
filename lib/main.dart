import 'dart:isolate';
import 'package:alarm/alarm.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:snevva/Widgets/home_wrapper.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/initial_bindings.dart';
import 'package:snevva/services/app_initializer.dart';
import 'package:snevva/utils/theme.dart';
import 'package:snevva/views/SignUp/sign_in_screen.dart';

void main() async {
  FlutterForegroundTask.initCommunicationPort();
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'sleep_channel',
      channelName: 'Sleep Tracking',
      channelDescription: 'Tracks sleep based on screen on/off',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
      onlyAlertOnce: true,
    ),

    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(30000), // 30 sec
      autoRunOnBoot: true,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
    iosNotificationOptions: IOSNotificationOptions(showNotification: true),
  );
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

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
  ReceivePort? _receivePort;

  @override
  void initState() {
    super.initState();
    _initForegroundListener();
  }

  void _initForegroundListener() async {
    if (_receivePort != null) {
      return;
    }

    try {
      _receivePort = await FlutterForegroundTask.receivePort;

      _receivePort?.listen((data) {
        // Handle sleep/wake globally
      });
    } catch (e) {
      // Stream already listened to, ignore
      print("⚠️ Foreground listener already initialized: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      // initialBinding: InitialBindings(),
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
