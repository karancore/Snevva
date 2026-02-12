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
import 'package:snevva/models/hive_models/reminder_payload_model.dart';

import '../../common/custom_snackbar.dart';
import '../../models/reminders/water_reminder_model.dart';

class WaterController extends GetxController {
  var waterReminderOption = Option.times.obs;
  final everyHourController = TextEditingController();
  final timesPerDayController = TextEditingController();
  final startWaterTimeController = TextEditingController();
  final endWaterTimeController = TextEditingController();
  var waterList = <WaterReminderModel>[].obs;
  var savedTimes = 0.obs;
  final everyXhours = 1.obs;

  final startWaterTime = Rx<TimeOfDay?>(null);
  final endWaterTime = Rx<TimeOfDay?>(null);

  ReminderController get reminderController =>
      Get.find<ReminderController>(tag: 'reminder');

  @override
  void onInit() {
    super.onInit();
    print("💧 WaterController initialized");
  }

  void resetForm() {
    // ---------- Text controllers ----------
    everyHourController.clear();
    timesPerDayController.clear();
    startWaterTimeController.clear();
    endWaterTimeController.clear();

    // ---------- Rx values ----------
    waterReminderOption.value = Option.times;
    savedTimes.value = 0;
    everyXhours.value = 1;

    startWaterTime.value = null;
    endWaterTime.value = null;

    // ---------- Local state ----------
    waterList.clear(); // optional: remove if you want to keep loaded reminders
  }

  Future<void> initialiseWaterReminder() async {
    debugPrint("🔄 initialiseWaterReminder called");

    final list = await loadWaterReminderList("water_list");

    if (list.isEmpty) {
      debugPrint("🚫 No water reminders found → skip reschedule");
      return;
    }

    debugPrint("📦 Loaded ${list.length} water reminders");

    if (savedTimes.value <= 0) {
      debugPrint("⚠️ savedTimes is 0 → nothing to schedule");
      return;
    }

    final todayTimes = generateTimesBetween(
      startTime: startWaterTimeController.text,
      endTime: endWaterTimeController.text,
      times: savedTimes.value,
    );

    debugPrint("⏰ Generated ${todayTimes.length} times");

    DateTime? nextTime;
    for (final time in todayTimes) {
      if (time.isAfter(now)) {
        nextTime = time;
        break;
      }
    }

    nextTime ??= todayTimes.first.add(const Duration(days: 1));

    debugPrint("🔔 Next water alarm at $nextTime");

    final alarm = AlarmSettings(
      id: alarmsId(),
      dateTime: nextTime,
      assetAudioPath: alarmSound,
      loopAudio: false,
      androidFullScreenIntent: true,
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

    await Alarm.set(alarmSettings: alarm);
    debugPrint("✅ Initial water alarm scheduled");
  }

  // ---------------------------------------------------------------------------
  // Validation & Save
  // ---------------------------------------------------------------------------

  Future<bool> validateAndSaveWaterReminder(BuildContext context) async {
    debugPrint("📝 validateAndSaveWaterReminder called");
    debugPrint("🔧 Mode = ${waterReminderOption.value}");

    if (startWaterTimeController.text.isEmpty) {
      debugPrint("❌ Start time missing");
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Please enter start time',
      );
      return false;
    }

    if (endWaterTimeController.text.isEmpty) {
      debugPrint("❌ End time missing");
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Please enter end time',
      );
      return false;
    }

    if (waterReminderOption.value == Option.interval) {
      final intervalHours = int.tryParse(everyHourController.text) ?? 0;
      debugPrint("⏱ Interval mode → every $intervalHours hours");

      if (intervalHours <= 0) {
        debugPrint("❌ Invalid interval");
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Please enter a valid hours interval',
        );
        return false;
      }

      final reminders = generateEveryXHours(
        start: stringToTimeOfDay(startWaterTimeController.text),
        end: stringToTimeOfDay(endWaterTimeController.text),
        intervalHours: intervalHours,
      );

      debugPrint("⏰ Generated ${reminders.length} interval alarms");

      if (reminders.isEmpty) {
        debugPrint("❌ No reminders generated");
        return false;
      }

