import 'package:alarm/alarm.dart';
import 'package:snevva/Widgets/home_wrapper.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/initial_bindings.dart';
import 'package:snevva/services/app_initializer.dart';
import 'package:snevva/utils/theme.dart';
import 'package:snevva/views/SignUp/sign_in_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
