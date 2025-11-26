import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:alarm/alarm.dart';
import 'package:alarm/model/alarm_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:snevva/Controllers/Reminder/reminder_controller.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/Widgets/Drawer/drawer_menu_wigdet.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/views/Reminder/reminder_notifications_screen.dart';
import '../../Widgets/CommonWidgets/custom_outlined_button.dart';

class AddReminder extends StatefulWidget {
  final Map<String, dynamic>?
  reminder; // We make it nullable in case we're adding a new reminder

  const AddReminder({super.key, this.reminder});

  @override
  State<AddReminder> createState() => _AddReminderState();
}

class _AddReminderState extends State<AddReminder> {
  late List<AlarmSettings> alarms;

  static StreamSubscription<AlarmSettings>? subscription;
  List<String> medicineNames = []; // List to hold multiple medicine names
  List<String> remindTimes = []; // List to hold multiple reminder times
  String selectedCategory = 'Medicine';
  final TextEditingController medicineController = TextEditingController();
  final TextEditingController titleController = TextEditingController();
  final TextEditingController timeController = TextEditingController(
    text: '09:30 AM',
  );
  final TextEditingController everyHourController = TextEditingController();
  final TextEditingController timesPerDayController = TextEditingController();
  bool enableNotifications = false;
  bool soundVibrationToggle = true;
  final TextEditingController notesController = TextEditingController();
  final controller = Get.put(ReminderController());
  TimeOfDay? pickedTime = TimeOfDay(hour: 0, minute: 0);

  DateTime? startDate;
  DateTime? endDate;
  int waterReminderOption = 1;
  int savedInterval = 0;
  int savedTimes = 0;

  List<Map<String, AlarmSettings>> medicineList = [];
  List<Map<String, AlarmSettings>> eventList = [];
  List<Map<String, AlarmSettings>> mealsList = [];

  List<String> categories = ['Medicine', 'Water', 'Meal', 'Event'];

  int _alarmIdCounter = 0;

  int generateAlarmId() {
    return _alarmIdCounter++;
  }

  bool listenerAttached = false;
  double itemHeight = 56; // typical ListTile height
  double maxHeight = 150;
  late double listHeight;

  @override
  void initState() {
    super.initState();

    // Initialize today's date for Water and Meal categories
    startDate = DateTime.now();

    // Check if we are editing an existing reminder
    if (widget.reminder != null) {
      final reminder = widget.reminder!;

      titleController.text = reminder['Title'] ?? '';
      notesController.text = reminder['Description'] ?? '';
      selectedCategory = reminder['Category'] ?? 'Medicine';

      if (selectedCategory == 'Medicine') {
        medicineNames = List<String>.from(reminder['MedicineName'] ?? []);
      }
      remindTimes = List<String>.from(reminder['RemindTime'] ?? []);
      if (reminder['StartDay'] != null &&
          reminder['StartMonth'] != null &&
          reminder['StartYear'] != null) {
        startDate = DateTime(
          reminder['StartYear'],
          reminder['StartMonth'],
          reminder['StartDay'],
        );
      }
      everyHourController.text =
          reminder['RemindFrequencyHour']?.toString() ?? '';
      timesPerDayController.text =
          reminder['RemindFrequencyCount']?.toString() ?? '';
      enableNotifications = reminder['EnablePushNotification'] ?? false;
    }
    checkAndroidNotificationPermission();
    //schedule alarm permission
    checkAndroidScheduleExactAlarmPermission();
    loadAlarms();
    initAlarmListener();
    listHeight = (medicineList.length * itemHeight).clamp(0, maxHeight);
    //subscription ??= Alarm.ringStream.stream.listen(navigateToRingScreen);
  }

  @override
  void dispose() {
    subscription?.cancel();
    medicineController.dispose();
    titleController.dispose();
    timeController.dispose();
    everyHourController.dispose();
    timesPerDayController.dispose();
    notesController.dispose();
    super.dispose();
  }

