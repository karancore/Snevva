import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:snevva/main.dart';
import 'package:timezone/data/latest.dart' as tzd;
import 'package:timezone/timezone.dart' as tz;

import '../Controllers/SleepScreen/sleep_controller.dart';
import '../consts/consts.dart';

const int NOTIFICATION_ID = 999;
const int WAKE_NOTIFICATION_ID = 998;


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

    await notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: onNotificationAction, // foreground
      onDidReceiveBackgroundNotificationResponse: notificationBackgroundHandler, // killed
    );

    // Initialize timezone (very important for scheduling)
    tzd.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
  }

  static void onNotificationAction(NotificationResponse response) async {
    if (response.actionId == 'STOP_ALARM') {
      // 1. Stop UI-based alarm sound/logic
      if (Get.isRegistered<SleepController>()) {
        Get.find<SleepController>().stopMonitoring();
      }

      // 2. Cancel the specific notification
      final fln = FlutterLocalNotificationsPlugin();
      await fln.cancel(response.id ?? WAKE_NOTIFICATION_ID);
    }
  }


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

  tz.TZDateTime nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);

    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // 🔑 If time already passed today → schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
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
      NOTIFICATION_ID, // Unique ID for OTP notifications
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

  // Future<void> scheduleWakeNotification(DateTime wakeDateTime) async {
  //   await notificationsPlugin.zonedSchedule(
  //     999, // fixed ID for wake alarm
  //     'Wake Time',
  //     'Stopping sleep monitoring',
  //     tz.TZDateTime.from(wakeDateTime, tz.local),
  //     const NotificationDetails(
  //       android: AndroidNotificationDetails(
  //         'wake_channel',
  //         'Wake Alarm',
  //         importance: Importance.max,
  //         priority: Priority.high,
  //       ),
  //     ),
  //     androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
  //     matchDateTimeComponents: DateTimeComponents.time,
  //   );
  // }

  // Future<void> showWakeNotification() async {
  //   await notificationsPlugin.show(
  //     WAKE_NOTIFICATION_ID,
  //     'Wake Up',
  //     'Tap STOP to turn off alarm',
  //     NotificationDetails(
  //       android: AndroidNotificationDetails(
  //         'alarm_channel',
  //         'Alarm',
  //         importance: Importance.max,
  //         priority: Priority.high,
  //         fullScreenIntent: true,
  //         actions: [
  //           AndroidNotificationAction(
  //             'STOP_ALARM',
  //             'Stop Alarm',
  //             cancelNotification: true,
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }
  Future<void> scheduleWakeNotification({required DateTime dateTime}) async {
    final scheduledDate =
    nextInstanceOfTime(dateTime.hour, dateTime.minute);

    await notificationsPlugin.zonedSchedule(
      WAKE_NOTIFICATION_ID,
      'Wake Time',
      'Wake up! Time to start your day.',
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'STOP_ALARM',
          'Wake Alarm',
          subText: 'Click on STOP to turn off alarm',
          channelDescription: 'Wake-up alerts',
          playSound: true,
          sound: RawResourceAndroidNotificationSound('alarm'),
          audioAttributesUsage: AudioAttributesUsage.alarm,
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true,

          autoCancel: false,
          actions: const [
            AndroidNotificationAction(
              'STOP_ALARM',
              'Stop',
              cancelNotification: true,

            ),
          ],
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }


  Future<void> cancelWakeNotification() async {
    await notificationsPlugin.cancel(WAKE_NOTIFICATION_ID); // Changed from 999 to 998
  }
}