      await setIntervalReminders(
        intervalReminders: reminders,
        context: context,
        title: 'Water',
        intervalHours: intervalHours,
        body: reminderController.notesController.text.trim(),
      );
      return true;
    }

    if (waterReminderOption.value == Option.times) {
      final times = int.tryParse(timesPerDayController.text) ?? 0;
      debugPrint("🔁 Times-per-day mode → $times times");

      if (times <= 0) {
        debugPrint("❌ Invalid times-per-day");
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

    debugPrint("❌ Unknown reminder option");
    return false;
  }

  // ---------------------------------------------------------------------------
  // Time Generators
  // ---------------------------------------------------------------------------

  Future<void> setWaterAlarm({
    required int? times,
    required BuildContext context,
  }) async {
    if (times == null || times <= 0) {
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

    final reminderGroupId = alarmsId();
    List<AlarmSettings> createdAlarms = [];

    for (var i = 0; i < alarmTimes.length; i++) {
      final time = alarmTimes[i];
      final scheduledTime =
          time.isBefore(DateTime.now()) ? time.add(Duration(days: 1)) : time;

      final alarmId = alarmsId();
      final alarmSettings = AlarmSettings(
        id: alarmId,
        dateTime: scheduledTime,
        assetAudioPath: alarmSound,
        loopAudio: false,
        androidFullScreenIntent: true,
        volumeSettings: VolumeSettings.fade(
          volume: 0.8,
          fadeDuration: Duration(seconds: 5),
          volumeEnforced: true,
        ),
        payload: jsonEncode({
          "groupId": reminderGroupId.toString(),
          "type": "times",
          "category": ReminderCategory.water.toString(),
        }),
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
    }

    final model = WaterReminderModel(
      id: reminderGroupId,
      title:
          reminderController.titleController.text.isNotEmpty
              ? reminderController.titleController.text
              : 'WATER REMINDER',
      alarms: createdAlarms,
      waterReminderStartTime: startWaterTimeController.text.trim(),
      waterReminderEndTime: endWaterTimeController.text.trim(),
      notes: reminderController.notesController.text.trim(),
      type: Option.times,
      timesPerDay: times.toString(),
      category: ReminderCategory.water.toString(),
    );

    // Reload list from Hive to ensure we have the latest data and don't override
    waterList.value = await loadWaterReminderList("water_list");

    waterList.add(model);

    savedTimes.value = times;

    await reminderController.saveReminderList(waterList, "water_list");
    await reminderController.loadAllReminderLists();

    List<String> list =
        createdAlarms.map((e) => e.toJson().toString()).toList();

    final waterData = ReminderPayloadModel(
      id: reminderGroupId,
      category: ReminderCategory.water.toString(),
      title: model.title,
      notes: reminderController.notesController.text,
      reminderFrequencyType: Option.times.toString(),
      customReminder: CustomReminder(
        timesPerDay: TimesPerDay(count: times.toString(), list: list),
      ),
      startWaterTime: startWaterTimeController.text.trim(),
      endWaterTime: endWaterTimeController.text.trim(),
    );

    print("Water Data setWaterAlarm: $waterData");

    //reminderController.addRemindertoAPI(waterData, context);

    CustomSnackbar().showReminderBar(context);
    Get.back(result: true);
  }

  List<DateTime> generateTimesBetween({
    required String startTime,
    required String endTime,
    required int times,
  }) {
    debugPrint(
      "🧮 generateTimesBetween → start=$startTime end=$endTime times=$times",
    );

    if (times <= 0) return [];

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

    if (endDT.isBefore(startDT)) {
      debugPrint("🌙 Overnight window detected");
      endDT = endDT.add(const Duration(days: 1));
    }

    final totalMinutes = endDT.difference(startDT).inMinutes;
    final gap = (totalMinutes / times).floor();

    debugPrint("⏱ totalMinutes=$totalMinutes gap=$gap");

    return List.generate(times, (i) {
      final t = startDT.add(Duration(minutes: gap * i));
      debugPrint("⏰ Generated time[$i] → $t");
      return t;
    });
  }

  List<DateTime> generateEveryXHours({
    required TimeOfDay start,
    required TimeOfDay end,
    required int intervalHours,
  }) {
    debugPrint("⏱ generateEveryXHours → every $intervalHours hours");

    if (intervalHours <= 0) return [];

    final window = buildTimeWindow(start, end);
    final reminders = <DateTime>[];

    DateTime current = window.start.add(Duration(hours: intervalHours));
    int counter = 0;

    while (!current.isAfter(window.end)) {
      reminders.add(current);
      debugPrint("⏰ Interval reminder → $current");

      current = current.add(Duration(hours: intervalHours));
      counter++;

      if (counter > 100) {
        debugPrint("⚠️ Safety break triggered");
        break;
      }
    }

    return reminders;
  }

  Future<void> onWaterAlarmRang(int rangAlarmId) async {
    final alarms = await Alarm.getAlarms();
    final stillExists = alarms.any((alarm) {
      if (alarm.payload == null) return false;
      try {
        final decoded = jsonDecode(alarm.payload!);
        return decoded['category'] == ReminderCategory.water.toString();
      } catch (_) {
        return false;
      }
    });
    if (!stillExists) {
      debugPrint("Water reminder deleted , skip reschedule");
      return;
    }

    /// Load from your existing function
    List<Map<String, AlarmSettings>> list = await reminderController
        .loadReminderList("water_list");

    for (int i = 0; i < list.length; i++) {
      final map = list[i];

      for (final entry in map.entries) {
        final String title = entry.key;
        final AlarmSettings alarm = entry.value;

        /// FOUND the alarm that rang
        if (alarm.id == rangAlarmId) {
          debugPrint("🚰 Found rang water alarm: $rangAlarmId ($title)");

          /// IMPORTANT: stop previous instance
          await Alarm.stop(rangAlarmId);

          /// Calculate next day same time
          DateTime nextTime = DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
            alarm.dateTime.hour,
            alarm.dateTime.minute,
          ).add(const Duration(days: 1));

          if (nextTime.isBefore(DateTime.now())) {
            nextTime = nextTime.add(const Duration(days: 1));
          }

          /// Create new alarm
          final newAlarm = AlarmSettings(
            id: rangAlarmId,
            // reuse SAME id
            dateTime: nextTime,
            assetAudioPath: alarm.assetAudioPath,
            loopAudio: true,
            vibrate: true,
            volumeSettings: alarm.volumeSettings,
            notificationSettings: alarm.notificationSettings,
          );

          /// Schedule again
          await Alarm.set(alarmSettings: newAlarm);

          /// Replace inside map
          list[i][title] = newAlarm;

          /// Convert back to JSON string list (VERY IMPORTANT)
          final List<String> encoded =
              list.map((mapItem) {
                final encodedMap = mapItem.map(
                  (k, v) => MapEntry(k, v.toJson()),
                );
                return jsonEncode(encodedMap);
              }).toList();

          /// Save back to Hive
          final box = Hive.box('reminders_box');
          await box.put("water_list", encoded);

          debugPrint("🔁 Water alarm rescheduled for $nextTime");

          return;
        }
      }
    }

    debugPrint("⚠️ Rang alarm not found in water_list: $rangAlarmId");
  }

  Future<void> setIntervalReminders({
    required List<DateTime> intervalReminders,
    required int intervalHours,
    BuildContext? context,
    required String title,
    required String body,
  }) async {
    final reminderGroupId = alarmsId();
    final List<AlarmSettings> createdAlarms = [];
    for (var reminderTime in intervalReminders) {
      final alarmSettings = AlarmSettings(
        id: alarmsId(),
        dateTime: reminderTime,
        notificationSettings: NotificationSettings(
          title:
              reminderController.titleController.text.isNotEmpty
                  ? reminderController.titleController.text
                  : '$title reminder',
          body: body,
          stopButton: 'Stop',
          icon: 'alarm',
          iconColor: AppColors.primaryColor,
        ),
        androidFullScreenIntent: true,
        payload: jsonEncode({
          "groupId": reminderGroupId.toString(),
          "type": "interval",
          "category": ReminderCategory.water.toString(),
        }),

        assetAudioPath: alarmSound,
        volumeSettings: VolumeSettings.fade(
          volume: 0.8,
          fadeDuration: Duration(seconds: 5),
          volumeEnforced: true,
        ),
      );

      await Alarm.set(alarmSettings: alarmSettings);
      createdAlarms.add(alarmSettings);
    }

    final model = WaterReminderModel(
      id: reminderGroupId,
      title:
          reminderController.titleController.text.isNotEmpty
              ? reminderController.titleController.text
              : '',
      alarms: createdAlarms,
      timesPerDay: '',
      notes: reminderController.notesController.text.trim(),
      waterReminderStartTime: startWaterTimeController.text.trim(),
      waterReminderEndTime: endWaterTimeController.text.trim(),
      type: Option.interval,
      interval: '$intervalHours',
      category: ReminderCategory.water.toString(),
    );

    // Reload list from Hive to ensure we have the latest data and don't override
    waterList.value = await loadWaterReminderList("water_list");
    waterList.add(model);

    await reminderController.saveReminderList(waterList, "water_list");

    await reminderController.loadAllReminderLists();

    final waterData = ReminderPayloadModel(
      id: reminderGroupId,
      category: ReminderCategory.water.toString(),
      title: model.title,
      notes: reminderController.notesController.text,
      reminderFrequencyType: Option.interval.toString(),
      customReminder: CustomReminder(
        everyXHours: EveryXHours(
          hours: intervalHours,
          startTime: startWaterTimeController.text,
          endTime: endWaterTimeController.text,
        ),
      ),
      startWaterTime: startWaterTimeController.text.trim(),
      endWaterTime: endWaterTimeController.text.trim(),
    );
    print("Water Data setIntervalReminders: $waterData");

    // reminderController.addRemindertoAPI(waterData, context);

    if (context != null) {
      CustomSnackbar().showReminderBar(context);
    }
    Get.back(result: true);
  }

  DateTime? _calculateNextWaterAlarm(int intervalHours) {
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
      debugPrint('Invalid water time window');
      return null;
    }
  }

  Future<void> updateWaterReminderFromLocal(
    BuildContext context,
    String id,
    int? times,
  ) async {
    try {
      final parsedId = int.tryParse(id);
      if (parsedId == null) return;
      final index = waterList.indexWhere((e) => e.id == parsedId);

      if (index != -1) {
        final oldModel = waterList[index];

        for (var alarm in oldModel.alarms) {
          await Alarm.stop(alarm.id);
        }

        waterList.removeAt(index);
        await reminderController.saveReminderList(waterList, "water_list");
      }

      await setWaterAlarm(times: times, context: context);
    } catch (e) {
      throw Exception("Error updating WATER reminder: $e");
    }
  }

  Future<List<WaterReminderModel>> loadWaterReminderList(String keyName) async {
    final box = Hive.box('reminders_box');
    final List<dynamic>? storedList = box.get(keyName);

    if (storedList == null) {
      return [];
    }

    final List<String> stringList = storedList.cast<String>();
    List<WaterReminderModel> loadedList = [];

    for (var i = 0; i < stringList.length; i++) {
      final item = stringList[i];

      try {
        final Map<String, dynamic> decoded = jsonDecode(item);

        if (decoded.containsKey('timesPerDay')) {
          final model = WaterReminderModel.fromJson(decoded);
          loadedList.add(model);
        } else {
          final entry = decoded.entries.first;
          final fallbackModel = WaterReminderModel(
            title: entry.key,
            id: alarmsId(),
            alarms: [],
            notes: reminderController.notesController.text.trim(),
            type: waterReminderOption.value,
            timesPerDay: timesPerDayController.text,
            category: ReminderCategory.water.toString(),
            waterReminderStartTime: startWaterTimeController.text.trim(),
            waterReminderEndTime: endWaterTimeController.text.trim(),
          );

          loadedList.add(fallbackModel);
        }
      } catch (e, stack) {
        print(' Error parsing water reminder: $e');
        print(stack);
      }
    }
    return loadedList;
  }

  // Future<void> deleteWaterReminder(int id) async {
  //   debugPrint('🗑️ deleteWaterReminder called with id=$id');
  //
  //   int index = -1;
  //
  //   for (int i = 0; i < waterList.length; i++) {
  //     debugPrint(
  //       '🔍 Checking waterList[$i] → storedId=${waterList[i].id} '
  //       '(type=${waterList[i].id.runtimeType})',
  //     );
  //
  //     if (waterList[i].id == id) {
  //       index = i;
  //       break;
  //     }
  //   }
  //
  //   if (index != -1) {
  //     debugPrint('✅ Water reminder found at index=$index');
  //
  //     for (var alarm in waterList[index].alarms) {
  //       debugPrint('⏹️ Stopping alarm id=${alarm.id}');
  //       await Alarm.stop(alarm.id);
  //     }
  //
  //     waterList.removeAt(index);
  //     debugPrint('🗑️ Removed water reminder. Remaining=${waterList.length}');
  //
  //     await reminderController.saveReminderList(waterList, "water_list");
  //     debugPrint('💾 Water list saved to Hive');
  //   } else {
  //     debugPrint('❌ No water reminder found with id=$id');
  //   }
  // }

  Future<void> deleteWaterReminder(int reminderId) async {
    debugPrint("🗑️ deleteWaterReminder called → id=$reminderId");
    waterList.value = await loadWaterReminderList("water_list");

    final alarms = await Alarm.getAlarms();

    for (final alarm in alarms) {
      if (alarm.payload == null) continue;
      try {
        final decoded = jsonDecode(alarm.payload!);
        final category = decoded['category']?.toString();
        final groupId = decoded['groupId']?.toString();
        if (_isWaterCategory(category) && groupId == reminderId.toString()) {
          debugPrint("⏹️ Stopping alarm ${alarm.id}");
          await Alarm.stop(alarm.id);
        }
      } catch (e) {
        debugPrint("❌ Payload parse error: $e");
      }
    }

    final index = waterList.indexWhere((e) => e.id == reminderId);
    if (index != -1) {
      waterList.removeAt(index);
      debugPrint("✅ Water reminder removed from list");
    }

    await reminderController.saveReminderList(waterList, "water_list");
    debugPrint("💾 Water list saved after delete");
  }

  bool _isWaterCategory(String? category) {
    if (category == null) return false;
    return category == 'water' || category == ReminderCategory.water.toString();
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
    resetForm();
    super.onClose();
  }
}