  void initAlarmListener() {
    if (listenerAttached) return;
    listenerAttached = true;

    subscription ??= Alarm.ringStream.stream.listen((
      AlarmSettings alarmSettings,
    ) async {
      print("🔔 ALARM RANG → ID: ${alarmSettings.id}");

      // Reschedule FIRST (so it doesn't get lost)
      await Alarm.stop(alarmSettings.id);

      if (savedInterval > 0) {
        print("🔄 Rescheduling water alarm (every $savedInterval hours)");
        await scheduleAlarmEveryXHours(savedInterval);
      } else if (savedTimes > 0) {
        // ✅ FIX: Calculate precise duration
        int totalMinutes = (24 * 60) ~/ savedTimes;
        int hours = totalMinutes ~/ 60;
        int minutes = totalMinutes % 60;

        print(
          "🔄 Rescheduling water alarm ($savedTimes times/day = ${hours}h ${minutes}m)",
        );

        final nextTime = DateTime.now().add(
          Duration(hours: hours, minutes: minutes),
        );

        final newAlarm = AlarmSettings(
          id: _alarmId(),
          dateTime: nextTime,
          assetAudioPath: alarmSound,
          loopAudio: true,
          vibrate: soundVibrationToggle,
          warningNotificationOnKill: Platform.isAndroid,
          androidFullScreenIntent: true,
          volumeSettings: VolumeSettings.fade(
            volume: 0.8,
            fadeDuration: Duration(seconds: 5),
            volumeEnforced: true,
          ),
          notificationSettings: NotificationSettings(
            title:
                titleController.text.isNotEmpty
                    ? titleController.text
                    : 'Water Reminder',
            body:
                notesController.text.isNotEmpty
                    ? notesController.text
                    : 'Time to drink water!',
            stopButton: 'Stop',
            icon: 'alarm',
            iconColor: AppColors.primaryColor,
          ),
        );

        await Alarm.set(alarmSettings: newAlarm);
      }

      // Then navigate (won't block rescheduling)
      await navigateToRingScreen(alarmSettings);
    });
  }

  //TESTING
  // void initAlarmListener() {
  //   if (listenerAttached) return;
  //   listenerAttached = true;
  //
  //   subscription ??= Alarm.ringStream.stream.listen((
  //       AlarmSettings alarmSettings,
  //       ) async {
  //     print("🔔🔔🔔 WATER ALARM RANG! 🔔🔔🔔");
  //     print("   ID: ${alarmSettings.id}");
  //     print("   Time: ${DateTime.now()}");
  //
  //     // Stop the current alarm
  //     await Alarm.stop(alarmSettings.id);
  //
  //     // ✅ TEST MODE: Reschedule in seconds
  //     if (savedInterval > 0) {
  //       print("🔄 Rescheduling test alarm in ${savedInterval * 10} seconds");
  //
  //       final nextTime = DateTime.now().add(Duration(seconds: savedInterval * 10));
  //
  //       final newAlarm = AlarmSettings(
  //         id: _alarmId(),
  //         dateTime: nextTime,
  //         assetAudioPath: alarmSound,
  //         loopAudio: true,
  //         vibrate: soundVibrationToggle,
  //         warningNotificationOnKill: Platform.isAndroid,
  //         androidFullScreenIntent: true,
  //         volumeSettings: VolumeSettings.fade(
  //           volume: 0.8,
  //           fadeDuration: Duration(seconds: 5),
  //           volumeEnforced: true,
  //         ),
  //         notificationSettings: NotificationSettings(
  //           title: 'Water Reminder (Rescheduled)',
  //           body: 'Time to drink water again!',
  //           stopButton: 'Stop',
  //           icon: 'alarm',
  //           iconColor: AppColors.primaryColor,
  //         ),
  //       );
  //
  //       await Alarm.set(alarmSettings: newAlarm);
  //       print("✅ Next test alarm set for: $nextTime");
  //     } else if (savedTimes > 0) {
  //       int totalSeconds = (60) ~/ savedTimes;
  //       print("🔄 Rescheduling test alarm in $totalSeconds seconds");
  //
  //       final nextTime = DateTime.now().add(Duration(seconds: totalSeconds));
  //
  //       final newAlarm = AlarmSettings(
  //         id: _alarmId(),
  //         dateTime: nextTime,
  //         assetAudioPath: alarmSound,
  //         loopAudio: true,
  //         vibrate: soundVibrationToggle,
  //         warningNotificationOnKill: Platform.isAndroid,
  //         androidFullScreenIntent: true,
  //         volumeSettings: VolumeSettings.fade(
  //           volume: 0.8,
  //           fadeDuration: Duration(seconds: 5),
  //           volumeEnforced: true,
  //         ),
  //         notificationSettings: NotificationSettings(
  //           title: 'Water Reminder (Rescheduled)',
  //           body: 'Time to drink water again!',
  //           stopButton: 'Stop',
  //           icon: 'alarm',
  //           iconColor: AppColors.primaryColor,
  //         ),
  //       );
  //
  //       await Alarm.set(alarmSettings: newAlarm);
  //       print("✅ Next test alarm set for: $nextTime");
  //     }
  //
  //     // Navigate to ring screen
  //     await navigateToRingScreen(alarmSettings);
  //   });
  // }

