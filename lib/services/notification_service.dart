import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzd;
import 'package:timezone/timezone.dart' as tz;

import '../consts/consts.dart';
import 'reminder/device_timezone_service.dart';

const int NOTIFICATION_ID = 999;
const int WAKE_NOTIFICATION_ID = 998;

class NotificationService {
  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  var hasNewNotification = true.obs;

  late tz.Location _location;

  // -------------------------------------------------
  // Normalize timezone (VERY IMPORTANT)
  // -------------------------------------------------
  String _normalizeTimeZone(String tzName) {
    if (tzName == "IST") return "Asia/Kolkata";
    return tzName;
  }

  // -------------------------------------------------
  // Initialize notifications + timezone
  // -------------------------------------------------
  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await notificationsPlugin.initialize(initSettings);

    // 🔥 Initialize timezone DB
    tzd.initializeTimeZones();

    final tzIdRaw = await DeviceTimezoneService.instance.getTimeZoneId();

    final tzId = _normalizeTimeZone(tzIdRaw);

    try {
      _location = tz.getLocation(tzId);
      tz.setLocalLocation(_location);
      debugPrint("🌍 Timezone set: ${_location.name}");
    } catch (e) {
      debugPrint("❌ Invalid timezone: $tzId → fallback Asia/Kolkata");

      _location = tz.getLocation("Asia/Kolkata");
      tz.setLocalLocation(_location);
    }

    debugPrint("⏰ Current time: ${tz.TZDateTime.now(_location)}");
  }

  // -------------------------------------------------
  // Common time generator (FIXED)
  // -------------------------------------------------
  tz.TZDateTime nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(_location);

    var scheduledDate = tz.TZDateTime(
      _location,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  // -------------------------------------------------
  // Instant notification
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
  // Schedule alert (FIXED)
  // -------------------------------------------------
  Future<void> scheduleAlertNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    final scheduledDate = nextInstanceOfTime(hour, minute);

    await notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'alerts_channel',
          'Alerts',
          channelDescription: 'Scheduled alerts',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@drawable/ic_stat_notification',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    debugPrint("✅ Scheduled -> $title at $scheduledDate");
  }

  // -------------------------------------------------
  // Daily Reminder (FIXED)
  // -------------------------------------------------
  Future<void> scheduleReminder({required int id}) async {
    final now = tz.TZDateTime.now(_location);

    var morningTime = tz.TZDateTime(
      _location,
      now.year,
      now.month,
      now.day,
      10,
      0,
    );

    var nightTime = tz.TZDateTime(
      _location,
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

    const morningDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_morning_channel',
        'Morning Reminder',
        channelDescription: 'Morning reminders',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@drawable/ic_stat_notification',
      ),
      iOS: DarwinNotificationDetails(),
    );

    const nightDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_night_channel',
        'Night Reminder',
        channelDescription: 'Night reminders',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@drawable/ic_stat_notification',
      ),
      iOS: DarwinNotificationDetails(),
    );

    await notificationsPlugin.zonedSchedule(
      id,
      'Wakey-wakey ☀️',
      'Have a great day!',
      morningTime,
      morningDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    await notificationsPlugin.zonedSchedule(
      id + 1,
      'Good night 🌙',
      'You did great today!',
      nightTime,
      nightDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    debugPrint("🌅 Morning: $morningTime");
    debugPrint("🌙 Night: $nightTime");
  }
}