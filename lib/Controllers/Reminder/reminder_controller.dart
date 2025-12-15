import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:alarm/alarm.dart';
import 'package:alarm/model/alarm_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'package:snevva/common/animted_reminder_bar.dart';
import 'package:snevva/common/custom_snackbar.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/env/env.dart';
import 'package:snevva/services/api_service.dart';

import '../../common/global_variables.dart';

class ReminderController extends GetxController {
  final titleController = TextEditingController();
  final medicineController = TextEditingController();
  final timeController = TextEditingController();
  final notesController = TextEditingController();

  final beforeReminderController = TextEditingController();

  final everyHourController = TextEditingController();

  final timesPerDayController = TextEditingController();

  var reminders = <Map<String, dynamic>>[].obs;
  var alarms = <AlarmSettings>[].obs;
  var isLoading = false.obs;
  final selectedValue = 'minutes'.obs;

  var medicineList = <Map<String, AlarmSettings>>[].obs;
  var eventList = <Map<String, AlarmSettings>>[].obs;
  var waterList = <Map<String, AlarmSettings>>[].obs;
  var mealsList = <Map<String, AlarmSettings>>[].obs;

  var medicineMeta = <Map<String, dynamic>>[].obs; // { "medicines": ["a","b"] }
  var eventMeta =
      <Map<String, dynamic>>[]
          .obs; // { "before_amount": 10, "before_unit": "minutes" }
  var waterMeta =
      <Map<String, dynamic>>[]
          .obs; // { "interval_hours": 3, "times_per_day": null }
  var mealsMeta = <Map<String, dynamic>>[].obs; // reserved for future meta

  var selectedDateIndex = 0.obs;

  var medicineNames = <String>[].obs;
  var remindTimes = <String>[].obs;

  var selectedCategory = 'Medicine'.obs;
  var enableNotifications = false.obs;
  var soundVibrationToggle = true.obs;
  var waterReminderOption = 1.obs; // 0 = interval, 1 = times/day
  var eventReminderOption = 0.obs; // 0 = before reminder enabled, 1 = disabled

  var savedInterval = 0.obs;
  var savedTimes = 0.obs;

  Rx<DateTime?> startDate = Rx<DateTime?>(null);
  Rx<DateTime?> endDate = Rx<DateTime?>(null);
  Rx<TimeOfDay?> pickedTime = Rx<TimeOfDay?>(null);

  static StreamSubscription<AlarmSettings>? subscription;
  bool listenerAttached = false;

  final List<String> categories = ['Medicine', 'Water', 'Meal', 'Event'];
  final double itemHeight = 56.0;
  final double maxHeight = 150.0;

  @override
  void onInit() {
    super.onInit();
    startDate.value = DateTime.now();
    checkAndroidNotificationPermission();
    checkAndroidScheduleExactAlarmPermission();
    loadAlarms();
    initAlarmListener();

    loadAllReminderLists();
  }

  @override
  void onClose() {
    subscription?.cancel();
    titleController.dispose();
    medicineController.dispose();
    timeController.dispose();
    notesController.dispose();
    beforeReminderController.dispose();
    everyHourController.dispose();
    timesPerDayController.dispose();
    super.onClose();
  }

