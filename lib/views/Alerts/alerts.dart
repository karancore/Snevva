import 'package:flutter/material.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/Widgets/Drawer/drawer_menu_wigdet.dart';
import 'package:snevva/consts/consts.dart';

import '../../services/notification_service.dart';

class Alerts extends StatefulWidget {
  const Alerts({super.key});

  @override
  State<Alerts> createState() => _AlertsState();
}

class _AlertsState extends State<Alerts> with SingleTickerProviderStateMixin {
  late final NotificationService notif;

  @override
  void initState() {
    super.initState();
    // Use the existing instance instead of creating new one
    notif = Get.find<NotificationService>();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final heightDevice = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: CustomAppBar(
        appbarText: 'Alerts',
        showCloseButton: false,
        showDrawerIcon: false,
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            // mainAxisAlignment: MainAxisAlignment.center,
            // crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(noNotif, width: 180, height: 180),
              const SizedBox(height: 24),

              // 🔕 Title
              Text(
                'No notification',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),

              const SizedBox(height: 8),

              // 📝 Subtitle (placeholder text)
              // ElevatedButton(
              //   onPressed: () {
              //     notif.showInstantNotification(id: 0, title: 'Instant Notif', body: 'body');
              //   },
              //   child: const Text("Click Me"),
              // )
            ],
          ),
        ),
      ),
    );
  }
}
