import 'dart:convert';

import 'package:alarm/alarm.dart';
import 'package:alarm/model/alarm_settings.dart';
import 'package:alarm/model/notification_settings.dart';
import 'package:alarm/model/volume_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:snevva/Controllers/Reminder/reminder_controller.dart';
import 'package:snevva/common/global_variables.dart';
import 'package:snevva/consts/consts.dart';

import '../../common/custom_snackbar.dart';
import '../../models/water_reminder_model.dart';

class WaterController extends GetxController {
  var waterReminderOption = Option.times.obs;
  final everyHourController = TextEditingController();
  final timesPerDayController = TextEditingController();
  final startWaterTimeController = TextEditingController();
  final endWaterTimeController = TextEditingController();
  var waterList = <WaterReminderModel>[].obs;
  var selectedOption = Option.times.obs;
  var savedTimes = 0.obs;
  final everyXhours = 1.obs;

  final startWaterTime = Rx<TimeOfDay?>(null);
  final endWaterTime = Rx<TimeOfDay?>(null);

  ReminderController get reminderController => Get.find<ReminderController>();

  @override
  void onInit() {
    super.onInit();
    print("💧 WaterController initialized");
  }

  Future<void> initialiseWaterReminder() async {
    if (savedTimes.value > 0) {
      final now = DateTime.now();

      final todayTimes = generateTimesBetween(
        startTime: startWaterTimeController.text,
        endTime: endWaterTimeController.text,
        times: savedTimes.value,
      );

      // Find next time today
      DateTime? nextTime;
      for (final time in todayTimes) {
        if (time.isAfter(now)) {
          nextTime = time;
          break;
        }
      }

      // If no time left today → first time tomorrow
      nextTime ??= todayTimes.first.add(const Duration(days: 1));

      print("🔄 Scheduling next water alarm at $nextTime");

      final newAlarm = AlarmSettings(
        id: alarmsId(),
        dateTime: nextTime!,
        assetAudioPath: alarmSound,
        loopAudio: false,
        vibrate: reminderController.soundVibrationToggle.value,
        volumeSettings: VolumeSettings.fade(
          volume: 0.8,
          fadeDuration: const Duration(seconds: 5),
          volumeEnforced: true,
        ),
        notificationSettings: NotificationSettings(
          title:
              reminderController.titleController.text.isNotEmpty
                  ? reminderController.titleController.text
                  : 'WATER REMINDER',
          body:
              reminderController.notesController.text.isNotEmpty
                  ? reminderController.notesController.text
                  : 'Time to drink water!',
          stopButton: 'Stop',
          icon: 'alarm',
          iconColor: AppColors.primaryColor,
        ),
      );

      await Alarm.set(alarmSettings: newAlarm);
    }
  }

  Future<bool> validateAndSaveWaterReminder(BuildContext context) async {
    if (startWaterTimeController.text.isEmpty) {
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Please enter start time',
      );
      return false;
    }

