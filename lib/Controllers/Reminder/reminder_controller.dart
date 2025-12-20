import 'dart:async';
import 'dart:convert';

import 'package:alarm/alarm.dart';
import 'package:alarm/model/alarm_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:snevva/common/custom_snackbar.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/env/env.dart';
import 'package:snevva/services/api_service.dart';

import '../../models/medicine_reminder_model.dart';
import '../../models/water_reminder_model.dart';

class ReminderController extends GetxController {
  // ==================== Controllers ====================
  final titleController = TextEditingController();
  final medicineController = TextEditingController();
  final timeController = TextEditingController();
  final startWaterTimeController = TextEditingController();
  final endWaterTimeController = TextEditingController();

  final notesController = TextEditingController();
  final everyHourController = TextEditingController();
  final timesPerDayController = TextEditingController();
  Rxn<dynamic> editingId = Rxn<dynamic>(); // Stores key/ID when editing

  // ==================== Observable Variables ====================
  var reminders = <Map<String, dynamic>>[].obs;
  var alarms = <AlarmSettings>[].obs;
  var isLoading = false.obs;
  final selectedValue = 'minutes'.obs;

  var medicineList = <MedicineReminderModel>[].obs;

  var eventList = <Map<String, AlarmSettings>>[].obs;
  var waterList = <WaterReminderModel>[].obs;

  var mealsList = <Map<String, AlarmSettings>>[].obs;
  var selectedDateIndex = 0.obs;

  var medicineNames = <String>[].obs;
  var remindTimes = <String>[].obs;

  // ==================== State Variables ====================
  var selectedCategory = 'Medicine'.obs;
  var enableNotifications = false.obs;
  var soundVibrationToggle = true.obs;
  var waterReminderOption = 1.obs;
  var eventReminderOption = 0.obs;

  var savedTimes = 0.obs;

  Rx<DateTime?> startDate = Rx<DateTime?>(null);
  Rx<DateTime?> endDate = Rx<DateTime?>(null);
  Rx<TimeOfDay?> pickedTime = Rx<TimeOfDay?>(null);

  // ==================== Stream Subscription ====================
  static StreamSubscription<AlarmSettings>? subscription;
  bool listenerAttached = false;

