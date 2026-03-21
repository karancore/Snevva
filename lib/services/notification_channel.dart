import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'reminder/reminder_notification_profile.dart';

class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    await ensureReminderNotificationPluginInitialized(_localNotifications);
    await setupNotificationChannel(localNotifications: _localNotifications);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });
  }

  void _showLocalNotification(RemoteMessage message) {
    final isReminder = _isReminderMessage(message);
    final notificationDetails =
        isReminder
            ? buildCriticalReminderNotificationDetails(
              body: message.notification?.body ?? message.data['body'] ?? '',
            )
            : const NotificationDetails(
              android: AndroidNotificationDetails(
                'high_importance_channel',
                'High Importance Notifications',
                importance: Importance.max,
                priority: Priority.high,
              ),
            );

    _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      message.notification?.title ?? message.data['title'],
      message.notification?.body ?? message.data['body'],
      notificationDetails,
    );
  }

  Future<String?> getDeviceToken() async {
    return await _fcm.getToken();
  }

  bool _isReminderMessage(RemoteMessage message) {
    final values = <String>[
      message.data['type']?.toString() ?? '',
      message.data['category']?.toString() ?? '',
      message.data['notificationType']?.toString() ?? '',
      message.data['screen']?.toString() ?? '',
    ].map((value) => value.toLowerCase());

    return values.any(
      (value) =>
          value == 'reminder' ||
          value == 'medicine' ||
          value == 'water' ||
          value == 'meal' ||
          value == 'event',
    );
  }
}

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  description: 'Used for important notifications',
  importance: Importance.max,
);

Future<void> setupNotificationChannel({
  FlutterLocalNotificationsPlugin? localNotifications,
  bool requestReminderOverrides = true,
}) async {
  final fln = localNotifications ?? FlutterLocalNotificationsPlugin();

  await ensureReminderNotificationPluginInitialized(fln);

  final androidPlugin = fln
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  await androidPlugin?.createNotificationChannel(channel);
  await ensureCriticalReminderChannel(
    fln,
    requestPermissions: requestReminderOverrides,
  );
}