    if (endWaterTimeController.text.isEmpty) {
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Please enter end time',
      );
      return false;
    }

    if (waterReminderOption.value == Option.interval) {
      // Interval mode
      final intervalHours = int.tryParse(everyHourController.text) ?? 0;
      if (intervalHours <= 0) {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Please enter a valid hours interval',
        );
        return false;
      }

      final start = stringToTimeOfDay(startWaterTimeController.text);
      final end = stringToTimeOfDay(endWaterTimeController.text);

      final reminders = generateEveryXHours(
        start: start,
        end: end,
        intervalHours: intervalHours,
      );

      if (reminders.isEmpty) {
        print('No reminders generated for the given interval and time range.');
        return false;
      }
      setIntervalReminders(
        intervalReminders: reminders,
        context: context,
        intervalHours: intervalHours,
      );
      return true;
    }
    if (waterReminderOption.value == Option.times) {
      // Times-per-day mode
      final times = int.tryParse(timesPerDayController.text) ?? 0;
      if (times <= 0) {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Please enter a valid number of times per day',
        );
        return false;
      }
      await setWaterAlarm(times: times, context: context);
      return true;
    }
    return false;
  }

  Future<void> setWaterAlarm({
    required int? times,
    required BuildContext context,
  }) async {
    if (times == null || times <= 0) {
      debugPrint('❌ Invalid times value');
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Please enter a valid number of times per day',
      );
      return;
    }

    final alarmTimes = generateTimesBetween(
      startTime: startWaterTimeController.text,
      endTime: endWaterTimeController.text,
      times: times,
    );

    List<AlarmSettings> createdAlarms = [];

    for (var i = 0; i < alarmTimes.length; i++) {
      final time = alarmTimes[i];
      final scheduledTime =
          time.isBefore(DateTime.now()) ? time.add(Duration(days: 1)) : time;

      final alarmId = alarmsId();
      debugPrint('🔔 Creating alarm [$i] → id=$alarmId, time=$scheduledTime');

      final alarmSettings = AlarmSettings(
        id: alarmId,
        dateTime: scheduledTime,
        assetAudioPath: alarmSound,
        loopAudio: false,
        vibrate: reminderController.soundVibrationToggle.value,
        volumeSettings: VolumeSettings.fade(
          volume: 0.8,
          fadeDuration: Duration(seconds: 5),
          volumeEnforced: true,
        ),
        notificationSettings: NotificationSettings(
          title:
              reminderController.titleController.text.isNotEmpty
                  ? reminderController.titleController.text
                  : 'WATER REMINDER',
          body:
              reminderController.notesController.text.isNotEmpty
                  ? reminderController.notesController.text
                  : 'Time to drink water!',
          stopButton: 'Stop',
          icon: 'alarm',
          iconColor: AppColors.primaryColor,
        ),
      );

      await Alarm.set(alarmSettings: alarmSettings);
      createdAlarms.add(alarmSettings);

      debugPrint('   ✅ Alarm set successfully');
    }

    final waterReminderId = DateTime.now().millisecondsSinceEpoch.toString();
    debugPrint('🆔 Generated water reminder group ID: $waterReminderId');

    print('water reminder title is ${reminderController.titleController.text}');

    final model = WaterReminderModel(
      id: waterReminderId,
      title:
          reminderController.titleController.text.isNotEmpty
              ? reminderController.titleController.text
              : '',
      alarms: createdAlarms,
      timesPerDay: times.toString(),
      category: "Water",
    );

    // Reload list from Hive to ensure we have the latest data and don't override
    waterList.value = await loadWaterReminderList("water_list");

    waterList.add(model);

    debugPrint(
      '📦 WaterReminderModel saved → '
      'id=${model.id}, '
      'alarms=${model.alarms.length}, '
      'timesPerDay=${model.timesPerDay}',
    );

    savedTimes.value = times;
    debugPrint('💾 savedTimes updated → $times');

    await reminderController.saveReminderList(waterList, "water_list");
    debugPrint('💾 Water reminders saved to Hive');

    await reminderController.loadAllReminderLists();
    debugPrint('🔄 Reloaded all reminder lists');

    CustomSnackbar.showSuccess(
      context: context,
      title: 'Success',
      message: 'Water reminders set successfully! ($times times per day)',
    );

    //CustomSnackbar().showReminderBar(context);
    Get.back(result: true);
  }

  List<DateTime> generateTimesBetween({
    required String startTime,
    required String endTime,
    required int times,
  }) {
    if (times <= 0) return [];

    final now = DateTime.now();

    final start = DateFormat('hh:mm a').parse(startTime);
    final end = DateFormat('hh:mm a').parse(endTime);

    DateTime startDT = DateTime(
      now.year,
      now.month,
      now.day,
      start.hour,
      start.minute,
    );

    DateTime endDT = DateTime(
      now.year,
      now.month,
      now.day,
      end.hour,
      end.minute,
    );

    // Handle overnight range
    if (endDT.isBefore(startDT)) {
      endDT = endDT.add(const Duration(days: 1));
    }

    final totalMinutes = endDT.difference(startDT).inMinutes;
    const int minGapMinutes = 1;

    final gap = (totalMinutes / times).floor();

    if (gap < minGapMinutes) {
      debugPrint("Not enough time to schedule $times reminders.");
      debugPrint('totalMinutes=$totalMinutes, times=$times, gap=$gap');
    }

    return List.generate(times, (i) {
      return startDT.add(Duration(minutes: gap * i));
    });
  }

  List<DateTime> generateEveryXHours({
    required TimeOfDay start,
    required TimeOfDay end,
    required int intervalHours,
  }) {
    debugPrint('🔹 generateEveryXHours called');
    debugPrint('   Start TimeOfDay: ${start.hour}:${start.minute}');
    debugPrint('   End TimeOfDay  : ${end.hour}:${end.minute}');
    debugPrint('   Interval Hours: $intervalHours');

    if (intervalHours <= 0) {
      debugPrint('❌ Invalid intervalHours, returning empty list');
      return [];
    }

    final window = buildTimeWindow(start, end);

    debugPrint('🕒 Time Window');
    debugPrint('   Start DateTime: ${window.start}');
    debugPrint('   End DateTime  : ${window.end}');

    final reminders = <DateTime>[];
    DateTime current = window.start;

    int counter = 0;

    while (!current.isAfter(window.end)) {
      debugPrint('⏰ Reminder #$counter → $current');

      reminders.add(current);

      final next = current.add(Duration(hours: intervalHours));
      debugPrint('   Next calculated time: $next');

      current = next;
      counter++;

      // Safety guard (prevents infinite loops in debug)
      if (counter > 100) {
        debugPrint('🚨 Loop safety break triggered');
        break;
      }
    }

    debugPrint('✅ Total reminders generated: ${reminders.length}');
    return reminders;
  }

  Future<void> setIntervalReminders({
    required List<DateTime> intervalReminders,
    required int intervalHours,
    required BuildContext context,
  }) async {
    debugPrint(
      '🔹 setIntervalReminders called with ${intervalReminders.length} reminders',
    );

    for (var reminderTime in intervalReminders) {
      debugPrint('   Scheduling reminder for: $reminderTime');

      final alarmSettings = AlarmSettings(
        id: alarmsId(),
        dateTime: reminderTime,
        notificationSettings:
            reminderController.enableNotifications.value
                ? NotificationSettings(
                  title:
                      reminderController.titleController.text.isNotEmpty
                          ? reminderController.titleController.text
                          : 'Water reminder',
                  body:
                      reminderController.notesController.text.isNotEmpty
                          ? reminderController.notesController.text
                          : '',
                  stopButton: 'Stop',
                  icon: 'alarm',
                  iconColor: AppColors.primaryColor,
                )
                : NotificationSettings(
                  title: 'Water reminder',
                  body: '',
                  stopButton: 'Stop',
                  icon: 'alarm',
                ),
        assetAudioPath: alarmSound,
        volumeSettings: VolumeSettings.fade(
          volume: 0.8,
          fadeDuration: Duration(seconds: 5),
          volumeEnforced: true,
        ),
      );

      await Alarm.set(alarmSettings: alarmSettings);
      debugPrint('   Reminder scheduled with ID: ${alarmSettings.id}');
    }
    final waterReminderId = DateTime.now().millisecondsSinceEpoch.toString();
    debugPrint('🆔 Generated water reminder group ID: $waterReminderId');

    debugPrint("Interval Hours: $intervalHours");

    final model = WaterReminderModel(
      id: waterReminderId,
      title:
          reminderController.titleController.text.isNotEmpty
              ? reminderController.titleController.text
              : '',
      alarms: [],
      timesPerDay: '',
      interval: '$intervalHours',
      category: "Water",
    );

    // Reload list from Hive to ensure we have the latest data and don't override
    waterList.value = await loadWaterReminderList("water_list");
    waterList.add(model);

    debugPrint(
      '📦 WaterReminderModel saved → '
      'id=${model.id}, '
      'alarms=${model.alarms.length}, '
      'interval=${model.interval}, '
      'intervalHours=${model.timesPerDay}',
    );
    //final waterList = reminderController.waterList;

    await reminderController.saveReminderList(waterList, "water_list");
    print('💾 Water reminders saved to Hive');

    await reminderController.loadAllReminderLists();
    print('🔄 Reloaded all reminder lists');

    CustomSnackbar.showSuccess(
      context: context,
      title: 'Success',
      message:
          'Water reminders set successfully! (${everyXhours.value} hours per day between ${startWaterTime.value} and ${endWaterTime.value})',
    );

    CustomSnackbar().showReminderBar(context);
    Get.back(result: true);

    debugPrint('✅ All interval reminders have been scheduled.');
  }

  DateTime? _calculateNextWaterAlarm(int intervalHours) {
    final now = DateTime.now();
    final startTime = startWaterTimeController.value; // e.g., 8:00 AM
    final endTime = startWaterTimeController.value; // e.g., 10:00 PM

    if (startTime != null && endTime != null) {
      // Convert to DateTime
      DateTime startDateTime = DateTime(now.year, now.month, now.day);
      DateTime endDateTime = DateTime(now.year, now.month, now.day);
      // Handle overnight window (e.g., 10 PM to 2 AM)
      if (endDateTime.isBefore(startDateTime)) {
        endDateTime = endDateTime.add(Duration(days: 1));
      }
      // Calculate next alarm
      DateTime nextAlarm = now.add(Duration(hours: intervalHours));

      // SCENARIO 1: Current time is BEFORE start time today
      if (now.isBefore(startDateTime)) {
        nextAlarm = startDateTime; // Set to start time today
      } // SCENARIO 2: Next alarm would be AFTER end time today
      else if (nextAlarm.isAfter(endDateTime)) {
        nextAlarm = startDateTime.add(Duration(days: 1)); // Tomorrow's start
      }
      // SCENARIO 3: Current time is AFTER end time today
      else if (now.isAfter(endDateTime)) {
        nextAlarm = startDateTime.add(Duration(days: 1)); // Tomorrow's start
      }

      return nextAlarm;
    } else {
      debugPrint('❌ Invalid water time window');
      return null;
    }
  }

  DateTimeRange getActiveWindow() {
    final start = combineWithToday(startWaterTime.value!);
    var end = combineWithToday(endWaterTime.value!);

    // Overnight window (e.g. 10 PM → 6 AM)
    if (end.isBefore(start)) {
      end = end.add(const Duration(days: 1));
    }

    return DateTimeRange(start: start, end: end);
  }

  Duration _waterDuration() {
    DateTime start = parseWaterTime(startWaterTimeController.text);
    DateTime end = parseWaterTime(endWaterTimeController.text);

    if (end.isBefore(start)) {
      end = end.add(const Duration(days: 1));
    }

    return end.difference(start);
  }

  DateTime parseWaterTime(String time) {
    final now = DateTime.now();
    final parsed = DateFormat('hh:mm a').parse(time);

    return DateTime(now.year, now.month, now.day, parsed.hour, parsed.minute);
  }

  Future<void> updateWaterReminderFromLocal(
    BuildContext context,
    String id,
    int? times,
  ) async {
    try {
      print("🚰 Updating WATER reminder");

      final index = waterList.indexWhere((e) => e.id == id);
      print("🔍 waterList index → $index");

      if (index != -1) {
        final oldModel = waterList[index];
        print("🛑 stopping ${oldModel.alarms.length} old alarms");

        for (var alarm in oldModel.alarms) {
          print("🛑 stop alarm id=${alarm.id}");
          await Alarm.stop(alarm.id);
        }

        waterList.removeAt(index);
        await reminderController.saveReminderList(waterList, "water_list");
        print("🗑️ old water reminder removed");
      }

      print("➕ creating new water alarms with times=$times");
      await setWaterAlarm(times: times, context: context);
    } catch (e) {
      throw Exception("Error updating WATER reminder: $e");
    }
  }

  Future<List<WaterReminderModel>> loadWaterReminderList(String keyName) async {
    print('📦 Loading water reminders from Hive → key: $keyName');

    final box = Hive.box('reminders_box');
    final List<dynamic>? storedList = box.get(keyName);

    if (storedList == null) {
      print('⚠️ No data found in Hive for key: $keyName');
      return [];
    }

    print('📄 Raw stored list length: ${storedList.length}');

    final List<String> stringList = storedList.cast<String>();
    List<WaterReminderModel> loadedList = [];

    for (var i = 0; i < stringList.length; i++) {
      final item = stringList[i];
      print('🔍 Parsing item [$i]: $item');

      try {
        final Map<String, dynamic> decoded = jsonDecode(item);
        print('✅ Decoded JSON: $decoded');

        if (decoded.containsKey('timesPerDay')) {
          print('🆕 New water reminder format detected');
          final model = WaterReminderModel.fromJson(decoded);
          loadedList.add(model);

          print(
            '   ➜ Loaded WaterReminderModel → '
            'id=${model.id}, '
            'title=${model.title}, '
            'alarms=${model.alarms.length}, '
            'interval=${model.interval}, '
            'timesPerDay=${model.timesPerDay}',
          );
        } else {
          print('🟡 Old format detected, migrating…');

          final entry = decoded.entries.first;
          final fallbackModel = WaterReminderModel(
            title: entry.key,
            id: alarmsId().toString(),
            alarms: [],
            timesPerDay: timesPerDayController.text,
            category: "Water",
          );

          loadedList.add(fallbackModel);

          print(
            '   ➜ Migrated WaterReminderModel → '
            'id=${fallbackModel.id}, '
            'title=${fallbackModel.title}',
          );
        }
      } catch (e, stack) {
        print('❌ Error parsing water reminder: $e');
        print(stack);
      }
    }

    print('✅ Total water reminders loaded: ${loadedList.length}');
    return loadedList;
  }

  Future<void> deleteWaterReminder(String id) async {
    int index = -1;
    for (int i = 0; i < waterList.length; i++) {
      if (waterList[i].id == id) {
        index = i;
        break;
      }
    }

    if (index != -1) {
      // Stop all alarms in this water reminder group
      for (var alarm in waterList[index].alarms) {
        await Alarm.stop(alarm.id);
      }
      waterList.removeAt(index);
      await reminderController.saveReminderList(waterList, "water_list");
    }
  }

  void resetControllers() {
    everyHourController.clear();
    timesPerDayController.clear();

    startWaterTimeController.clear();
    endWaterTimeController.clear();
    savedTimes.value = 0;
    startWaterTime.value = null;
    endWaterTime.value = null;
    everyXhours.value = 1;
    waterReminderOption.value = Option.times;
  }

  @override
  void onClose() {
    everyHourController.dispose();
    timesPerDayController.dispose();
    super.onClose();
  }
}