  // ==================== Constants ====================
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
    loadAllReminderLists();
    initAlarmListener();
  }

  @override
  void onClose() {
    subscription?.cancel();
    titleController.dispose();
    medicineController.dispose();
    timeController.dispose();
    notesController.dispose();
    everyHourController.dispose();
    timesPerDayController.dispose();
    super.onClose();
  }

  // ==================== Permission Methods ====================

  Future<void> checkAndroidNotificationPermission() async {
    final status = await Permission.notification.status;
    if (status.isDenied) {
      print('Requesting notification permission...');
      final res = await Permission.notification.request();
      print('Notification permission ${res.isGranted ? '' : 'not '}granted');
    }
    if (status.isGranted) {
      enableNotifications.value = true;
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
      print("🔔 ALARM RANG → ID: ${alarmSettings.id}");

      // await Alarm.stop(alarmSettings.id); // FIX: Let it ring until user stops it

      // if (savedInterval.value > 0) {
      //   print(
      //     "🔄 Rescheduling water alarm (every ${savedInterval.value} hours)",
      //   );
      //   await scheduleAlarmEveryXHours(savedInterval.value);
      // } else
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
          id: _alarmId(),
          dateTime: nextTime,
          assetAudioPath: alarmSound,
          loopAudio: false,
          vibrate: soundVibrationToggle.value,
          volumeSettings: VolumeSettings.fade(
            volume: 0.8,
            fadeDuration: const Duration(seconds: 5),
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
    });
  }

  // ==================== Alarm Management ====================

  Future<void> loadAlarms() async {
    final loadedAlarms = await Alarm.getAlarms();
    loadedAlarms.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    alarms.value = loadedAlarms;
  }

  int _alarmId() {
    return DateTime.now().millisecondsSinceEpoch % 2147483647;
  }

  Future<void> setBeforeReminderAlarm(DateTime mainTime) async {
    int amount = int.tryParse(timesPerDayController.text) ?? 0;
    String unit = selectedValue.value; // "minutes" or "hours"

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
      notificationSettings: NotificationSettings(
        title: "Reminder before your event",
        body: "Your event is coming in $amount $unit",
        stopButton: "Stop",
        icon: "alarm",
      ),
      volumeSettings: VolumeSettings.fade(fadeDuration: Duration(seconds: 2)),
    );

    await Alarm.set(alarmSettings: alarmSettings);
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

    int value = int.tryParse(timesPerDayController.text) ?? 0;

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
      print('⚠️ Time was in past/now, moved to tomorrow: $scheduledTime');
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
    if (category == 'Event' && eventReminderOption.value == 0) {
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

    print('🔔 Setting alarm:');
    print('   ID: ${alarmSettings.id}');
    print('   Time: $scheduledTime');
    print('   Category: Medicine');
    print('   Title: ${titleController.text}');

    final success = await Alarm.set(alarmSettings: alarmSettings);

    if (success) {
      // Reload list from Hive to ensure we have the latest data and don't override
      medicineList.value = await loadMedicineReminderList("medicine_list");

      medicineList.add(
        MedicineReminderModel(
          title: titleController.text.trim(),
          medicines: List<String>.from(medicineNames),
          alarm: alarmSettings,
        ),
      );
      titleController.clear();
      notesController.clear();
      medicineController.clear();
      medicineNames.clear(); // FIX: Clear medicine names after saving
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
      print('   Total alarms active: ${allAlarms.length}');
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
                body: notesController.text,
                stopButton: 'Stop',
                icon: 'alarm',
                iconColor: AppColors.primaryColor,
              )
              : NotificationSettings(
                title: 'REMINDER',
                body:
                    'Take your meal', // FIX: Changed from "medicine" to "meal"
                stopButton: 'Stop',
                icon: 'alarm',
              ),
    );

    final success = await Alarm.set(alarmSettings: alarmSettings);
    if (success) {
      // Reload list from Hive to ensure we have the latest data and don't override
      mealsList.value = await loadReminderList("meals_list");

      mealsList.add({titleController.text.trim(): alarmSettings});
      titleController.clear();
      notesController.clear();
      await saveReminderList(mealsList, "meals_list");

      // Reload the combined list
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
      // Reload list from Hive to ensure we have the latest data and don't override
      eventList.value = await loadReminderList("event_list");

      eventList.add({titleController.text.trim(): alarmSettings});
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
      Get.back(result: true);
    }
  }

  Future<void> setWaterAlarm({
    required int? times,
    required BuildContext context,
  }) async {
    print('🚰 setWaterAlarm called → times=$times');

    if (times == null || times <= 0) {
      print('❌ Invalid times value');
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Please enter a valid number of times per day',
      );
      return;
    }

    print(
      '🕒 Generating alarm times between '
      '${startWaterTimeController.text} → ${endWaterTimeController.text}',
    );

    final alarmTimes = generateTimesBetween(
      startTime: startWaterTimeController.text,
      endTime: endWaterTimeController.text,
      times: times,
    );

    print('📅 Generated ${alarmTimes.length} alarm times');
    alarmTimes.forEach((t) => print('   ⏰ $t'));

    print('📅 Generated ${alarmTimes.length} alarm times');
    alarmTimes.forEach((t) => print('   ⏰ $t'));

    print('🧹 Cleared existing waterList - SKIPPED');

    List<AlarmSettings> createdAlarms = [];

    for (var i = 0; i < alarmTimes.length; i++) {
      final time = alarmTimes[i];
      final scheduledTime =
          time.isBefore(DateTime.now()) ? time.add(Duration(days: 1)) : time;

      final alarmId = _alarmId();
      print('🔔 Creating alarm [$i] → id=$alarmId, time=$scheduledTime');

      final alarmSettings = AlarmSettings(
        id: alarmId,
        dateTime: scheduledTime,
        assetAudioPath: alarmSound,
        loopAudio: false,
        vibrate: soundVibrationToggle.value,
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

      await Alarm.set(alarmSettings: alarmSettings);
      createdAlarms.add(alarmSettings);

      print('   ✅ Alarm set successfully');
    }

    final waterReminderId = DateTime.now().millisecondsSinceEpoch.toString();
    print('🆔 Generated water reminder group ID: $waterReminderId');

    final model = WaterReminderModel(
      id: waterReminderId,
      title:
          titleController.text.isNotEmpty
              ? titleController.text
              : 'Water Reminder',
      alarms: createdAlarms,
      timesPerDay: times.toString(),
      category: "Water",
    );

    // Reload list from Hive to ensure we have the latest data and don't override
    waterList.value = await loadWaterReminderList("water_list");

    waterList.add(model);

    print(
      '📦 WaterReminderModel saved → '
      'id=${model.id}, '
      'alarms=${model.alarms.length}, '
      'timesPerDay=${model.timesPerDay}',
    );

    savedTimes.value = times;
    print('💾 savedTimes updated → $times');

    await saveReminderList(waterList, "water_list");
    print('💾 Water reminders saved to Hive');

    await loadAllReminderLists();
    print('🔄 Reloaded all reminder lists');

    CustomSnackbar.showSuccess(
      context: context,
      title: 'Success',
      message: 'Water reminders set successfully! ($times times per day)',
    );

    CustomSnackbar().showReminderBar(context);
    Get.back(result: true);
  }

  Future<void> updateReminderFromLocal(
    BuildContext context, {
    required String id,
    required String category,
    TimeOfDay? timeOfDay,
    int? times,
  }) async {
    print("🚀 updateReminderFromLocal called");
    print("➡️ id: $id (${id.runtimeType})");
    print("➡️ category: $category");
    print("➡️ timeOfDay: $timeOfDay");
    print("➡️ times: $times (${times.runtimeType})");

    final now = DateTime.now();
    var scheduledTime = DateTime(
      startDate.value?.year ?? now.year,
      startDate.value?.month ?? now.month,
      startDate.value?.day ?? now.day,
      timeOfDay == TimeOfDay.now() ? timeOfDay!.hour : now.hour,
      timeOfDay == TimeOfDay.now() ? timeOfDay!.minute : now.minute,
    );

    print("🕒 initial scheduledTime → $scheduledTime");

    if (scheduledTime.isBefore(now) || scheduledTime.isAtSameMomentAs(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
      print("⏭️ time was past → moved to $scheduledTime");
    }

    // 🚰 WATER
    if (category == 'Water') {
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
        await saveReminderList(waterList, "water_list");
        print("🗑️ old water reminder removed");
      }

      print("➕ creating new water alarms with times=$times");
      await setWaterAlarm(times: times, context: context);
    }
    // 💊🍽️📅 SINGLE ALARMS
    else {
      print("🔁 Updating single alarm → $category with id=$id");

      switch (category) {
        case 'Medicine':
          await _updateMedicineAlarm(scheduledTime, context, int.parse(id));
          break;
        case 'Meal':
          await _updateMealAlarm(scheduledTime, context, int.parse(id));
          break;
        case 'Event':
          await _updateEventAlarm(scheduledTime, context, int.parse(id));
          break;
        default:
          print("⚠️ Unknown category: $category");
      }
    }

    print("✅ updateReminderFromLocal completed");
  }

  Future<void> _updateMedicineAlarm(
    DateTime scheduledTime,
    BuildContext context,
    int alarmId,
  ) async {
    // 1. Re-set the alarm with the SAME ID
    final alarmSettings = AlarmSettings(
      id: alarmId, // <--- Key change: Reuse ID
      dateTime: scheduledTime,
      assetAudioPath: alarmSound,
      loopAudio: true,
      vibrate: true,
      volumeSettings: VolumeSettings.fade(
        volume: 0.8,
        fadeDuration: const Duration(seconds: 5),
        volumeEnforced: true,
      ),
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

    await Alarm.set(alarmSettings: alarmSettings);

    // 2. Update the List in Hive
    medicineList.value = await loadMedicineReminderList("medicine_list");

    // Create updated model
    final newModel = MedicineReminderModel(
      title: titleController.text.trim(),
      medicines: List<String>.from(medicineNames),
      alarm: alarmSettings,
    );

    // Find index and replace
    final index = medicineList.indexWhere((e) => e.alarm.id == alarmId);
    if (index != -1) {
      medicineList[index] = newModel;
    } else {
      medicineList.add(newModel); // Fallback if not found
    }

    // 3. Save and Refresh
    await _finalizeUpdate(context, "medicine_list", medicineList);
  }

  Future<void> _updateMealAlarm(
    DateTime scheduledTime,
    BuildContext context,
    int alarmId,
  ) async {
    // Use same AlarmSettings logic as _addMealAlarm but with alarmId
    final alarmSettings = AlarmSettings(
      id: alarmId,
      dateTime: scheduledTime,
      assetAudioPath: alarmSound,
      loopAudio: true,
      vibrate: soundVibrationToggle.value,
      volumeSettings: VolumeSettings.fade(
        volume: 0.8,
        fadeDuration: const Duration(seconds: 5),
        volumeEnforced: true,
      ),
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
                body: 'Take your meal',
                stopButton: 'Stop',
                icon: 'alarm',
                iconColor: AppColors.primaryColor,
              ),
    );

    await Alarm.set(alarmSettings: alarmSettings);

    // Find and replace in List
    mealsList.value = await loadReminderList("meals_list");
    int index = -1;
    for (int i = 0; i < mealsList.length; i++) {
      if (mealsList[i].values.first.id == alarmId) {
        index = i;
        break;
      }
    }

    final newItem = {titleController.text.trim(): alarmSettings};
    if (index != -1) {
      mealsList[index] = newItem;
    } else {
      mealsList.add(newItem);
    }

    await _finalizeUpdate(context, "meals_list", mealsList);
  }

  Future<void> _updateEventAlarm(
    DateTime scheduledTime,
    BuildContext context,
    int alarmId,
  ) async {
    // Use same AlarmSettings logic as _addEventAlarm but with alarmId
    final alarmSettings = AlarmSettings(
      id: alarmId,
      dateTime: scheduledTime,
      assetAudioPath: alarmSound,
      loopAudio: true,
      vibrate: soundVibrationToggle.value,
      volumeSettings: VolumeSettings.fade(
        volume: 0.8,
        fadeDuration: const Duration(seconds: 5),
        volumeEnforced: true,
      ),
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
                iconColor: AppColors.primaryColor,
              ),
    );

    await Alarm.set(alarmSettings: alarmSettings);

    eventList.value = await loadReminderList("event_list");
    int index = -1;
    for (int i = 0; i < eventList.length; i++) {
      if (eventList[i].values.first.id == alarmId) {
        index = i;
        break;
      }
    }

    final newItem = {titleController.text.trim(): alarmSettings};
    if (index != -1) {
      eventList[index] = newItem;
    } else {
      eventList.add(newItem);
    }

    await _finalizeUpdate(context, "event_list", eventList);
  }

  Future<void> _finalizeUpdate(
    BuildContext context,
    String key,
    dynamic list,
  ) async {
    titleController.clear();
    notesController.clear();
    medicineController.clear();
    medicineNames.clear();

    await saveReminderList(list, key);
    await loadAllReminderLists();

    CustomSnackbar.showSuccess(
      context: context,
      title: 'Success',
      message: 'Reminder updated successfully!',
    );
    Get.back(result: true);
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
                title: 'Water Reminder',
                // FIX: Added default title
                body: 'Time to drink water!',
                // FIX: Added default body
                stopButton: 'Stop',
                icon: 'alarm',
                iconColor: AppColors.primaryColor,
              ),
    );

    await Alarm.set(alarmSettings: newAlarm);
  }

  Future<void> stopAlarm(
    int index,
    AlarmSettings alarm,
    dynamic reminderList,
  ) async {
    await Alarm.stop(alarm.id);
    reminderList.removeAt(index);
    // FIX: Save list after removing
    String listKey = _getListKeyFromType(reminderList);
    if (listKey.isNotEmpty) {
      await saveReminderList(reminderList, listKey);
    }
  }

  // FIX: Helper method to determine list key
  String _getListKeyFromType(RxList<Map<String, AlarmSettings>> list) {
    if (identical(list, medicineList)) return "medicine_list";
    if (identical(list, mealsList)) return "meals_list";
    if (identical(list, eventList)) return "event_list";
    if (identical(list, waterList)) return "water_list";
    return "";
  }

  Future<void> deleteReminder(Map<String, dynamic> reminder) async {
    final id = reminder['id'];
    final category = reminder['Category'];

    if (id == null) {
      return;
    }

    switch (category) {
      case 'Medicine':
        await _deleteFromListById(medicineList, id, "medicine_list");
        break;
      case 'Meal':
        await _deleteFromListById(mealsList, id, "meals_list");
        break;
      case 'Event':
        await _deleteFromListById(eventList, id, "event_list");
        break;
      case 'Water':
        if (id is String) {
          await _deleteWaterReminder(id);
        }
        break;
    }
    await loadAllReminderLists();
  }

  Future<void> _deleteFromListById(
    RxList<dynamic> list,
    int id,
    String keyName,
  ) async {
    int index = -1;
    for (int i = 0; i < list.length; i++) {
      // FIX: Handle both Map and MedicineReminderModel types
      if (list[i] is Map<String, AlarmSettings>) {
        if ((list[i] as Map<String, AlarmSettings>).values.first.id == id) {
          index = i;
          break;
        }
      } else if (list[i] is MedicineReminderModel) {
        if ((list[i] as MedicineReminderModel).alarm.id == id) {
          index = i;
          break;
        }
      }
    }

    if (index != -1) {
      await Alarm.stop(id);
      list.removeAt(index);
      await saveReminderList(list, keyName);
    }
  }

  Future<void> _deleteWaterReminder(String id) async {
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
      await saveReminderList(waterList, "water_list");
    }
  }

  // ==================== Medicine Management ====================

  void addMedicine() {
    if (medicineController.text.isNotEmpty) {
      medicineNames.add(medicineController.text);
      //medicineController.clear();
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

  // ==================== Hive Methods ====================

  Future<List<Map<String, AlarmSettings>>> loadReminderList(
    String keyName,
  ) async {
    print('📦 loadReminderList() → key: $keyName');

    final box = Hive.box('reminders_box');
    final List<dynamic>? storedList = box.get(keyName);

    if (storedList == null) {
      print('⚠️ No data found for $keyName');
      return [];
    }

    print('📄 Raw list length [$keyName]: ${storedList.length}');

    final List<String> stringList = storedList.cast<String>();

    final result =
        stringList.map((item) {
          print('🔍 Decoding item: $item');

          final Map<String, dynamic> decoded = jsonDecode(item);
          final mapped = decoded.map((key, value) {
            print('   ➜ Alarm title: $key');
            return MapEntry(key, AlarmSettings.fromJson(value));
          });

          return mapped;
        }).toList();

    print('✅ Loaded ${result.length} alarms for $keyName');
    return result;
  }

  // FIX: Handle both Map and MedicineReminderModel types
  Future<void> saveReminderList(RxList<dynamic> list, String keyName) async {
    print('💾 Saving reminders → key: $keyName');
    print('📦 Total items to save: ${list.length}');

    final box = Hive.box('reminders_box');

    List<String> stringList =
        list.map((item) {
          if (item is Map<String, AlarmSettings>) {
            print('🗂 Saving Map<String, AlarmSettings>');
            final jsonMap = item.map((key, value) {
              print('   ➜ Alarm: $key | id=${value.id}');
              return MapEntry(key, value.toJson());
            });
            return jsonEncode(jsonMap);
          } else if (item is MedicineReminderModel) {
            print('💊 Saving MedicineReminderModel → ${item.title}');
            return jsonEncode(item.toJson());
          } else if (item is WaterReminderModel) {
            print(
              '💧 Saving WaterReminderModel → '
              'id=${item.id}, '
              'title=${item.title}, '
              'alarms=${item.alarms.length}, '
              'timesPerDay=${item.timesPerDay}',
            );
            return jsonEncode(item.toJson());
          }

          print('⚠️ Unknown item type: ${item.runtimeType}');
          return jsonEncode({});
        }).toList();

    await box.put(keyName, stringList);
    print('✅ Saved ${stringList.length} items to Hive → $keyName');
  }

  // New method to specifically load MedicineReminderModel list
  Future<List<MedicineReminderModel>> loadMedicineReminderList(
    String keyName,
  ) async {
    final box = Hive.box('reminders_box');
    final List<dynamic>? storedList = box.get(keyName);

    if (storedList == null) return [];

    final List<String> stringList = storedList.cast<String>();

    List<MedicineReminderModel> loadedList = [];
    for (var item in stringList) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(item);

        // Check if it's the new format (has 'medicines' key)
        if (decoded.containsKey('medicines')) {
          loadedList.add(MedicineReminderModel.fromJson(decoded));
        } else {
          // Fallback for old format: {title: alarm_settings}
          final entry = decoded.entries.first;
          loadedList.add(
            MedicineReminderModel(
              title: entry.key,
              medicines: [], // Old format didn't have medicines list
              alarm: AlarmSettings.fromJson(entry.value),
            ),
          );
        }
      } catch (e) {
        print("Error parsing medicine reminder: $e");
      }
    }
    return loadedList;
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
            'timesPerDay=${model.timesPerDay}',
          );
        } else {
          print('🟡 Old format detected, migrating…');

          final entry = decoded.entries.first;
          final fallbackModel = WaterReminderModel(
            title: entry.key,
            id: _alarmId().toString(),
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

  Future<void> loadAllReminderLists() async {
    try {
      print('🔄 loadAllReminderLists() START');
      isLoading(true);

      medicineList.value = await loadMedicineReminderList("medicine_list");
      print('💊 Medicine loaded: ${medicineList.length}');

      mealsList.value = await loadReminderList("meals_list");
      print('🍽 Meals loaded: ${mealsList.length}');

      eventList.value = await loadReminderList("event_list");
      print('📅 Events loaded: ${eventList.length}');

      waterList.value = await loadWaterReminderList("water_list");
      print('💧 Water loaded: ${waterList.length}');

      final List<Map<String, dynamic>> combined = [];

      print('🧩 Building combined reminder list');

      for (var item in medicineList) {
        print('➕ Add Medicine → ${item.title}');
        combined.add({
          "Category": "Medicine",
          "Title": item.title,
          "MedicineName": item.medicines,
          "RemindTime": [item.alarm.dateTime.toString()],
          "Description": item.alarm.notificationSettings.body ?? "",
          "id": item.alarm.id,
        });
      }

      for (var item in mealsList) {
        item.forEach((title, alarm) {
          print('➕ Add Meal → $title | id=${alarm.id}');
          combined.add({
            "Category": "Meal",
            "Title": title,
            "RemindTime": [alarm.dateTime.toString()],
            "id": alarm.id,
          });
        });
      }

      for (var item in eventList) {
        item.forEach((title, alarm) {
          print('➕ Add Event → $title | id=${alarm.id}');
          combined.add({
            "Category": "Event",
            "Title": title,
            "RemindTime": [alarm.dateTime.toString()],
            "Description": alarm.notificationSettings.body ?? "",
            "id": alarm.id,
          });
        });
      }

      for (var item in waterList) {
        print(
          '➕ Add Water → '
          'id=${item.id}, '
          'title=${item.title}, '
          'alarms=${item.alarms.length}, '
          'timesPerDay=${item.timesPerDay}',
        );

        combined.add({
          "Category": "Water",
          "Title": item.title,
          "RemindFrequencyCount": int.tryParse(item.timesPerDay),
          "id": item.id,
        });
      }

      reminders.value = combined;
      print('✅ Combined reminders count: ${combined.length}');
    } catch (e, stack) {
      print('❌ Error loading reminder lists: $e');
      print(stack);
    } finally {
      isLoading(false);
      print('🔚 loadAllReminderLists() END');
    }
  }

  // ==================== API Methods ====================

  Future<void> getReminders(BuildContext context) async {
    try {
      isLoading(true);
      var result = await getReminderFromAPI(context);
      var reminders = result as List<Map<String, dynamic>>;
      this.reminders.assignAll(reminders);
      print(reminders);
    } catch (e) {
      print("Error fetching reminders");
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
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Failed to fetch reminders: ${response.statusCode}',
        );
        return [];
      }

      final enc = jsonEncode(response);
      final decbody = jsonDecode(enc);
      final List remindersList = decbody['data']['Reminders'] as List;
      return remindersList.map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      // CustomSnackbar.showError(
      //   context: context,
      //   title: 'Error',
      //   message: 'Exception while fetching reminders',
      // );
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
        await getReminders(context);
      }
    } catch (e) {
      // CustomSnackbar.showError(
      //   context: context,
      //   title: 'Error',
      //   message: 'Exception while saving Reminder record',
      // );
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
        await getReminders(context);
      }
    } catch (e) {
      // CustomSnackbar.showError(
      //   context: context,
      //   title: 'Error',
      //   message: 'Exception while updating Reminder record',
      // );
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
      if (editingId.value != null) {
        updateReminderFromLocal(
          context,
          id: editingId.value,
          category: "Medicine",
          timeOfDay: pickedTime.value!,
        );
      } else {
        addAlarm(context, timeOfDay: pickedTime.value!, category: "Medicine");
      }
      return true;
    } else if (selectedCategory.value == "Water") {
      if (waterReminderOption.value == 0) {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Please enter hours interval',
        );
        return false;
      }
      if (startWaterTimeController.text.isEmpty) {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Please enter start time',
        );
        return false;
      }
      if (endWaterTimeController.text.isEmpty) {
        print(endWaterTimeController.text);
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Please enter end time',
        );
        return false;
      }
      if (waterReminderOption.value == 1 && savedTimes.value <= 0) {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Please enter times per day',
        );
        return false;
      }
      if (editingId.value != null) {
        updateReminderFromLocal(
          context,
          id: editingId.value,
          category: "Water",
          times: waterReminderOption.value == 1 ? savedTimes.value : null,
          timeOfDay: TimeOfDay.now(),
        );
      } else {
        setWaterAlarm(
          context: context,
          times: waterReminderOption.value == 1 ? savedTimes.value : null,
        );
      }
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
      if (editingId.value != null) {
        updateReminderFromLocal(
          context,
          id: editingId.value,
          category: "Meal",
          timeOfDay: pickedTime.value!,
        );
      } else {
        addAlarm(context, timeOfDay: pickedTime.value!, category: "Meal");
      }
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
      if (editingId.value != null) {
        updateReminderFromLocal(
          context,
          id: editingId.value,
          category: "Event",
          timeOfDay: pickedTime.value!,
        );
      } else {
        addAlarm(context, timeOfDay: pickedTime.value!, category: "Event");
      }
      return true;
    }
    return false;
  }

  // ==================== Refresh Methods ====================

  /// Refresh all reminder data from both local storage and API
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
    startWaterTimeController.clear();
    endWaterTimeController.clear();
    // medicineList.clear(); // FIX: Do not clear reminder list on reset
    notesController.clear();
    everyHourController.clear();
    timesPerDayController.clear();
    selectedCategory.value = 'Medicine';
    editingId.value = null; // Clear ID so next add is fresh
    startDate.value = DateTime.now();
    endDate.value = null;
    pickedTime.value = null;
    waterReminderOption.value = 1;
    //savedInterval.value = 0;
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
    editingId.value = reminder['id']; // Populate ID from the opened reminder

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
  }

  String formatReminderTime(List remindTimes) {
    if (remindTimes.isEmpty) return 'N/A';

    List<String> formattedTimes = [];
    for (var time in remindTimes) {
      try {
        if (time is String) {
          try {
            DateTime dateTime = DateTime.parse(time);
            formattedTimes.add(DateFormat('hh:mm a').format(dateTime));
          } catch (e) {
            formattedTimes.add(time);
          }
        } else if (time is DateTime) {
          formattedTimes.add(DateFormat('hh:mm a').format(time));
        }
      } catch (e) {
        print('Error formatting time: $e');
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

  String formatTimeFromHourMinute(int hour, int minute) {
    try {
      final now = DateTime.now();
      final dateTime = DateTime(now.year, now.month, now.day, hour, minute);
      return DateFormat('hh:mm a').format(dateTime);
    } catch (e) {
      return '$hour:$minute';
    }
  }

  TimeOfDay _parseTime(String timeString) {
    final format = DateFormat("hh:mm a");
    return TimeOfDay.fromDateTime(format.parse(timeString));
  }

  DateTime _parseWaterTime(String time) {
    final now = DateTime.now();
    final parsed = DateFormat('hh:mm a').parse(time);

    return DateTime(now.year, now.month, now.day, parsed.hour, parsed.minute);
  }

  Duration _waterDuration() {
    DateTime start = _parseWaterTime(startWaterTimeController.text);
    DateTime end = _parseWaterTime(endWaterTimeController.text);

    if (end.isBefore(start)) {
      end = end.add(const Duration(days: 1));
    }

    return end.difference(start);
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
    final gap = totalMinutes ~/ times;

    return List.generate(times, (i) {
      return startDT.add(Duration(minutes: gap * i));
    });
  }
}
