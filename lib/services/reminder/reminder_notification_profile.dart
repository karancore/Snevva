import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String reminderCriticalChannelId = 'reminder_critical_channel_v1';
const String reminderCriticalChannelName = 'Critical Reminders';
const String reminderCriticalChannelDescription =
    'Urgent reminder alerts for medicine, water, meals, and events.';
const String reminderAlarmPluginChannelId = 'alarm_plugin_channel';

const String _fullScreenPromptKey =
    'reminder_full_screen_permission_requested_v1';
const String _notificationPolicyPromptKey =
    'reminder_notification_policy_requested_v1';
const Color _reminderLedColor = Color(0xFFFF6B35);

Future<void> ensureReminderNotificationPluginInitialized(
  FlutterLocalNotificationsPlugin plugin,
) async {
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings();
  const initSettings = InitializationSettings(
    android: androidInit,
    iOS: iosInit,
  );

  await plugin.initialize(initSettings);
}

AndroidNotificationChannel buildCriticalReminderChannel({
  required bool bypassDnd,
}) {
  return AndroidNotificationChannel(
    reminderCriticalChannelId,
    reminderCriticalChannelName,
    description: reminderCriticalChannelDescription,
    importance: Importance.max,
    bypassDnd: bypassDnd,
    playSound: true,
    enableVibration: true,
    enableLights: true,
    ledColor: _reminderLedColor,
    audioAttributesUsage: AudioAttributesUsage.alarm,
  );
}

Future<void> ensureCriticalReminderChannel(
  FlutterLocalNotificationsPlugin plugin, {
  bool requestPermissions = true,
}) async {
  await ensureReminderNotificationPluginInitialized(plugin);

  final androidPlugin = plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  if (androidPlugin == null) return;

  await androidPlugin.requestNotificationsPermission();

  final bypassDnd = await _ensureNotificationPolicyAccess(
    androidPlugin,
    requestPermissions: requestPermissions,
  );

  if (requestPermissions) {
    await _requestFullScreenPermissionIfNeeded(androidPlugin);
  }

  try {
    await androidPlugin.deleteNotificationChannel(reminderCriticalChannelId);
  } catch (_) {}

  await androidPlugin.createNotificationChannel(
    buildCriticalReminderChannel(bypassDnd: bypassDnd),
  );
}

Future<bool> _ensureNotificationPolicyAccess(
  AndroidFlutterLocalNotificationsPlugin androidPlugin, {
  required bool requestPermissions,
}) async {
  final hasAccess = await androidPlugin.hasNotificationPolicyAccess() ?? false;
  if (hasAccess || !requestPermissions) {
    return hasAccess;
  }

  final prefs = await SharedPreferences.getInstance();
  final alreadyPrompted =
      prefs.getBool(_notificationPolicyPromptKey) ?? false;

  if (!alreadyPrompted) {
    await prefs.setBool(_notificationPolicyPromptKey, true);
    await androidPlugin.requestNotificationPolicyAccess();
  }

  return await androidPlugin.hasNotificationPolicyAccess() ?? false;
}

Future<void> _requestFullScreenPermissionIfNeeded(
  AndroidFlutterLocalNotificationsPlugin androidPlugin,
) async {
  final prefs = await SharedPreferences.getInstance();
  final alreadyPrompted = prefs.getBool(_fullScreenPromptKey) ?? false;
  if (alreadyPrompted) return;

  await prefs.setBool(_fullScreenPromptKey, true);
  await androidPlugin.requestFullScreenIntentPermission();
}

NotificationDetails buildCriticalReminderNotificationDetails({
  required String body,
  String icon = '@drawable/ic_stat_notification',
}) {
  return NotificationDetails(
    android: AndroidNotificationDetails(
      reminderCriticalChannelId,
      reminderCriticalChannelName,
      channelDescription: reminderCriticalChannelDescription,
      icon: icon,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: _reminderLedColor,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: false,
      silent: false,
      channelBypassDnd: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      styleInformation: BigTextStyleInformation(body),
      channelAction: AndroidNotificationChannelAction.update,
    ),
    iOS: const DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentList: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    ),
  );
}

AlarmSettings buildCriticalReminderAlarmSettings({
  required int id,
  required DateTime dateTime,
  required String assetAudioPath,
  required VolumeSettings volumeSettings,
  required String notificationTitle,
  required String notificationBody,
  String? payload,
  String stopButton = 'Stop',
  String? icon = 'alarm',
  Color? iconColor,
  bool loopAudio = true,
  bool vibrate = true,
  bool androidFullScreenIntent = true,
  bool allowAlarmOverlap = true,
  bool warningNotificationOnKill = true,
  bool androidStopAlarmOnTermination = false,
}) {
  return AlarmSettings(
    id: id,
    dateTime: dateTime,
    assetAudioPath: assetAudioPath,
    volumeSettings: volumeSettings,
    notificationSettings: NotificationSettings(
      title: notificationTitle,
      body: notificationBody,
      stopButton: stopButton,
      icon: icon,
      iconColor: iconColor,
    ),
    loopAudio: loopAudio,
    vibrate: vibrate,
    warningNotificationOnKill: warningNotificationOnKill,
    androidFullScreenIntent: androidFullScreenIntent,
    allowAlarmOverlap: allowAlarmOverlap,
    androidStopAlarmOnTermination: androidStopAlarmOnTermination,
    payload: payload,
  );
}