  Future<void> checkAndroidNotificationPermission() async {
    final status = await Permission.notification.status;
    if (status.isDenied || status.isRestricted || status.isLimited) {
      if (kDebugMode) print('Requesting notification permission...');
      final res = await Permission.notification.request();
      enableNotifications.value = res.isGranted;
      if (kDebugMode) {
        print(
          'Notification permission ${res.isGranted ? 'granted' : 'not granted'}',
        );
      }
    } else {
      enableNotifications.value = status.isGranted;
      if (kDebugMode) {
        print(
          'Notification permission ${status.isGranted ? 'already granted' : 'not granted'}',
        );
      }
    }
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

  // ==================== Alarm Listener ====================

  void initAlarmListener() {
    if (listenerAttached) return;
    listenerAttached = true;

    subscription ??= Alarm.ringStream.stream.listen((
      AlarmSettings alarmSettings,
    ) async {
      if (kDebugMode) print("🔔 ALARM RANG → ID: ${alarmSettings.id}");

      bool isWaterAlarm = false;
      for (var item in waterList) {
        if (item.values.first.id == alarmSettings.id) {
          isWaterAlarm = true;
          break;
        }
      }

      if (isWaterAlarm) {
        await Alarm.stop(alarmSettings.id);

        if (savedInterval.value > 0) {
          if (kDebugMode) {
            print(
              "🔄 Rescheduling water alarm (every ${savedInterval.value} hours)",
            );
          }
          await scheduleAlarmEveryXHours(savedInterval.value);
        } else if (savedTimes.value > 0) {
          int totalMinutes = (24 * 60) ~/ savedTimes.value;
          int hours = totalMinutes ~/ 60;
          int minutes = totalMinutes % 60;

          if (kDebugMode) {
            print(
              "🔄 Rescheduling water alarm (${savedTimes.value} times/day = ${hours}h ${minutes}m)",
            );
          }

          final nextTime = DateTime.now().add(
            Duration(hours: hours, minutes: minutes),
          );

          final newAlarm = AlarmSettings(
            id: _alarmId(),
            dateTime: nextTime,
            assetAudioPath: alarmSound,
            loopAudio: true,
            vibrate: soundVibrationToggle.value,
            volumeSettings: VolumeSettings.fade(
              volume: 0.8,
              fadeDuration: Duration(seconds: 5),
              volumeEnforced: true,
            ),
            androidFullScreenIntent: true,
            warningNotificationOnKill: Platform.isIOS,
            notificationSettings:
                enableNotifications.value
                    ? NotificationSettings(
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
                    )
                    : NotificationSettings(
                      title: 'Water Reminder',
                      body: 'Drink water',
                      stopButton: 'Stop',
                      icon: 'alarm',
                    ),
          );

          await Alarm.set(alarmSettings: newAlarm);
        }
      }
      // Medicine, Meal, Event alarms will keep ringing until user stops them
    });
  }

  // ==================== Alarm Management ====================

  Future<void> loadAlarms() async {
    final loadedAlarms = await Alarm.getAlarms();
    loadedAlarms.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    alarms.value = loadedAlarms;
  }

  int _alarmId() {
    final rand = Random().nextInt(1 << 16);
    return (DateTime.now().millisecondsSinceEpoch & 0x7fffffff) ^ rand;
  }

  Future<void> setBeforeReminderAlarm(DateTime mainTime) async {
    // This method expects that beforeReminderController and selectedValue are set.
    int amount = int.tryParse(beforeReminderController.text) ?? 0;
    String unit = selectedValue.value; // "minutes" or "hours"

    if (amount <= 0) return; // nothing to schedule

    Duration offset =
        unit == "minutes" ? Duration(minutes: amount) : Duration(hours: amount);

    DateTime beforeTime = mainTime.subtract(offset);

    if (beforeTime.isBefore(DateTime.now())) {
      beforeTime = beforeTime.add(Duration(days: 1));
    }

    final alarmSettings = AlarmSettings(
      id: _alarmId(),
      dateTime: beforeTime,
      assetAudioPath: alarmSound,
      loopAudio: true,
      vibrate: soundVibrationToggle.value,
      androidFullScreenIntent: true,
      warningNotificationOnKill: Platform.isIOS,
      notificationSettings: NotificationSettings(
        title: "Reminder before your event",
        body: "Your event is coming in $amount $unit",
        stopButton: "Stop",
        icon: "alarm",
      ),
      volumeSettings: VolumeSettings.fade(fadeDuration: Duration(seconds: 2)),
    );

    await Alarm.set(alarmSettings: alarmSettings);

    // save meta for the event to allow editing later
    eventMeta.add({
      'before_amount': amount,
      'before_unit': unit,
      'generated_for': mainTime.toIso8601String(),
    });
    await _saveMetaList(eventMeta, 'event_list_meta');
  }

  DateTime calculateBeforeReminder() {
    final now = DateTime.now();

    // Parse input time (hh:mm a)
    final selectedTime = _parseTime(timeController.text);

    DateTime eventTime = DateTime(
      now.year,
      now.month,
      now.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    int value = int.tryParse(beforeReminderController.text) ?? 0;

    Duration diff =
        selectedValue.value == "minutes"
            ? Duration(minutes: value)
            : Duration(hours: value);

    DateTime reminderTime = eventTime.subtract(diff);

    // If reminder is in the past → move to tomorrow
    if (reminderTime.isBefore(now)) {
      reminderTime = reminderTime.add(Duration(days: 1));
    }

    return reminderTime;
  }

  Future<void> addAlarm(
    BuildContext context, {
    required TimeOfDay timeOfDay,
    required String category,
  }) async {
    final now = DateTime.now();

    var scheduledTime = DateTime(
      startDate.value?.year ?? now.year,
      startDate.value?.month ?? now.month,
      startDate.value?.day ?? now.day,
      timeOfDay.hour,
      timeOfDay.minute,
    );

    if (scheduledTime.isBefore(now) || scheduledTime.isAtSameMomentAs(now)) {
      scheduledTime = scheduledTime.add(Duration(days: 1));
      if (kDebugMode) {
        print('⚠️ Time was in past/now, moved to tomorrow: $scheduledTime');
      }
    }

    switch (category) {
      case "Medicine":
        await _addMedicineAlarm(scheduledTime, context);
        break;
      case "Meal":
        await _addMealAlarm(scheduledTime, context);
        break;
      case "Event":
        await _addEventAlarm(scheduledTime, context);
        break;
    }

    // Only schedule before-minute reminder for events and only if enabled
    if (category == "Event" && eventReminderOption.value == 0) {
      await setBeforeReminderAlarm(scheduledTime);
    }
  }

  Future<void> _addMedicineAlarm(
    DateTime scheduledTime,
    BuildContext context,
  ) async {
    final alarmSettings = AlarmSettings(
      id: _alarmId(),
      dateTime: scheduledTime,
      assetAudioPath: alarmSound,
      loopAudio: true,
      vibrate: true,
      volumeSettings: VolumeSettings.fade(
        volume: 0.8,
        fadeDuration: Duration(seconds: 5),
        volumeEnforced: true,
      ),
      androidFullScreenIntent: true,
      warningNotificationOnKill: Platform.isIOS,
      notificationSettings:
          enableNotifications.value
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
                body: 'Take your medicine',
                stopButton: 'Stop',
                icon: 'alarm',
                iconColor: AppColors.primaryColor,
              ),
    );

    if (kDebugMode) {
      print('🔔 Setting alarm:');
      print('   ID: ${alarmSettings.id}');
      print('   Time: $scheduledTime');
      print('   Category: Medicine');
      print('   Title: ${titleController.text}');
    }

    final success = await Alarm.set(alarmSettings: alarmSettings);

    if (success) {
      // FIX: Use titleController instead of medicineController
      medicineList.add({titleController.text.trim(): alarmSettings});

      // Save medicine names explicitly as metadata instead of parsing notification body
      medicineMeta.add({'medicines': List<String>.from(medicineNames)});
      print(medicineMeta.last);
      await _saveMetaList(medicineMeta, 'medicine_list_meta');

      titleController.clear();
      notesController.clear();
      medicineController.clear();
      medicineNames.clear();

      await saveReminderList(medicineList, "medicine_list");

      // Reload the combined list
      await loadAllReminderLists();

      CustomSnackbar.showSuccess(
        context: context,
        message: 'Success',
        title: 'Medicine reminder set successfully!',
      );
      CustomSnackbar().showReminderBar(context);

      Get.back(result: true);

      final allAlarms = await Alarm.getAlarms();
      if (kDebugMode) print('   Total alarms active: ${allAlarms.length}');
    }
  }

  Future<void> _addMealAlarm(
    DateTime scheduledTime,
    BuildContext context,
  ) async {
    final alarmSettings = AlarmSettings(
      id: _alarmId(),
      dateTime: scheduledTime,
      assetAudioPath: alarmSound,
      loopAudio: true,
      androidFullScreenIntent: true,
      warningNotificationOnKill: Platform.isIOS,
      vibrate: soundVibrationToggle.value,
      volumeSettings: VolumeSettings.fade(
        volume: 0.8,
        fadeDuration: Duration(seconds: 5),
        volumeEnforced: true,
      ),
      notificationSettings:
          enableNotifications.value
              ? NotificationSettings(
                title: titleController.text,
                body:
                    notesController.text.isNotEmpty
                        ? notesController.text
                        : 'Meal reminder',
                stopButton: 'Stop',
                icon: 'alarm',
                iconColor: AppColors.primaryColor,
              )
              : NotificationSettings(
                title: 'REMINDER',
                body: 'Meal reminder',
                stopButton: 'Stop',
                icon: 'alarm',
              ),
    );

    final success = await Alarm.set(alarmSettings: alarmSettings);
    if (success) {
      mealsList.add({titleController.text.trim(): alarmSettings});
      await saveReminderList(mealsList, "meals_list");

      // reload combined list
      await loadAllReminderLists();

      CustomSnackbar.showSuccess(
        context: context,
        title: 'Success',
        message: 'Meal reminder set successfully!',
      );
      CustomSnackbar().showReminderBar(context);
      Get.back(result: true);
    }
  }

  Future<void> _addEventAlarm(
    DateTime scheduledTime,
    BuildContext context,
  ) async {
    final alarmSettings = AlarmSettings(
      id: _alarmId(),
      dateTime: scheduledTime,
      assetAudioPath: alarmSound,
      loopAudio: true,
      vibrate: soundVibrationToggle.value,
      volumeSettings: VolumeSettings.fade(
        volume: 0.8,
        fadeDuration: Duration(seconds: 5),
        volumeEnforced: true,
      ),
      androidFullScreenIntent: true,
      warningNotificationOnKill: Platform.isIOS,
      notificationSettings:
          enableNotifications.value
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

    final success = await Alarm.set(alarmSettings: alarmSettings);
    if (success) {
      eventList.add({titleController.text.trim(): alarmSettings});

      // Save event meta (before reminder amount if present)
      int beforeAmount = int.tryParse(beforeReminderController.text) ?? 0;
      eventMeta.add({
        'before_amount': beforeAmount,
        'before_unit': selectedValue.value,
      });
      await _saveMetaList(eventMeta, 'event_list_meta');

      titleController.clear();
      notesController.clear();
      await saveReminderList(eventList, "event_list");

      // Reload the combined list
      await loadAllReminderLists();

      CustomSnackbar.showSuccess(
        context: context,
        title: 'Success',
        message: 'Event reminder set successfully!',
      );
      CustomSnackbar().showReminderBar(context);
      Get.back(result: true);
    }
  }

  Future<void> setWaterAlarm({
    required int? interval,
    required int? times,
    required BuildContext context,
  }) async {
    bool alarmSet = false;

    if ((times == null || times <= 0) && (interval == null || interval <= 0)) {
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Please enter a valid reminder interval',
      );
      return;
    }

    // Save the scheduling choice so the listener can reschedule correctly
    savedInterval.value = (interval ?? 0);
    savedTimes.value = (times ?? 0);

    if (times != null && times > 0) {
      int totalMinutes = (24 * 60) ~/ times;
      int hours = totalMinutes ~/ 60;
      int minutes = totalMinutes % 60;

      var scheduledTime = DateTime.now().add(
        Duration(hours: hours, minutes: minutes),
      );

      if (kDebugMode) print('💧 Setting water alarm for $times times/day');
      if (kDebugMode) print('   Next alarm at: $scheduledTime');

      final alarmSettings = AlarmSettings(
        id: _alarmId(),
        dateTime: scheduledTime,
        assetAudioPath: alarmSound,
        loopAudio: true,
        vibrate: soundVibrationToggle.value,
        volumeSettings: VolumeSettings.fade(
          volume: 0.8,
          fadeDuration: Duration(seconds: 5),
          volumeEnforced: true,
        ),
        androidFullScreenIntent: true,
        warningNotificationOnKill: Platform.isIOS,
        notificationSettings:
            enableNotifications.value
                ? NotificationSettings(
                  title: titleController.text,
                  body: notesController.text,
                  stopButton: 'Stop',
                  icon: 'alarm',
                  iconColor: AppColors.primaryColor,
                )
                : NotificationSettings(
                  title: '',
                  body: 'Drink Water!',
                  stopButton: 'Stop',
                  icon: 'alarm',
                ),
      );

      final success = await Alarm.set(alarmSettings: alarmSettings);
      if (success) {
        waterList.add({titleController.text.toString(): alarmSettings});

        // Save meta for water frequency so it can be shown/edited later
        waterMeta.add({'interval_hours': interval, 'times_per_day': times});
        await _saveMetaList(waterMeta, 'water_list_meta');

        titleController.clear();
        notesController.clear();
        await saveReminderList(waterList, "water_list");
      }
      if (kDebugMode) print('   Set result: ${success ? "✅" : "❌"}');
      alarmSet = alarmSet || success;
    }

    if (interval != null && interval > 0) {
      var scheduledTime = DateTime.now().add(Duration(hours: interval));

      if (kDebugMode) print('💧 Setting water alarm every $interval hours');
      if (kDebugMode) print('   Next alarm at: $scheduledTime');

      final alarmSettings = AlarmSettings(
        id: _alarmId(),
        dateTime: scheduledTime,
        assetAudioPath: alarmSound,
        loopAudio: true,
        vibrate: soundVibrationToggle.value,
        volumeSettings: VolumeSettings.fade(
          volume: 0.8,
          fadeDuration: Duration(seconds: 5),
          volumeEnforced: true,
        ),
        androidFullScreenIntent: true,
        warningNotificationOnKill: Platform.isIOS,
        notificationSettings:
            enableNotifications.value
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
      if (success) {
        waterList.add({titleController.text.toString(): alarmSettings});

        // Save meta for water frequency
        waterMeta.add({'interval_hours': interval, 'times_per_day': times});
        await _saveMetaList(waterMeta, 'water_list_meta');

        titleController.clear();
        notesController.clear();
        await saveReminderList(waterList, "water_list");
      }
      if (kDebugMode) print('   Set result: ${success ? "✅" : "❌"}');
      alarmSet = alarmSet || success;
    }

    await loadAlarms();

    final allAlarms = await Alarm.getAlarms();
    if (kDebugMode) print('💧 Total alarms active: ${allAlarms.length}');

    if (alarmSet) {
      // Reload the combined list before showing success message
      await loadAllReminderLists();

      CustomSnackbar.showSuccess(
        context: context,
        title: 'Success',
        message: 'Water reminder set successfully!',
      );
      CustomSnackbar().showReminderBar(context);
      Get.back(result: true);
    }
  }

  Future<void> scheduleAlarmEveryXHours(int intervalHours) async {
    final nextTime = DateTime.now().add(Duration(hours: intervalHours));

    final newAlarm = AlarmSettings(
      id: _alarmId(),
      dateTime: nextTime,
      assetAudioPath: alarmSound,
      loopAudio: true,
      vibrate: soundVibrationToggle.value,
      volumeSettings: VolumeSettings.fade(
        volume: 0.8,
        fadeDuration: Duration(seconds: 5),
        volumeEnforced: true,
      ),
      androidFullScreenIntent: true,
      warningNotificationOnKill: Platform.isIOS,
      notificationSettings:
          enableNotifications.value
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

    // Also persist this alarm to the waterList so user can see it in UI
    waterList.add({'AutoWater_${newAlarm.id}': newAlarm});
    waterMeta.add({'interval_hours': intervalHours, 'times_per_day': null});
    await saveReminderList(waterList, 'water_list');
    await _saveMetaList(waterMeta, 'water_list_meta');
  }

  Future<void> stopAlarm(
    int index,
    AlarmSettings alarm,
    RxList<Map<String, AlarmSettings>> reminderList,
  ) async {
    await Alarm.stop(alarm.id);
    reminderList.removeAt(index);
  }

  Future<void> deleteReminder(Map<String, dynamic> reminder) async {
    final id = reminder['id'];
    final category = reminder['Category'];

    if (id == null) {
      return;
    }

    switch (category) {
      case 'Medicine':
        await _deleteFromListById(
          medicineList,
          id,
          "medicine_list",
          medicineMeta,
          'medicine_list_meta',
        );
        break;
      case 'Meal':
        await _deleteFromListById(
          mealsList,
          id,
          "meals_list",
          mealsMeta,
          'meals_list_meta',
        );
        break;
      case 'Event':
        await _deleteFromListById(
          eventList,
          id,
          "event_list",
          eventMeta,
          'event_list_meta',
        );
        break;
      case 'Water':
        await _deleteFromListById(
          waterList,
          id,
          "water_list",
          waterMeta,
          'water_list_meta',
        );
        break;
    }
    await loadAllReminderLists();
  }

  Future<void> _deleteFromListById(
    RxList<Map<String, AlarmSettings>> list,
    int id,
    String keyName,
    RxList<Map<String, dynamic>> metaList,
    String metaKeyName,
  ) async {
    int index = -1;
    for (int i = 0; i < list.length; i++) {
      if (list[i].values.first.id == id) {
        index = i;
        break;
      }
    }

    if (index != -1) {
      await Alarm.stop(id);
      list.removeAt(index);
      // also remove meta at same index if present
      if (index < metaList.length) metaList.removeAt(index);
      await saveReminderList(list, keyName);
      await _saveMetaList(metaList, metaKeyName);
    }
  }

  // ==================== Medicine Management ====================

  void addMedicine(String medicineName) {
    if (medicineController.text.isNotEmpty) {
      medicineNames.add(medicineName);
      // medicineController.clear();
    }
  }

  void removeMedicine(int index) {
    medicineNames.removeAt(index);
  }

  // ==================== Time Management ====================

  void addReminderTime() {
    if (timeController.text.isNotEmpty) {
      remindTimes.add(timeController.text);
      timeController.clear();
    }
  }

  void removeReminderTime(int index) {
    remindTimes.removeAt(index);
  }

  // ==================== SharedPreferences Methods ====================

  Future<List<Map<String, AlarmSettings>>> loadReminderList(
    String keyName,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final storedList = prefs.getStringList(keyName);

    if (storedList == null) return [];

    return storedList.map((item) {
      final Map<String, dynamic> decoded = jsonDecode(item);
      final mapped = decoded.map((key, value) {
        return MapEntry(key, AlarmSettings.fromJson(value));
      });
      return mapped;
    }).toList();
  }

  Future<void> saveReminderList(
    RxList<Map<String, AlarmSettings>> list,
    String keyName,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    List<String> stringList =
        list.map((mapItem) {
          final jsonMap = mapItem.map((key, value) {
            return MapEntry(key, value.toJson());
          });
          return jsonEncode(jsonMap);
        }).toList();

    await prefs.setStringList(keyName, stringList);
  }

  Future<List<Map<String, dynamic>>> _loadMetaList(String keyName) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(keyName);
    if (stored == null) return [];
    return stored.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
  }

  Future<void> _saveMetaList(
    RxList<Map<String, dynamic>> list,
    String keyName,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final enc = list.map((m) => jsonEncode(m)).toList();
    await prefs.setStringList(keyName, enc);
  }

  Future<void> loadAllReminderLists() async {
    try {
      isLoading(true);

      medicineList.value = await loadReminderList("medicine_list");
      mealsList.value = await loadReminderList("meals_list");
      eventList.value = await loadReminderList("event_list");
      waterList.value = await loadReminderList("water_list");

      // load metas (if any)
      medicineMeta.value =
          (await _loadMetaList(
            'medicine_list_meta',
          )).cast<Map<String, dynamic>>();
      eventMeta.value =
          (await _loadMetaList('event_list_meta')).cast<Map<String, dynamic>>();
      waterMeta.value =
          (await _loadMetaList('water_list_meta')).cast<Map<String, dynamic>>();
      mealsMeta.value =
          (await _loadMetaList('meals_list_meta')).cast<Map<String, dynamic>>();

      List<Map<String, dynamic>> combined = [];

      for (int i = 0; i < medicineList.length; i++) {
        final item = medicineList[i];
        item.forEach((title, alarm) {
          combined.add({
            "Category": "Medicine",
            "Title": title,
            // Use explicit meta if present, else try to parse body (fallback)
            "MedicineName":
                (i < medicineMeta.length &&
                        medicineMeta[i]['medicines'] != null)
                    ? List<String>.from(medicineMeta[i]['medicines'])
                    : (alarm.notificationSettings.body?.split(',') ?? []),
            "RemindTime": [alarm.dateTime.toString()],
            "Description": alarm.notificationSettings.body ?? "",
            "id": alarm.id,
          });
        });
      }

      for (int i = 0; i < mealsList.length; i++) {
        final item = mealsList[i];
        item.forEach((title, alarm) {
          combined.add({
            "Category": "Meal",
            "Title": title,
            "RemindTime": [alarm.dateTime.toString()],
            "id": alarm.id,
          });
        });
      }

      for (int i = 0; i < eventList.length; i++) {
        final item = eventList[i];
        item.forEach((title, alarm) {
          combined.add({
            "Category": "Event",
            "Title": title,
            "StartDay": alarm.dateTime.day,
            "StartMonth": alarm.dateTime.month,
            "StartYear": alarm.dateTime.year,
            "RemindTime": [alarm.dateTime.toString()],
            "Description": alarm.notificationSettings.body ?? "",
            "id": alarm.id,
            // include meta if available
            "BeforeMeta": i < eventMeta.length ? eventMeta[i] : {},
          });
        });
      }

      for (int i = 0; i < waterList.length; i++) {
        final item = waterList[i];
        item.forEach((title, alarm) {
          combined.add({
            "Category": "Water",
            "Title": title,
            // Use stored meta to show frequency instead of alarm's date/time values
            "RemindFrequencyHour":
                (i < waterMeta.length) ? waterMeta[i]['interval_hours'] : null,
            "RemindFrequencyCount":
                (i < waterMeta.length) ? waterMeta[i]['times_per_day'] : null,
            "id": alarm.id,
          });
        });
      }

      reminders.value = combined;
    } catch (e) {
      print('Error loading reminder lists: $e');
    } finally {
      isLoading(false);
    }
  }

  // ==================== API Methods ====================

  Future<void> getReminders(BuildContext context) async {
    try {
      isLoading(true);
      var result = await getReminderFromAPI(context);
      final List<Map<String ,dynamic>> reminders = (result as List).map((e) => Map<String , dynamic>.from(e)).toList();
      this.reminders.assignAll(reminders);
      if (kDebugMode) print(reminders);
    } catch (e) {
      if (kDebugMode) print("Error fetching reminders: $e");
    } finally {
      isLoading(false);
    }
  }

  Future<dynamic> getReminderFromAPI(BuildContext context) async {
    try {
      final response = await ApiService.post(
        getreminderApi,
        null,
        withAuth: true,
        encryptionRequired: false,
      );

      if (response is http.Response && response.statusCode >= 400) {
        print('Error Failed to get reminder: ${response.statusCode}');
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Failed to fetch reminders: Api calling failed',
        );
        return [];
      }

      final enc = jsonEncode(response);
      final decbody = jsonDecode(enc);
      final List remindersList = decbody['data']['Reminders'] as List;
      return remindersList.map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Exception while fetching reminders',
      );
      return [];
    }
  }

