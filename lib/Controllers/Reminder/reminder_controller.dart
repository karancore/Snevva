import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:alarm/alarm.dart';
import 'package:alarm/model/alarm_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/env/env.dart';
import 'package:snevva/services/api_service.dart';

class ReminderController extends GetxController {
  // ==================== Controllers ====================
  final titleController = TextEditingController();
  final medicineController = TextEditingController();
  final timeController = TextEditingController();
  final notesController = TextEditingController();
  final everyHourController = TextEditingController();
  final timesPerDayController = TextEditingController();

  // ==================== Observable Variables ====================
  var reminders = <Map<String, dynamic>>[].obs;
  var alarms = <AlarmSettings>[].obs;
  var isLoading = false.obs;

  var medicineList = <Map<String, AlarmSettings>>[].obs;
  var eventList = <Map<String, AlarmSettings>>[].obs;
  var waterList = <Map<String, AlarmSettings>>[].obs;
  var mealsList = <Map<String, AlarmSettings>>[].obs;

  var medicineNames = <String>[].obs;
  var remindTimes = <String>[].obs;

  // ==================== State Variables ====================
  var selectedCategory = 'Medicine'.obs;
  var enableNotifications = false.obs;
  var soundVibrationToggle = true.obs;
  var waterReminderOption = 1.obs;
  var savedInterval = 0.obs;
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

      await Alarm.stop(alarmSettings.id);