  // void initAlarmRepeatingListener() {
  //   if (listenerAttached) return;
  //   listenerAttached = true;
  //
  //   Alarm.ringStream.stream.listen((AlarmSettings alarmSettings) async {
  //     print("WATER ALARM RANG → Rescheduling...");
  //
  //     await Alarm.stop(alarmSettings.id);
  //
  //     if (savedInterval > 0) {
  //       await scheduleAlarmEveryXHours(savedInterval);
  //     }
  //
  //     if (savedTimes > 0) {
  //       double hours = 24 / savedTimes;
  //       await scheduleAlarmEveryXHours(hours.toInt());
  //     }
  //
  //   });
  // }

  Future<List<AlarmSettings>> loadAlarms() async {
    final loadedAlarms = await Alarm.getAlarms();

    loadedAlarms.sort((a, b) => a.dateTime.compareTo(b.dateTime));

    setState(() {
      alarms = loadedAlarms;
    });
    return alarms;
  }

  Future<void> checkAndroidNotificationPermission() async {
    final status = await Permission.notification.status;
    if (status.isDenied) {
      print('Requesting notification permission...');
      final res = await Permission.notification.request();
      print('Notification permission ${res.isGranted ? '' : 'not '}granted');
    }
    if (status.isGranted) {
      setState(() {
        enableNotifications = true;
      });
    }
  }