  Future<void> addReminder(
    Map<String, dynamic> reminderData,
    BuildContext context,
  ) async {
    try {
      final response = await ApiService.post(
        addreminderApi,
        reminderData,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response && response.statusCode >= 400) {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Failed to save Reminder record: ${response.statusCode}',
        );
      } else {
        getReminders(context);
      }
    } catch (e) {
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Exception while saving Reminder record',
      );
    }
  }

  Future<void> updateReminder(
    Map<String, dynamic> reminderData,
    BuildContext context,
  ) async {
    try {
      final response = await ApiService.post(
        editreminderApi,
        reminderData,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response && response.statusCode >= 400) {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Failed to update Reminder record: ${response.statusCode}',
        );
      } else {
        getReminders(context);
      }
    } catch (e) {
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Exception while updating Reminder record',
      );
    }
  }

  // ==================== Validation & Save Methods ====================

  bool validateAndSave(BuildContext context) {
    if (selectedCategory.value == "Medicine") {
      if (pickedTime.value == null) {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Please select a reminder time',
        );
        return false;
      }
      if (medicineController.text.isEmpty) {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Please enter medicine name',
        );
        return false;
      }

      // addMedicine(medicineController.text.trim());
      addAlarm(context, timeOfDay: pickedTime.value!, category: "Medicine");
      medicineController.clear();
      timeController.clear();
      titleController.clear();
      notesController.clear();
      return true;
    } else if (selectedCategory.value == "Water") {
      if (waterReminderOption.value == 0 &&
          savedInterval.value <= 0 &&
          (int.tryParse(everyHourController.text) ?? 0) <= 0) {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Please enter hours interval',
        );
        return false;
      }
      if (waterReminderOption.value == 1 &&
          savedTimes.value <= 0 &&
          (int.tryParse(timesPerDayController.text) ?? 0) <= 0) {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Please enter times per day',
        );
        return false;
      }
      if (timeController.text.isEmpty) {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Please select time',
        );
        return false;
      }

      // prefer controller values if not already saved
      final interval =
          savedInterval.value > 0
              ? savedInterval.value
              : int.tryParse(everyHourController.text);
      final times =
          savedTimes.value > 0
              ? savedTimes.value
              : int.tryParse(timesPerDayController.text);

      setWaterAlarm(
        context: context,
        interval: waterReminderOption.value == 0 ? interval : null,
        times: waterReminderOption.value == 1 ? times : null,
      );
      return true;
    } else if (selectedCategory.value == "Meal") {
      if (pickedTime.value == null) {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Please select a meal time',
        );
        return false;
      }
      addAlarm(context, timeOfDay: pickedTime.value!, category: "Meal");
      return true;
    } else if (selectedCategory.value == "Event") {
      if (pickedTime.value == null) {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Please select an event time',
        );
        return false;
      }
      addAlarm(context, timeOfDay: pickedTime.value!, category: "Event");
      return true;
    }
    return false;
  }

  // ==================== Refresh Methods ====================

  Future<void> refreshAllData(BuildContext context) async {
    await Future.wait([loadAllReminderLists(), getReminders(context)]);
  }

  // ==================== Helper Methods ====================

  String getCategoryIcon(String category) {
    switch (category) {
      case 'Medicine':
        return medicineIcon;
      case 'Water':
        return waterReminderIcon;
      case 'Meal':
        return mealIcon;
      case 'Event':
        return eventIcon;
      default:
        return "";
    }
  }

  Color getCategoryColor(String category) {
    return AppColors.primaryColor;
  }

  void resetForm() {
    titleController.clear();
    medicineController.clear();
    timeController.clear();
    notesController.clear();
    beforeReminderController.clear();
    everyHourController.clear();
    timesPerDayController.clear();
    selectedCategory.value = 'Medicine';
    startDate.value = DateTime.now();
    endDate.value = null;
    pickedTime.value = null;
    waterReminderOption.value = 1;
    savedInterval.value = 0;
    savedTimes.value = 0;
    enableNotifications.value = false;
    soundVibrationToggle.value = true;
    medicineNames.clear();
    remindTimes.clear();
  }

  void loadReminderData(Map<String, dynamic> reminder) {
    titleController.text = reminder['Title'] ?? '';
    notesController.text = reminder['Description'] ?? '';
    selectedCategory.value = reminder['Category'] ?? 'Medicine';

    if (selectedCategory.value == 'Medicine') {
      medicineNames.value = List<String>.from(reminder['MedicineName'] ?? []);
    }
    remindTimes.value = List<String>.from(reminder['RemindTime'] ?? []);

    if (reminder['StartDay'] != null &&
        reminder['StartMonth'] != null &&
        reminder['StartYear'] != null) {
      startDate.value = DateTime(
        reminder['StartYear'],
        reminder['StartMonth'],
        reminder['StartDay'],
      );
    }

    everyHourController.text =
        reminder['RemindFrequencyHour']?.toString() ?? '';
    timesPerDayController.text =
        reminder['RemindFrequencyCount']?.toString() ?? '';
    enableNotifications.value = reminder['EnablePushNotification'] ?? false;

    // load before meta if present
    if (reminder['BeforeMeta'] != null) {
      beforeReminderController.text =
          reminder['BeforeMeta']['before_amount']?.toString() ?? '';
      selectedValue.value =
          reminder['BeforeMeta']['before_unit'] ?? selectedValue.value;
    }
  }

  String formatReminderTime(List remindTimes) {
    if (remindTimes.isEmpty) return 'N/A';

    // Parse and format each time
    List<String> formattedTimes = [];
    for (var time in remindTimes) {
      try {
        // Check if it's already a formatted string or a DateTime string
        if (time is String) {
          // Try to parse as DateTime first
          try {
            DateTime dateTime = DateTime.parse(time);
            formattedTimes.add(DateFormat('hh:mm a').format(dateTime));
          } catch (e) {
            // If it fails, it might already be formatted, just use it
            formattedTimes.add(time);
          }
        } else if (time is DateTime) {
          formattedTimes.add(DateFormat('hh:mm a').format(time));
        }
      } catch (e) {
        if (kDebugMode) print('Error formatting time: $e');
        formattedTimes.add(time.toString());
      }
    }

    return formattedTimes.join(', ');
  }

  String formatDate(int? day, int? month, int? year) {
    if (day == null || month == null || year == null) return 'N/A';
    return '$day/$month/$year';
  }

  double getListHeight(int itemCount) {
    return (itemCount * itemHeight).clamp(0, maxHeight);
  }

  // String formatTimeFromHourMinute(int hour, int minute) {
  //   try {
  //     final now = DateTime.now();
  //     final dateTime = DateTime(now.year, now.month, now.day, hour, minute);
  //     return DateFormat('hh:mm a').format(dateTime);
  //   } catch (e) {
  //     return '$hour:$minute';
  //   }
  // }

  TimeOfDay _parseTime(String timeString) {
    final format = DateFormat("hh:mm a");
    return TimeOfDay.fromDateTime(format.parse(timeString));
  }
}