      if (savedInterval.value > 0) {
        print("🔄 Rescheduling water alarm (every ${savedInterval.value} hours)");
        await scheduleAlarmEveryXHours(savedInterval.value);
      } else if (savedTimes.value > 0) {
        int totalMinutes = (24 * 60) ~/ savedTimes.value;
        int hours = totalMinutes ~/ 60;
        int minutes = totalMinutes % 60;

        print(
          "🔄 Rescheduling water alarm (${savedTimes.value} times/day = ${hours}h ${minutes}m)",
        );

        final nextTime = DateTime.now().add(
          Duration(hours: hours, minutes: minutes),
        );

        final newAlarm = AlarmSettings(
          id: _alarmId(),
          dateTime: nextTime,
          assetAudioPath: alarmSound,
          loopAudio: true,
          vibrate: soundVibrationToggle.value,
          warningNotificationOnKill: Platform.isAndroid,
          androidFullScreenIntent: true,
          volumeSettings: VolumeSettings.fade(
            volume: 0.8,
            fadeDuration: Duration(seconds: 5),
            volumeEnforced: true,
          ),
          notificationSettings: NotificationSettings(
            title: titleController.text.isNotEmpty
                ? titleController.text
                : 'Water Reminder',
            body: notesController.text.isNotEmpty
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

  Future<void> addAlarm({
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
        await _addMedicineAlarm(scheduledTime);
        break;
      case "Meal":
        await _addMealAlarm(scheduledTime);
        break;
      case "Event":
        await _addEventAlarm(scheduledTime);
        break;
    }
  }

  Future<void> _addMedicineAlarm(DateTime scheduledTime) async {
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
      notificationSettings: enableNotifications.value
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
      medicineList.add({medicineController.text.trim(): alarmSettings});
      await saveReminderList(medicineList, "medicine_list");

      // Reload the combined list
      await loadAllReminderLists();

      Get.snackbar(
        'Success',
        'Medicine reminder set successfully!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.primaryColor,
        colorText: Colors.white,
      );
      Get.back(result: true);
      final allAlarms = await Alarm.getAlarms();
      print('   Total alarms active: ${allAlarms.length}');
    }
  }

  Future<void> _addMealAlarm(DateTime scheduledTime) async {
    final alarmSettings = AlarmSettings(
      id: _alarmId(),
      dateTime: scheduledTime,
      assetAudioPath: alarmSound,
      loopAudio: true,
      vibrate: soundVibrationToggle.value,
      warningNotificationOnKill: Platform.isAndroid,
      androidFullScreenIntent: true,
      volumeSettings: VolumeSettings.fade(
        volume: 0.8,
        fadeDuration: Duration(seconds: 5),
        volumeEnforced: true,
      ),
      notificationSettings: enableNotifications.value
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
      await saveReminderList(mealsList, "meals_list");

      // Reload the combined list
      await loadAllReminderLists();

      Get.snackbar(
        'Success',
        'Meal reminder set successfully!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.primaryColor,
        colorText: Colors.white,
      );
      Get.back(result: true);
    }
  }

  Future<void> _addEventAlarm(DateTime scheduledTime) async {
    final alarmSettings = AlarmSettings(
      id: _alarmId(),
      dateTime: scheduledTime,
      assetAudioPath: alarmSound,
      loopAudio: true,
      vibrate: soundVibrationToggle.value,
      warningNotificationOnKill: Platform.isAndroid,
      androidFullScreenIntent: true,
      volumeSettings: VolumeSettings.fade(
        volume: 0.8,
        fadeDuration: Duration(seconds: 5),
        volumeEnforced: true,
      ),
      notificationSettings: enableNotifications.value
          ? NotificationSettings(
        title: titleController.text,
        body: notesController.text.isNotEmpty
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
      eventList.add({medicineController.text.trim(): alarmSettings});
      await saveReminderList(eventList, "event_list");

      // Reload the combined list
      await loadAllReminderLists();

      Get.snackbar(
        'Success',
        'Event reminder set successfully!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.primaryColor,
        colorText: Colors.white,
      );
      Get.back(result: true);
    }
  }

  Future<void> setWaterAlarm({
    required int? interval,
    required int? times,
  }) async {
    bool alarmSet = false;

    if (times != null && times > 0) {
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
        vibrate: soundVibrationToggle.value,
        warningNotificationOnKill: Platform.isAndroid,
        androidFullScreenIntent: true,
        volumeSettings: VolumeSettings.fade(
          volume: 0.8,
          fadeDuration: Duration(seconds: 5),
          volumeEnforced: true,
        ),
        notificationSettings: enableNotifications.value
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
      print('   Set result: ${success ? "✅" : "❌"}');
      alarmSet = success;
    }

    if (interval != null && interval > 0) {
      var scheduledTime = DateTime.now().add(Duration(hours: interval));

      print('💧 Setting water alarm every $interval hours');
      print('   Next alarm at: $scheduledTime');

      final alarmSettings = AlarmSettings(
        id: _alarmId(),
        dateTime: scheduledTime,
        assetAudioPath: alarmSound,
        loopAudio: true,
        vibrate: soundVibrationToggle.value,
        warningNotificationOnKill: Platform.isAndroid,
        androidFullScreenIntent: true,
        volumeSettings: VolumeSettings.fade(
          volume: 0.8,
          fadeDuration: Duration(seconds: 5),
          volumeEnforced: true,
        ),
        notificationSettings: enableNotifications.value
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
        saveReminderList(waterList, "water_list");
      }
      print('   Set result: ${success ? "✅" : "❌"}');
      alarmSet = alarmSet || success;
    }

    if ((times == null || times <= 0) && (interval == null || interval <= 0)) {
      Get.snackbar(
        'Error',
        'Please enter a valid reminder interval',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    await loadAlarms();

    final allAlarms = await Alarm.getAlarms();
    print('💧 Total alarms active: ${allAlarms.length}');

    if (alarmSet) {
      // Reload the combined list before showing success message
      await loadAllReminderLists();

      Get.snackbar(
        'Success',
        'Water reminder set successfully!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.primaryColor,
        colorText: Colors.white,
      );
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
      warningNotificationOnKill: Platform.isAndroid,
      androidFullScreenIntent: true,
      volumeSettings: VolumeSettings.fade(
        volume: 0.8,
        fadeDuration: Duration(seconds: 5),
        volumeEnforced: true,
      ),
      notificationSettings: enableNotifications.value
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

  Future<void> stopAlarm(
      int index,
      AlarmSettings alarm,
      RxList<Map<String, AlarmSettings>> reminderList,
      ) async {
    await Alarm.stop(alarm.id);
    reminderList.removeAt(index);
  }

  // ==================== Medicine Management ====================

  void addMedicine() {
    if (medicineController.text.isNotEmpty) {
      medicineNames.add(medicineController.text);
      medicineController.clear();
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

    List<String> stringList = list.map((mapItem) {
      final jsonMap = mapItem.map((key, value) {
        return MapEntry(key, value.toJson());
      });
      return jsonEncode(jsonMap);
    }).toList();

    prefs.setStringList(keyName, stringList);
  }

  Future<void> loadAllReminderLists() async {
    try {
      isLoading(true);

      medicineList.value = await loadReminderList("medicine_list");
      mealsList.value = await loadReminderList("meals_list");
      eventList.value = await loadReminderList("event_list");
      waterList.value = await loadReminderList("water_list");

      List<Map<String, dynamic>> combined = [];

      for (var item in medicineList) {
        item.forEach((title, alarm) {
          combined.add({
            "Category": "Medicine",
            "Title": title,
            "MedicineName": alarm.notificationSettings.body?.split(",") ?? [],
            "RemindTime": [alarm.dateTime.toString()],
            "Description": alarm.notificationSettings.body ?? "",
          });
        });
      }

      for (var item in mealsList) {
        item.forEach((title, alarm) {
          combined.add({
            "Category": "Meal",
            "Title": title,
            "RemindTime": [alarm.dateTime.toString()],
          });
        });
      }

      for (var item in eventList) {
        item.forEach((title, alarm) {
          combined.add({
            "Category": "Event",
            "Title": title,
            "StartDay": alarm.dateTime.day,
            "StartMonth": alarm.dateTime.month,
            "StartYear": alarm.dateTime.year,
            "RemindTime": [alarm.dateTime.toString()],
            "Description": alarm.notificationSettings.body ?? "",
          });
        });
      }

      for (var item in waterList) {
        item.forEach((title, alarm) {
          combined.add({
            "Category": "Water",
            "Title": title,
            "RemindFrequencyHour": alarm.dateTime.hour,
            "RemindFrequencyCount": alarm.dateTime.minute,
          });
        });
      }

      reminders.value = combined;
    } catch (e) {
      Get.snackbar('Error', '❌ Failed to load reminder lists');
      print('Error loading reminder lists: $e');
    } finally {
      isLoading(false);
    }
  }

  // ==================== API Methods ====================

  Future<void> getReminders() async {
    try {
      isLoading(true);
      var result = await getReminderFromAPI();
      var reminders = result as List<Map<String, dynamic>>;
      this.reminders.assignAll(reminders);
      print(reminders);
    } catch (e) {
      print("Error fetching reminders");
    } finally {
      isLoading(false);
    }
  }

  Future<dynamic> getReminderFromAPI() async {
    try {
      final response = await ApiService.post(
        getreminderApi,
        null,
        withAuth: true,
        encryptionRequired: false,
      );

      if (response is http.Response && response.statusCode >= 400) {
        Get.snackbar(
          'Error',
          '❌ Failed to fetch reminders: ${response.statusCode}',
        );
        return [];
      }

      final enc = jsonEncode(response);
      final decbody = jsonDecode(enc);
      final List remindersList = decbody['data']['Reminders'] as List;
      return remindersList.map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      Get.snackbar('Error', '❌ Exception while fetching reminders');
      return [];
    }
  }

  Future<void> addReminder(Map<String, dynamic> reminderData) async {
    try {
      final response = await ApiService.post(
        addreminderApi,
        reminderData,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response && response.statusCode >= 400) {
        Get.snackbar(
          'Error',
          '❌ Failed to save Reminder record: ${response.statusCode}',
        );
      } else {
        getReminders();
      }
    } catch (e) {
      Get.snackbar('Error', '❌ Exception while saving Reminder record');
    }
  }

  Future<void> updateReminder(Map<String, dynamic> reminderData) async {
    try {
      final response = await ApiService.post(
        editreminderApi,
        reminderData,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response && response.statusCode >= 400) {
        Get.snackbar(
          'Error',
          '❌ Failed to update Reminder record: ${response.statusCode}',
        );
      } else {
        getReminders();
      }
    } catch (e) {
      Get.snackbar('Error', '❌ Exception while updating Reminder record');
    }
  }

  // ==================== Validation & Save Methods ====================

  bool validateAndSave() {
    if (selectedCategory.value == "Medicine") {
      if (pickedTime.value == null) {
        Get.snackbar(
          'Error',
          'Please select a reminder time',
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }
      addAlarm(timeOfDay: pickedTime.value!, category: "Medicine");
      return true;
    } else if (selectedCategory.value == "Water") {
      if (waterReminderOption.value == 0 && savedInterval.value <= 0) {
        Get.snackbar(
          'Error',
          'Please enter hours interval',
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }
      if (waterReminderOption.value == 1 && savedTimes.value <= 0) {
        Get.snackbar(
          'Error',
          'Please enter times per day',
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }
      setWaterAlarm(
        interval: waterReminderOption.value == 0 ? savedInterval.value : null,
        times: waterReminderOption.value == 1 ? savedTimes.value : null,
      );
      return true;
    } else if (selectedCategory.value == "Meal") {
      if (pickedTime.value == null) {
        Get.snackbar(
          'Error',
          'Please select a meal time',
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }
      addAlarm(timeOfDay: pickedTime.value!, category: "Meal");
      return true;
    } else if (selectedCategory.value == "Event") {
      if (pickedTime.value == null) {
        Get.snackbar(
          'Error',
          'Please select an event time',
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }
      addAlarm(timeOfDay: pickedTime.value!, category: "Event");
      return true;
    }
    return false;
  }

  // ==================== Refresh Methods ====================

  /// Refresh all reminder data from both local storage and API
  Future<void> refreshAllData() async {
    await Future.wait([
      loadAllReminderLists(),
      getReminders(),
    ]);
  }

  // ==================== Helper Methods ====================

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

  Color getCategoryColor(String category) {
    return AppColors.primaryColor;
  }

  void resetForm() {
    titleController.clear();
    medicineController.clear();
    timeController.clear();
    notesController.clear();
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

    everyHourController.text = reminder['RemindFrequencyHour']?.toString() ?? '';
    timesPerDayController.text = reminder['RemindFrequencyCount']?.toString() ?? '';
    enableNotifications.value = reminder['EnablePushNotification'] ?? false;
  }

  String formatReminderTime(List remindTimes) {
    if (remindTimes.isEmpty) return 'N/A';
    return remindTimes.join(', ');
  }

  String formatDate(int? day, int? month, int? year) {
    if (day == null || month == null || year == null) return 'N/A';
    return '$day/$month/$year';
  }

  double getListHeight(int itemCount) {
    return (itemCount * itemHeight).clamp(0, maxHeight);
  }
}