import 'package:alarm/alarm.dart';
import 'package:alarm/model/alarm_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ReminderNotificationsScreen extends StatefulWidget {
  AlarmSettings alarmSettings;
  ReminderNotificationsScreen({super.key, required this.alarmSettings});

  @override
  State<ReminderNotificationsScreen> createState() =>
      _ReminderNotificationsScreenState();
}

class _ReminderNotificationsScreenState
    extends State<ReminderNotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(widget.alarmSettings.notificationSettings.title),
          Text(widget.alarmSettings.notificationSettings.body),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {
                  //skip alarm for next time
                  final now = DateTime.now();
                  Alarm.set(
                    alarmSettings: widget.alarmSettings.copyWith(
                      dateTime: DateTime(
                        now.year,
                        now.month,
                        now.day,
                        now.hour,
                        now.minute,
                      ).add(const Duration(minutes: 1)),
                    ),
                  ).then((_) => Navigator.pop(context));
                },
                child: const Text("Snooze"),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  //stop alarm
                  Alarm.stop(
                    widget.alarmSettings.id,
                  ).then((_) => Navigator.pop(context));
                },
                child: const Text("Stop"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
