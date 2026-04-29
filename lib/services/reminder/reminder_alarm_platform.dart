import 'package:alarm/alarm.dart';
import 'package:flutter/foundation.dart';

bool get usesNativeReminderScheduling =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

Future<bool> scheduleReminderAlarm(AlarmSettings settings) async {
  if (usesNativeReminderScheduling) {
    debugPrint(
      '[ReminderAlarmPlatform] Android native scheduler active; '
      'skipping Alarm.set for id=${settings.id}',
    );
    return true;
  }
  return Alarm.set(alarmSettings: settings);
}

Future<void> clearLegacyFlutterReminderAlarms() async {
  if (!usesNativeReminderScheduling) return;
  try {
    await Alarm.stopAll();
    debugPrint(
      '[ReminderAlarmPlatform] Cleared legacy flutter_alarm reminders on Android startup',
    );
  } catch (e) {
    debugPrint(
      '[ReminderAlarmPlatform] Failed to clear legacy flutter_alarm reminders: $e',
    );
  }
}