  Future<void> navigateToRingScreen(AlarmSettings alarmSettings) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder:
            (context) =>
                ReminderNotificationsScreen(alarmSettings: alarmSettings),
      ),
    );
    loadAlarms();
  }

  Future<void> checkAndroidScheduleExactAlarmPermission() async {
    final status = await Permission.scheduleExactAlarm.status;
    if (kDebugMode) {
      print('Schedule exact alarm permission: $status.');
    }
    if (status.isDenied) {
      if (kDebugMode) {
        print('Requesting schedule exact alarm permission...');
      }
      final res = await Permission.scheduleExactAlarm.request();
      if (kDebugMode) {
        print(
          'Schedule exact alarm permission ${res.isGranted ? '' : 'not'} granted.',
        );
      }
    }
  }

  IconData getCategoryIcon(String category) {
    switch (category) {
      case 'Medicine':
        return Icons.medical_services;
      case 'Water':
        return Icons.local_drink;
      case 'Meal':
        return Icons.restaurant;
      case 'Event':
        return Icons.event;
      default:
        return Icons.help_outline;
    }
  }

  void addReminderTime() {
    setState(() {
      if (timeController.text.isNotEmpty) {
        remindTimes.add(timeController.text);
        timeController.clear();
      }
    });
  }

  void removeReminderTime(int index) {
    setState(() {
      remindTimes.removeAt(index);
    });
  }

  void addMedicine() {
    setState(() {
      if (medicineController.text.isNotEmpty) {
        setState(() {
          medicineNames.add(medicineController.text);
          medicineController.clear();
        });
      }
    });
  }

  void removeMedicine(int index) {
    setState(() {
      medicineNames.removeAt(index);
    });
  }

  int _alarmId() {
    return DateTime.now().millisecondsSinceEpoch % 2147483647; // Max int32
  }

  void _saveReminder() async {
    String title = titleController.text;
    String description = notesController.text;
    String category = selectedCategory;

    // Handle special case: add single time for Meal or Event
    if ((category == 'Meal' || category == 'Event') &&
        timeController.text.isNotEmpty) {
      remindTimes = [timeController.text]; // 👈 Add to remindTimes
    }

    List<String> medicines = medicineNames;
    List<String> reminderTimes = remindTimes;

    DateTime? start = startDate;

    // Get current device time (for Water reminder)
    String currentTime = DateFormat('hh:mm a').format(DateTime.now());

    // Default values if not water (or make conditional if needed)
    int remindFrequencyHour = int.tryParse(everyHourController.text) ?? 0;
    int remindFrequencyCount = int.tryParse(timesPerDayController.text) ?? 0;

    // Build map according to backend keys (case-sensitive!)
    Map<String, dynamic> reminderData = {
      'Title': title,
      'Description': description,
      'Category': category,
      'MedicineName': medicines,
      'StartDay': start?.day ?? 0,
      'StartMonth': start?.month ?? 0,
      'StartYear': start?.year ?? 0,
      'RemindTime': reminderTimes,
      'RemindFrequencyHour': remindFrequencyHour,
      'RemindFrequencyCount': remindFrequencyCount,
      'EnablePushNotification': enableNotifications,
      'IsActive': true, // Defaulting to true
    };

    // Only add this if it's a "Water" reminder
    if (selectedCategory == 'Water' || selectedCategory == 'Meal') {
      reminderData['RemindTime'].add(
        currentTime,
      ); // Add the current time to the reminder
    }

    if (widget.reminder == null) {
      // Adding new reminder
      controller.addReminder(reminderData);
    } else {
      // Editing existing reminder
      reminderData['Id'] = widget.reminder!['Id'];
      controller.updateReminder(
        reminderData,
      ); // Assuming a function `updateReminder` in controller.
    }

    // Navigator.pop(context)
    Get.back(result: true); // Return true to indicate success
  }

  Future<void> addAlarm({
    required TimeOfDay timeOfDay,
    required String category,
  }) async {
    final now = DateTime.now(); // ✅ Always use current time, not startDate

    // Correct time calculation
    var scheduledTime = DateTime(
      startDate?.year ?? now.year,
      startDate?.month ?? now.month,
      startDate?.day ?? now.day,
      timeOfDay.hour,
      timeOfDay.minute,
    );

    // If time already passed today → schedule for tomorrow
    if (scheduledTime.isBefore(now) || scheduledTime.isAtSameMomentAs(now)) {
      scheduledTime = scheduledTime.add(Duration(days: 1));
      print('⚠️ Time was in past/now, moved to tomorrow: $scheduledTime');
    }

    if (category == "Medicine") {
      final alarmSettings = AlarmSettings(
        id: _alarmId(),
        dateTime: scheduledTime,
        assetAudioPath: alarmSound,
        loopAudio: true,
        vibrate: true,
        warningNotificationOnKill: Platform.isAndroid,
        androidFullScreenIntent: true,
        volumeSettings: VolumeSettings.fade(
          volume: 0.8,
          fadeDuration: Duration(seconds: 5),
          volumeEnforced: true,
        ),
        notificationSettings:
            enableNotifications
                ? NotificationSettings(
                  title: titleController.text,
                  body:
                      'Take ${medicineNames.isNotEmpty ? medicineNames.join(", ") : "your medicine"}. ${notesController.text}',

                  stopButton: 'Stop',
                  icon: 'alarm',
                  iconColor: AppColors.primaryColor,
                )
                : NotificationSettings(
                  title: '',
                  body: '',
                  stopButton: 'Stop',
                  icon: 'alarm',
                  iconColor: AppColors.primaryColor,
                ),
      );

      print('🔔 Setting alarm:');
      print('   ID: ${alarmSettings.id}');
      print('   Time: ${scheduledTime}');
      print('   Category: $category');
      print('   Title: ${titleController.text}');
      print('   Notifications enabled: $enableNotifications');

      final success = await Alarm.set(alarmSettings: alarmSettings);

      if (success) {
        medicineList.add({medicineController.text.trim(): alarmSettings});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Medicine reminder set successfully!',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: AppColors.primaryColor,
          ),
        );
        setState(() {
          listHeight = (medicineList.length * itemHeight).clamp(0, maxHeight);
        });
        final allAlarms = await Alarm.getAlarms();
        print('   Total alarms active: ${allAlarms.length}');
      }
    } else if (category == "Meal") {
      final now = DateTime.now();

      // Correct time calculation
      var scheduledTime = DateTime(
        now.year,
        now.month,
        now.day,
        timeOfDay.hour,
        timeOfDay.minute,
      );
      print(
        'Scheduled Time is ${scheduledTime.hour} : ${scheduledTime.minute}',
      );

      final alarmSettings = AlarmSettings(
        id: _alarmId(),
        dateTime: scheduledTime,
        assetAudioPath: alarmSound,
        loopAudio: true,
        vibrate: soundVibrationToggle,
        warningNotificationOnKill: Platform.isAndroid,
        androidFullScreenIntent: true,
        volumeSettings: VolumeSettings.fade(
          volume: 0.8,
          fadeDuration: Duration(seconds: 5),
          volumeEnforced: true,
        ),
        notificationSettings:
            enableNotifications
                ? NotificationSettings(
                  title: titleController.text,
                  body: notesController.text,
                  stopButton: 'Stop',
                  icon: 'alarm',
                  iconColor: AppColors.primaryColor,
                )
                : NotificationSettings(
                  title: 'REMINDER',
                  body: 'Take your medicine',
                  stopButton: 'Stop',
                  icon: 'alarm',
                ),
      );

      final success = await Alarm.set(alarmSettings: alarmSettings);
      if (success) {
        mealsList.add({titleController.text.trim(): alarmSettings});
        setState(() {
          listHeight = (mealsList.length * itemHeight).clamp(0, maxHeight);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Meal reminder set successfully!',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: AppColors.primaryColor,
          ),
        );
      }
    } else if (category == "Event") {
      final now = DateTime.now();

      // Correct time calculation
      var scheduledTime = DateTime(
        startDate?.year ?? now.year,
        startDate?.month ?? now.month,
        startDate?.day ?? now.day,
        timeOfDay.hour,
        timeOfDay.minute,
      );

      // If time already passed today → schedule for tomorrow
      if (scheduledTime.isBefore(now) || scheduledTime.isAtSameMomentAs(now)) {
        scheduledTime = scheduledTime.add(Duration(days: 1));
        print('⚠️ Time was in past/now, moved to tomorrow: $scheduledTime');
      }

      final alarmSettings = AlarmSettings(
        id: _alarmId(),
        dateTime: scheduledTime,
        assetAudioPath: alarmSound,
        loopAudio: true,
        vibrate: soundVibrationToggle,
        warningNotificationOnKill: Platform.isAndroid,
        androidFullScreenIntent: true,
        volumeSettings: VolumeSettings.fade(
          volume: 0.8,
          fadeDuration: Duration(seconds: 5),
          volumeEnforced: true,
        ),
        notificationSettings:
            enableNotifications
                ? NotificationSettings(
                  title: titleController.text,
                  body:
                      notesController.text.isNotEmpty
                          ? notesController.text
                          : 'Event reminder',
                  stopButton: 'Stop',
                  icon: 'alarm',
                  iconColor: AppColors.primaryColor,
                )
                : NotificationSettings(
                  title: '',
                  body: 'Event reminder',
                  stopButton: 'Stop',
                  icon: 'alarm',
                ),
      );

      print(
        'AlarmSettings variable ${alarmSettings.notificationSettings.title}',
      );

      final success = await Alarm.set(alarmSettings: alarmSettings);
      if (success) {
        eventList.add({medicineController.text.trim(): alarmSettings});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Event reminder set successfully!',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: AppColors.primaryColor,
          ),
        );
        setState(() {
          listHeight = (eventList.length * itemHeight).clamp(0, maxHeight);
        });
        final allAlarms = await Alarm.getAlarms();
        print('   Total alarms active: ${allAlarms.length}');
      }
    }
  }

  void scheduleEveryXHours(int interval) {
    var nextTime = DateTime.now().add(Duration(hours: interval));

    final newAlarm = AlarmSettings(
      id: _alarmId(),
      dateTime: nextTime,
      assetAudioPath: alarmSound,
      loopAudio: true,
      vibrate: soundVibrationToggle,
      warningNotificationOnKill: Platform.isAndroid,
      androidFullScreenIntent: true,
      volumeSettings: VolumeSettings.fade(
        volume: 0.8,
        fadeDuration: Duration(seconds: 5),
        volumeEnforced: true,
      ),
      notificationSettings:
          enableNotifications
              ? NotificationSettings(
                title: titleController.text,
                body: notesController.text,
                stopButton: 'Stop',
                icon: 'alarm',
                iconColor: AppColors.primaryColor,
              )
              : NotificationSettings(title: '', body: ''),
    );

    Alarm.set(alarmSettings: newAlarm);
  }

  Future<void> setWaterAlarm({
    required int? interval,
    required int? times,
  }) async {
    bool alarmSet = false; // Track if any alarm was set

    if (times != null && times > 0) {
      // int totalSeconds = (60) ~/ times; // 60 seconds divided by times
      // var scheduledTime = DateTime.now().add(
      //   Duration(seconds: totalSeconds),
      // );
      //
      // print('💧 TEST: Setting water alarm for $times times/minute');
      // print('   Next alarm in $totalSeconds seconds at: $scheduledTime');

      int totalMinutes = (24 * 60) ~/ times;

      int hours = totalMinutes ~/ 60;
      int minutes = totalMinutes % 60;

      var scheduledTime = DateTime.now().add(
        Duration(hours: hours, minutes: minutes),
      );


      print('💧 Setting water alarm for $times times/day');
      print('   Next alarm at: $scheduledTime');

      final alarmSettings = AlarmSettings(
        id: _alarmId(),
        dateTime: scheduledTime,
        assetAudioPath: alarmSound,
        loopAudio: true,
        vibrate: soundVibrationToggle,
        warningNotificationOnKill: Platform.isAndroid,
        androidFullScreenIntent: true,
        volumeSettings: VolumeSettings.fade(
          volume: 0.8,
          fadeDuration: Duration(seconds: 5),
          volumeEnforced: true,
        ),
        notificationSettings:
            enableNotifications
                ? NotificationSettings(
                  title: titleController.text,
                  body: notesController.text,
                  stopButton: 'Stop',
                  icon: 'alarm',
                  iconColor: AppColors.primaryColor,
                )
                : NotificationSettings(
                  title: '',
                  body: '',
                  stopButton: 'Stop',
                  icon: 'alarm',
                ),
      );

      final success = await Alarm.set(alarmSettings: alarmSettings);
      print('   Set result: ${success ? "✅" : "❌"}');
      alarmSet = success;
    }

    if (interval != null && interval > 0) {
      var scheduledTime = DateTime.now().add(Duration(hours: interval));
      //var scheduledTime = DateTime.now().add(Duration(seconds: interval * 10));

      print('💧 Setting water alarm every $interval hours');
      print('   Next alarm at: $scheduledTime');

      final alarmSettings = AlarmSettings(
        id: _alarmId(),
        dateTime: scheduledTime,
        assetAudioPath: alarmSound,
        loopAudio: true,
        vibrate: soundVibrationToggle,
        warningNotificationOnKill: Platform.isAndroid,
        androidFullScreenIntent: true,
        volumeSettings: VolumeSettings.fade(
          volume: 0.8,
          fadeDuration: Duration(seconds: 5),
          volumeEnforced: true,
        ),
        notificationSettings:
            enableNotifications
                ? NotificationSettings(
                  title: titleController.text,
                  body: notesController.text,
                  stopButton: 'Stop',
                  icon: 'alarm',
                  iconColor: AppColors.primaryColor,
                )
                : NotificationSettings(
                  title: 'REMINDER',
                  body: 'GET HYDRATED',
                  stopButton: 'Stop',
                  icon: 'alarm',
                ),
      );

      final success = await Alarm.set(alarmSettings: alarmSettings);
      print('   Set result: ${success ? "✅" : "❌"}');
      alarmSet = alarmSet || success;
    }

    if ((times == null || times <= 0) && (interval == null || interval <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid reminder interval')),
      );
      return; // Don't proceed
    }

    // ✅ Always load alarms after setting them
    await loadAlarms();

    // ✅ Verify the alarm was set
    final allAlarms = await Alarm.getAlarms();
    print('💧 Total alarms active: ${allAlarms.length}');
    for (var alarmSet in allAlarms) {
      print(
        '   - Alarm ${alarmSet.id} at ${alarmSet.dateTime} (in ${alarmSet.dateTime.difference(DateTime.now()).inSeconds}s)',
      );
    }

    if (alarmSet) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Water reminder set successfully!')),
      );
    }
  }

  Future<void> scheduleAlarmEveryXHours(int intervalHours) async {
    final nextTime = DateTime.now().add(Duration(hours: intervalHours));

    final newAlarm = AlarmSettings(
      id: _alarmId(),
      // unique id
      dateTime: nextTime,
      assetAudioPath: alarmSound,
      loopAudio: true,
      vibrate: soundVibrationToggle,
      warningNotificationOnKill: Platform.isAndroid,
      androidFullScreenIntent: true,
      volumeSettings: VolumeSettings.fade(
        volume: 0.8,
        fadeDuration: Duration(seconds: 5),
        volumeEnforced: true,
      ),
      notificationSettings:
          enableNotifications
              ? NotificationSettings(
                title: titleController.text,
                body: notesController.text,
                stopButton: 'Stop',
                icon: 'alarm',
                iconColor: AppColors.primaryColor,
              )
              : NotificationSettings(
                title: '',
                body: '',
                stopButton: 'Stop',
                icon: 'alarm',
                iconColor: AppColors.primaryColor,
              ),
    );

    await Alarm.set(alarmSettings: newAlarm);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;

    return Scaffold(
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      appBar: CustomAppBar(
        appbarText: widget.reminder == null ? "Add Reminder" : "Edit Reminder",
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Title
            Text("Title", style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                hintText: 'Enter title',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),

            // Category Selection
            Text(
              "Select category",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children:
                  categories.map((category) {
                    final isSelected = selectedCategory == category;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedCategory = category;
                        });
                      },
                      child: Card(
                        color:
                            isSelected ? AppColors.primaryColor : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        elevation: 0, // remove shadow
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                getCategoryIcon(category),
                                color: isSelected ? Colors.white : Colors.grey,
                                size: 28,
                              ),
                              SizedBox(height: 4),
                              Text(
                                category,
                                style: TextStyle(
                                  color:
                                      isSelected ? Colors.white : Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            ),
            if (selectedCategory == 'Water') ...[
              SizedBox(height: 20),
              Text(
                "Set Reminder Time",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),

              // Option 1: Every X hours
              Row(
                children: [
                  Radio(
                    value: 0,
                    groupValue: waterReminderOption,
                    onChanged: (value) {
                      setState(() => waterReminderOption = value as int);
                    },
                  ),
                  Text("Remind me every "),
                  SizedBox(
                    width: 50,
                    child: TextField(
                      controller: everyHourController,
                      keyboardType: TextInputType.number,
                      enabled: waterReminderOption == 0,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                      onChanged: (_) {
                        savedInterval =
                            int.tryParse(everyHourController.text) ?? 0;
                        setState(() {});
                      },
                    ),
                  ),
                  Text(" hours"),
                ],
              ),

              // Option 2: X times a day
              Row(
                children: [
                  Radio(
                    value: 1,
                    groupValue: waterReminderOption,
                    onChanged:
                        (value) =>
                            setState(() => waterReminderOption = value as int),
                  ),
                  Text("Remind me "),
                  SizedBox(
                    width: 50,
                    child: TextField(
                      controller: timesPerDayController,
                      keyboardType: TextInputType.number,
                      enabled: waterReminderOption == 1,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                      onChanged: (_) {
                        // ✅ FIX: Set savedTimes instead of savedInterval
                        savedTimes =
                            int.tryParse(timesPerDayController.text) ?? 0;
                        setState(() {});
                      },
                    ),
                  ),
                  Text(" times a day"),
                ],
              ),
            ],
            if (selectedCategory == 'Meal') ...[
              SizedBox(height: 20),
              Text(
                "Set Reminder Time",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: timeController,
                      readOnly: true,
                      onTap: () async {
                        TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                          initialEntryMode: TimePickerEntryMode.dialOnly,
                        );
                        if (picked != null) {
                          setState(() {
                            pickedTime = picked;
                          });
                          final hour = picked.hourOfPeriod.toString().padLeft(
                            2,
                            '0',
                          );
                          final minute = picked.minute.toString().padLeft(
                            2,
                            '0',
                          );
                          final period =
                              picked.period == DayPeriod.am ? 'AM' : 'PM';
                          setState(() {
                            timeController.text = '$hour:$minute $period';
                          });
                        }
                      },
                      decoration: InputDecoration(
                        hintText: '09:30 AM',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              // Display added reminder times
              if (mealsList.isEmpty)
                SizedBox.shrink()
              else
                SizedBox(
                  height: listHeight,
                  width: double.infinity,
                  child: ListView.builder(
                    itemCount: mealsList.length,
                    itemBuilder: (context, index) {
                      final reminderMap = mealsList[index];
                      final title = reminderMap.keys.first;

                      final alarm = reminderMap.values.first;
                      return ListTile(
                        title: Text(
                          '${alarm.dateTime.hour} : ${alarm.dateTime.minute}',
                        ),
                        subtitle: Text(title),

                        trailing: IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () {
                            setState(() {
                              mealsList.removeAt(index);
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
            ],
            if (selectedCategory == 'Medicine') ...[
              SizedBox(height: 20),
              Text("Medicine", style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: medicineController,
                      decoration: InputDecoration(
                        hintText: 'Medicine name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  IconButton(icon: Icon(Icons.add), onPressed: addMedicine),
                ],
              ),
              SizedBox(height: 10),
              // Display added medicines
              ListView.builder(
                shrinkWrap: true,
                itemCount: medicineNames.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(medicineNames[index]),
                    trailing: IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () => removeMedicine(index),
                    ),
                  );
                },
              ),
              SizedBox(height: 20),
              Text(
                "Reminder Date",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() {
                            startDate = picked; // 👈 THIS WAS MISSING
                          });
                        }
                      },
                      child: Text(
                        startDate == null
                            ? 'Start Date'
                            : startDate.toString().split(' ')[0],
                      ),
                    ),
                  ),
                ],
              ),

              // Reminder Time
              SizedBox(height: 20),
              Text(
                "Reminder Time",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: timeController,
                      readOnly: true,
                      onTap: () async {
                        TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                          initialEntryMode: TimePickerEntryMode.dialOnly,
                        );

                        if (picked != null) {
                          setState(() {
                            pickedTime = picked; // 👈 ADD THIS
                          });
                          final hour = picked.hourOfPeriod.toString().padLeft(
                            2,
                            '0',
                          );
                          final minute = picked.minute.toString().padLeft(
                            2,
                            '0',
                          );
                          pickedTime = picked;
                          setState(() {
                            pickedTime = picked;
                          });
                          final period =
                              picked.period == DayPeriod.am ? 'AM' : 'PM';
                          setState(() {
                            timeController.text = '$hour:$minute $period';
                          });
                        }
                      },
                      decoration: InputDecoration(
                        hintText: '09:30 AM',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  //SizedBox(width: 8),
                  //IconButton(icon: Icon(Icons.add), onPressed: () => addAlarm(picked!)),
                ],
              ),
              SizedBox(height: 10),
              // Display added reminder times
              if (medicineList.isEmpty)
                SizedBox.shrink()
              else
                SizedBox(
                  height: listHeight,
                  width: double.infinity,
                  child: ListView.builder(
                    itemCount: medicineList.length,
                    itemBuilder: (context, index) {
                      final reminderMap = medicineList[index];
                      final title = reminderMap.keys.first;
                      final alarm = reminderMap.values.first;
                      return ListTile(
                        title: Text(
                          '${alarm.dateTime.hour} : ${alarm.dateTime.minute}',
                        ),
                        subtitle: Text(title),

                        trailing: IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () {
                            setState(() {
                              medicineList.removeAt(index);
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
              // SizedBox(height: 8),
              // TextButton.icon(
              //   onPressed: () {
              //     // Add time logic
              //   },
              //   icon: Icon(Icons.add, color: AppColors.primaryColor),
              //   label: Text("Add", style: TextStyle(color: AppColors.primaryColor)),
              // ),
            ],
            if (selectedCategory == 'Event') ...[
              SizedBox(height: 20),
              Text(
                "Reminder Date",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setState(() => startDate = picked);
                      },
                      child: Text(
                        startDate == null
                            ? 'Start Date'
                            : startDate.toString().split(' ')[0],
                      ),
                    ),
                  ),
                  // SizedBox(width: 8),
                  // Expanded(
                  //   child: OutlinedButton(
                  //     onPressed: () async {
                  //       DateTime? picked = await showDatePicker(
                  //         context: context,
                  //         initialDate: DateTime.now(),
                  //         firstDate: DateTime(2000),
                  //         lastDate: DateTime(2100),
                  //       );
                  //       if (picked != null) setState(() => endDate = picked);
                  //     },
                  //     child: Text(
                  //       endDate == null
                  //           ? 'Finish Date'
                  //           : endDate.toString().split(' ')[0],
                  //     ),
                  //   ),
                  // ),
                ],
              ),

              // Reminder Time
              SizedBox(height: 20),
              Text(
                "Reminder Time",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: timeController,
                      readOnly: true,
                      onTap: () async {
                        TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                          initialEntryMode: TimePickerEntryMode.dialOnly,
                        );
                        if (picked != null) {
                          setState(() {
                            pickedTime = picked; // 👈 ADD THIS
                          });
                          final hour = picked.hourOfPeriod.toString().padLeft(
                            2,
                            '0',
                          );
                          final minute = picked.minute.toString().padLeft(
                            2,
                            '0',
                          );
                          final period =
                              picked.period == DayPeriod.am ? 'AM' : 'PM';
                          setState(() {
                            timeController.text = '$hour:$minute $period';
                          });
                        }
                      },
                      decoration: InputDecoration(
                        hintText: '09:30 AM',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              // Display added reminder times
              if (eventList.isEmpty)
                SizedBox.shrink()
              else
                SizedBox(
                  height: listHeight,
                  width: double.infinity,
                  child: ListView.builder(
                    itemCount: eventList.length,
                    itemBuilder: (context, index) {
                      final reminderMap = eventList[index];
                      final title = reminderMap.keys.first;
                      final alarm = reminderMap.values.first;
                      return ListTile(
                        title: Text(
                          '${alarm.dateTime.hour} : ${alarm.dateTime.minute}',
                        ),
                        subtitle: Text(title),

                        trailing: IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () {
                            setState(() {
                              eventList.removeAt(index);
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
            ],
            SizedBox(height: 20),
            Text("Toggles", style: TextStyle(fontWeight: FontWeight.bold)),
            CheckboxListTile(
              value: enableNotifications,
              onChanged: (value) {
                setState(() => enableNotifications = value!);
              },
              title: Text('Enable notifications'),
              controlAffinity: ListTileControlAffinity.leading,
            ),

            CheckboxListTile(
              value: soundVibrationToggle,
              onChanged: (value) {
                setState(() => soundVibrationToggle = value!);
              },
              title: Text('Sound/Vibration toggle'),
              controlAffinity: ListTileControlAffinity.leading,
            ),

            SizedBox(height: 20),
            Text("Notes", style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Optional',
                border: UnderlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: CustomOutlinedButton(
          width: width,
          isDarkMode: isDarkMode,
          buttonName: widget.reminder == null ? "Save" : "Update",
          onTap: () {
            if (selectedCategory == "Medicine") {
              if (pickedTime != null) {
                addAlarm(timeOfDay: pickedTime!, category: "Medicine");
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please select a reminder time')),
                );
              }
            } else if (selectedCategory == "Water") {
              if (waterReminderOption == 0 && savedInterval <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please enter hours interval')),
                );
                return;
              }
              if (waterReminderOption == 1 && savedTimes <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please enter times per day')),
                );
                return;
              }

              setWaterAlarm(
                interval: waterReminderOption == 0 ? savedInterval : null,
                times: waterReminderOption == 1 ? savedTimes : null,
              );
            } else if (selectedCategory == "Meal") {
              if (pickedTime != null) {
                addAlarm(timeOfDay: pickedTime!, category: "Meal");
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please select a meal time')),
                );
              }
            } else if (selectedCategory == "Event") {
              if (pickedTime != null) {
                addAlarm(timeOfDay: pickedTime!, category: "Event");
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please select an event time')),
                );
              }
            }
            // _saveReminder();
          },
        ),
      ),
    );
  }
}
