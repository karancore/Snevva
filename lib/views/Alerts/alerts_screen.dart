import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
import 'package:intl/intl.dart';
import '../../Controllers/alerts/alerts_controller.dart';
import '../../consts/images.dart';
import '../../services/notification_service.dart';
import '../../widgets/CommonWidgets/custom_appbar.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  final alertsController = Get.find<AlertsController>();

  @override
  void initState() {
    super.initState();
    // _firebaseMessaging.requestPermission();
    // FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    //   flutterLocalNotificationsPlugin.show(
    //     0,
    //     message.notification?.title,
    //     message.notification?.body,
    //     NotificationDetails(
    //       android: AndroidNotificationDetails(
    //         'high_importance_channel',
    //         'High Importance Notifications',
    //         importance: Importance.max,
    //         priority: Priority.high,
    //       ),
    //     ),
    //   );
    // });
    //
    // FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    //   print('Message clicked! ${message.messageId}');
    // });
    // // Use the existing instance instead of creating new one
    // notif = Get.find<NotificationService>();
    WidgetsBinding.instance.addPostFrameCallback((_){
      alertsController.hitAlertsNotifications();
    });
  }



  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    // ✅ Listens to the app's current theme command
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBodyBehindAppBar: true,

      appBar: CustomAppBar(
        appbarText: 'Alerts',
        showCloseButton: false,
        showDrawerIcon: false,
      ),

      body: SafeArea(
        child: Obx(() {
          final list = Get.find<AlertsController>().notifications;

          return (list.isEmpty)
              ? _noNotificationsWidget(isDarkMode)
              : ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final n = list[i];
                  return ListTile(
                    title: Text(n.title),
                    subtitle: Text(n.body),
                    trailing: Text(DateFormat('hh:mm a').format(n.timestamp)),
                  );
                },
              );
        }),
      ),
    );
  }

  Widget _noNotificationsWidget(bool isDarkMode) {
    return Center(
      child: Column(
        // mainAxisAlignment: MainAxisAlignment.center,
        // crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(noNotif, width: 180, height: 180),
          const SizedBox(height: 24),

          Text(
            'No alerts',
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
    );
  }
}
