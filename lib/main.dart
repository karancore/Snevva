import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:snevva/Widgets/home_wrapper.dart';
import 'package:snevva/services/app_initializer.dart';
import 'package:snevva/utils/theme.dart';
import 'package:snevva/views/Sign%20Up/sign_in_screen.dart';

import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Alarm.init();
  final isRemembered = await initializeApp();
  runApp(MyApp(isRemembered: isRemembered));
}
class MyApp extends StatelessWidget {
  final bool isRemembered;
  const MyApp({super.key, required this.isRemembered});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          Get.back();
        }
      },
      child: GetMaterialApp(
        debugShowCheckedModeBanner: false,
        title: "Snevva",
        theme: SnevvaTheme.lightTheme,
        darkTheme: SnevvaTheme.darkTheme,
        themeMode: ThemeMode.system,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: isRemembered ? HomeWrapper() : HomeWrapper(),
      ),
    );
  }
}
