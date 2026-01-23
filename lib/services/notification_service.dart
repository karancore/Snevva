import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  var hasNewNotification = false.obs;

  // -------------------------------------------------
  // Initialize notifications and timezone
  // -------------------------------------------------
  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await notificationsPlugin.initialize(initSettings);

    // Initialize timezone (very important for scheduling)
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
  }

  // -------------------------------------------------
  // Instant notification (like Swiggy order update)
  // -------------------------------------------------
  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await notificationsPlugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'instant_notification_channel_id',
          'Instant Notifications',
          channelDescription: 'Instant notification channel',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@drawable/ic_stat_notification',
          styleInformation: BigTextStyleInformation(''),
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
    hasNewNotification.value = true;
  }

  // -------------------------------------------------
  // Daily reminders at 10 AM and 10 PM
  // -------------------------------------------------
  Future<void> scheduleReminder({required int id}) async {
    final now = tz.TZDateTime.now(tz.local);

    tz.TZDateTime morningTime = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      10,
      0,
    );
    tz.TZDateTime nightTime = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      22,
      0,
    );

    if (now.isAfter(morningTime)) {
      morningTime = morningTime.add(const Duration(days: 1));
    }
    if (now.isAfter(nightTime)) {
      nightTime = nightTime.add(const Duration(days: 1));
    }

    // Morning channel (used by Android system)
    const morningDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_morning_channel',
        'Daily Morning Reminder',
        channelDescription: 'Morning motivation reminders ☀️',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@drawable/ic_stat_notification',
        styleInformation: BigTextStyleInformation(''),
      ),
      iOS: DarwinNotificationDetails(),
    );

    // Night channel
    const nightDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_night_channel',
        'Daily Night Reminder',
        channelDescription: 'Night reflection reminders 🌙',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@drawable/ic_stat_notification',
        styleInformation: BigTextStyleInformation(''),
      ),
      iOS: DarwinNotificationDetails(),
    );

    // ✅ Morning notification text
    await notificationsPlugin.zonedSchedule(
      id,
      'Wakey-wakey! ☀️',
      "If today is even half as amazing as you are, it's going to be a good one. 🌻",
      morningTime,
      morningDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    hasNewNotification.value = true;

    // ✅ Night notification text
    await notificationsPlugin.zonedSchedule(
      id + 1,
      'Good night! 🌙',
      'Before you close your eyes, remember you did great today! ✨',
      nightTime,
      nightDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    hasNewNotification.value = true;

    print('Morning scheduled: $morningTime');
    print('Night scheduled: $nightTime');
  }

  // -------------------------------------------------
  // OTP Notification (Instant) — shows OTP in notification bar
  // -------------------------------------------------
  Future<void> showOtpNotification(String otp) async {
    await notificationsPlugin.show(
      999, // Unique ID for OTP notifications
      'Your OTP Code',
      'OTP: $otp', // Content shown in notification
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'otp_notification_channel',
          'OTP Notifications',
          channelDescription: 'Used for showing OTP verification codes',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@drawable/ic_stat_notification',
          styleInformation: BigTextStyleInformation(''),
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );

    hasNewNotification.value = true;
  }
}
