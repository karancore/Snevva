import 'dart:async';
import 'package:flutter/widgets.dart';
import 'dart:convert';

import 'package:alarm/alarm.dart';
import 'package:alarm/model/alarm_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:snevva/Controllers/Reminder/event_controller.dart';
import 'package:snevva/Controllers/Reminder/meal_controller.dart';
import 'package:snevva/Controllers/Reminder/medicine_controller.dart';
import 'package:snevva/Controllers/Reminder/water_controller.dart';
import 'package:snevva/common/custom_snackbar.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/env/env.dart';
import 'package:snevva/services/api_service.dart';

import '../../common/global_variables.dart';
import '../../models/medicine_reminder_model.dart';
import '../../models/water_reminder_model.dart';

class ReminderController extends GetxController {
  final titleController = TextEditingController();
  final timeController = TextEditingController();
  final notesController = TextEditingController();
  Rx<TimeOfDay?> waterStartTime = Rx<TimeOfDay?>(TimeOfDay(hour: 8, minute: 0));
  Rx<TimeOfDay?> waterEndTime = Rx<TimeOfDay?>(TimeOfDay(hour: 22, minute: 0));
  Rxn<dynamic> editingId = Rxn<dynamic>();
  final xTimeUnitController = TextEditingController();
  var reminders = <Map<String, dynamic>>[].obs;
  var alarms = <AlarmSettings>[].obs;
  var isLoading = false.obs;
  final selectedValue = 'minutes'.obs;
  var startDateString = ''.obs;
  var endDateString = ''.obs;


  var selectedDateIndex = 0.obs;

  var remindTimes = <String>[].obs;

  late final WaterController waterController;
  late final MedicineController medicineGetxController;
  late final EventController eventGetxController;

  late final MealController mealController;

  var selectedCategory = 'Medicine'.obs;
  var enableNotifications = true.obs;
  var soundVibrationToggle = true.obs;
  final RxnInt remindMeBefore = RxnInt();

  Rx<DateTime?> startDate = Rx<DateTime?>(null);
  Rx<DateTime?> endDate = Rx<DateTime?>(null);
  Rx<TimeOfDay?> pickedTime = Rx<TimeOfDay?>(null);

  static StreamSubscription<AlarmSettings>? subscription;
  bool listenerAttached = false;

  final List<String> categories = ['Medicine', 'Water', 'Meal', 'Event'];

  @override
  void onInit() {
    super.onInit();
    waterController = Get.find<WaterController>();
    medicineGetxController = Get.find<MedicineController>();
    mealController = Get.find<MealController>();
    eventGetxController = Get.find<EventController>();
    startDate.value = DateTime.now();
    checkAndroidNotificationPermission();
    startDateString.value = "Start Date";
    endDateString.value = "End Date";

    checkAndroidScheduleExactAlarmPermission();
    initAlarmListener();
    // Defer heavy loading until after first frame to avoid UI freeze
    // WidgetsBinding.instance.addPostFrameCallback((_) async {
    //   await loadAlarms();
    //   await loadAllReminderLists();
    // });
    Future.microtask(() {
      Future.wait([
        loadAlarms(),
        loadAllReminderLists(),
      ]);
    });



    // WidgetsBinding.instance.addPostFrameCallback((_) async {
    //   await loadAlarms();
    //   await loadAllReminderLists();
    // });
    
  }

  @override
  void onClose() {
    titleController.dispose();
    timeController.dispose();
    notesController.dispose();
    xTimeUnitController.dispose();

    super.onClose();
  }

  Future<void> handleRemindMeBefore({
    required RxnInt option,
    required TimeOfDay? timeOfDay,
    required TextEditingController timeController,
    required RxString unitController,
    required String category,
    required String title,
    required String body,
  }) async {

    // 1️⃣ Guard conditions
    if (option.value != 0) {
      return;
    }

    if (timeOfDay == null) {
      return;
    }

    // 3️⃣ Calculate scheduled time
    final now = DateTime.now();

    DateTime scheduledTime = DateTime(
      startDate.value?.year ?? now.year,
      startDate.value?.month ?? now.month,
      startDate.value?.day ?? now.day,
      timeOfDay.hour,
      timeOfDay.minute,
    );


    // 4️⃣ Adjust if in past
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));

    }

    // 5️⃣ Schedule alarm
    setBeforeReminderAlarm(mainTime: scheduledTime , title: title , body: body);

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
      print("Enabled notifications permission ${enableNotifications.value}");
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
    if(subscription != null) return;
    // if (listenerAttached) return;
    // listenerAttached = true;

    // subscription ??= Alarm.ringStream.stream.listen((
    //   AlarmSettings alarmSettings,
    // ) async {
    //   print("ALARM RANG → ID: ${alarmSettings.id}");
    //   unawaited(waterController.initialiseWaterReminder());
    // });
    subscription = Alarm.ringStream.stream.listen((
      AlarmSettings alarmSettings,
    ) async {
      print("ALARM RANG → ID: ${alarmSettings.id}");
      unawaited(waterController.initialiseWaterReminder());
    });

  }

  // ==================== Alarm Management ====================

  Future<void> loadAlarms() async {
    final loadedAlarms = await Alarm.getAlarms();
    loadedAlarms.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    alarms.value = loadedAlarms;
  }

  Future<void> setBeforeReminderAlarm({required DateTime mainTime , required String title , required String body}) async {

    // 1️⃣ Read inputs
    final amount = int.tryParse(xTimeUnitController.text) ?? 0;
    final unit = selectedValue.value; // "minutes" or "hours"



    // 2️⃣ Calculate offset
    final offset =
    unit == "minutes"
        ? Duration(minutes: amount)
        : Duration(hours: amount);


    // 3️⃣ Calculate before time
    DateTime beforeTime = mainTime.subtract(offset);

    // 4️⃣ Adjust if in past
    if (beforeTime.isBefore(DateTime.now())) {
      beforeTime = beforeTime.add(const Duration(days: 1));

    }

    // 5️⃣ Build alarm settings
    final alarmId = alarmsId();
    final alarmSettings = AlarmSettings(
      id: alarmId,
      dateTime: beforeTime,
      assetAudioPath: alarmSound,
      loopAudio: true,
      vibrate: soundVibrationToggle.value,
      androidFullScreenIntent: true,
      notificationSettings: NotificationSettings(
        title: title,
        body: "$body $amount $unit",
        stopButton: "Stop",
        icon: "alarm",
      ),
      volumeSettings: VolumeSettings.fade(
        fadeDuration: const Duration(seconds: 2),
      ),
    );


    // 6️⃣ Set alarm
    await Alarm.set(alarmSettings: alarmSettings);


  }
  DateTime calculateBeforeReminder() {

    // Parse input time (hh:mm a)
    final selectedTime = parseTime(timeController.text);

    DateTime eventTime = DateTime(
      now.year,
      now.month,
      now.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    int value = int.tryParse(xTimeUnitController.text) ?? 0;

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
      // case "Medicine":
      //   await medicineGetxController.addMedicineAlarm(scheduledTime, context);
      //   break;
      case "Meal":
        await mealController.addMealAlarm(scheduledTime, context);
        break;
      case "Event":
        await eventGetxController.addEventAlarm(scheduledTime, context);
        break;
    }
    // if (category == 'Event' && remindMeBefore.value == 0) {
    //   final rx =
    //       eventGetxController.eventRemindMeBefore;
    //   rx.value = rx.value == 0 ? null : 0;
    //   await handleRemindMeBefore(
    //     option: rx,
    //     timeOfDay: pickedTime.value,
    //     timeController: xTimeUnitController,
    //     unitController: selectedValue,
    //     category: "Medicine",
    //   );
    //   await setBeforeReminderAlarm(scheduledTime);
    // }
    // if (category == 'Medicine' && remindMeBefore.value == 0) {
    //   final rx =
    //       medicineGetxController.medicineRemindMeBeforeOption;
    //   rx.value = rx.value == 0 ? null : 0;
    //   await handleRemindMeBefore(
    //     option: rx,
    //     timeOfDay: pickedTime.value,
    //     timeController: xTimeUnitController,
    //     unitController: selectedValue,
    //     category: "Medicine",
    //   );
    // }

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

    if (category == 'Water') {
      waterController.updateWaterReminderFromLocal(context, id, times);
    } else {
      print("🔁 Updating single alarm → $category with id=$id");

      switch (category) {
        case 'Medicine':
          await medicineGetxController.updateMedicineAlarm(
            scheduledTime,
            context,
            int.parse(id),
          );
          break;
        case 'Meal':
          await mealController.updateMealAlarm(
            scheduledTime,
            context,
            int.parse(id),
          );
          break;
        case 'Event':
          await eventGetxController.updateEventAlarm(
            scheduledTime,
            context,
            int.parse(id),
          );
          break;
        default:
          print("⚠️ Unknown category: $category");
      }
    }

    print("✅ updateReminderFromLocal completed");
  }

  Future<void> finalizeUpdate(
    BuildContext context,
    String key,
    dynamic list,
  ) async {
    titleController.clear();
    notesController.clear();
    medicineGetxController.medicineController.clear();

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
      id: alarmsId(),
      dateTime: nextTime,
      assetAudioPath: alarmSound,
      androidFullScreenIntent: true,
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
    String listKey = _getListKeyFromType(reminderList);
    if (listKey.isNotEmpty) {
      await saveReminderList(reminderList, listKey);
    }
  }

  String _getListKeyFromType(RxList<Map<String, AlarmSettings>> list) {
    if (identical(list, medicineGetxController.medicineList)) return "medicine_list";
    if (identical(list, mealController.mealsList)) return "meals_list";
    if (identical(list, eventGetxController.eventList)) return "event_list";
    if (identical(list, waterController.waterList)) return "water_list";
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
        int idString = int.parse(reminder['id']);
        await _deleteFromListById(
          medicineGetxController.medicineList,
          idString,
          "medicine_list",
        );
        break;
      case 'Meal':
        await _deleteFromListById(mealController.mealsList, id, "meals_list");
        break;
      case 'Event':
        await _deleteFromListById(
          eventGetxController.eventList,
          id,
          "event_list",
        );
        break;
      case 'Water':
        if (id is String) {
          await waterController.deleteWaterReminder(id);
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
        //TODO:
        throw Exception("MedicineReminderModel deletion not implemented");
        // if ((list[i] as MedicineReminderModel).alarm.id == id) {
        //   index = i;
        //   break;
        // }
      }
    }

    if (index != -1) {
      await Alarm.stop(id);
      list.removeAt(index);
      await saveReminderList(list, keyName);
    }
  }

  // ==================== Medicine Management ====================

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

  Future<void> loadAllReminderLists() async {
    try {
      print('🔄 loadAllReminderLists() START');
      isLoading(true);

      medicineGetxController.medicineList.value = await medicineGetxController
          .loadMedicineReminderList("medicine_list");
      print(
        '💊 Medicine loaded: ${medicineGetxController.medicineList.length}',
      );

      mealController.mealsList.value = await loadReminderList("meals_list");
      print('🍽 Meals loaded: ${mealController.mealsList.length}');

      eventGetxController.eventList.value = await loadReminderList(
        "event_list",
      );
      print('📅 Events loaded: ${eventGetxController.eventList.length}');

      waterController.waterList.value = await waterController
          .loadWaterReminderList("water_list");
      print('💧 Water loaded: ${waterController.waterList.length}');

      final List<Map<String, dynamic>> combined = [];

      print('🧩 Building combined reminder list');

      for (var item in medicineGetxController.medicineList) {
        print('➕ Add Medicine → ${item.title}');
        print('Description Med: ${item.note ?? ""}');

        combined.add({
          "id": item.id,
          "Category": "Medicine",
          "Title": item.title,
          "MedicineName": item.medicineName,
          //"RemindTime": [item.alarm.dateTime.toString()],
          "Description": item.note ?? "",
        });
      }

      for (var item in mealController.mealsList) {
        item.forEach((title, alarm) {
          print('➕ Add Meal → $title | id=${alarm.id}');
          combined.add({
            "id": alarm.id,
            "Category": "Meal",
            "Title": title,
            "RemindTime": [alarm.dateTime.toString()],
          });
        });
      }

      for (var item in eventGetxController.eventList) {
        item.forEach((title, alarm) {
          print('➕ Add Event → $title | id=${alarm.id}');
          print('Description: ${alarm.notificationSettings.body ?? ""}');
          combined.add({
            "id": alarm.id,
            "Category": "Event",
            "Title": title,
            "RemindTime": [alarm.dateTime.toString()],
            "Description": alarm.notificationSettings.body ?? "",
          });
        });
      }

      for (var item in waterController.waterList) {
        print(
          '➕ Add Water → '
          'id=${item.id}, '
          'title=${item.title}, '
          'alarms=${item.alarms.length}, '
          'timesPerDay=${item.timesPerDay} , '
          'interval= ${item.interval}',
        );

        combined.add({
          "id": item.id,
          "Category": "Water",
          "Title": item.title,
          "RemindFrequencyCount": int.tryParse(item.timesPerDay),
          "RemindFrequencyHour": item.interval,
        });
      }

      reminders.value = combined;
      print('Combined reminders count: ${combined.length}');
    } catch (e, stack) {
      print('❌ Error loading reminder lists: $e');
      print(stack);
    } finally {
      isLoading(false);
      print('loadAllReminderLists() END');
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
      debugPrint("Exception while fetching reminders: $e");

      return [];
    }
  }

  Map<String, dynamic> buildReminderPayload({
    required String category,
    required int id,
  }) {
    final DateTime start = startDate.value ?? DateTime.now();
    return {
      "Id": id,
      "Title": titleController.text.trim(),
      "Description": notesController.text.trim(),
      "Category": category,
      "MedicineName": medicineGetxController.medicineController.text.trim() ,
      "StartDay": start.day,
      "StartMonth": start.month,
      "StartYear": start.year,
      "RemindTime": List<String>.from(remindTimes),
      "RemindFrequencyHour":
          int.tryParse(waterController.everyHourController.text) ?? 0,
      "RemindFrequencyCount":
          int.tryParse(waterController.timesPerDayController.text) ?? 0,
      "EnablePushNotification": enableNotifications.value,
      "IsActive": true,
    };
  }

  Future<void> addRemindertoAPI(
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
      }
      // else {
      //   await getReminders(context);
      // }
    } catch (e) {
      debugPrint("Exception while saving Reminder record: $e");
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
      }
      // else {
      //   await getReminders(context);
      // }
    } catch (e) {
      debugPrint("Exception while updating Reminder record: $e");
    }
  }

  Future<bool> validateAndSave({required BuildContext context , num ? dosage}) async {

    final isSelected =
        medicineGetxController.medicineRemindMeBeforeOption.value == 0;

    if (isSelected) {
      await handleRemindMeBefore(
        option: medicineGetxController.medicineRemindMeBeforeOption,
        timeOfDay: pickedTime.value,
        timeController: xTimeUnitController,
        unitController: selectedValue,
        category: "Medicine",
        title: "Reminder before your medicine",
        body: "Your medicine is coming in ",
      );
    }
    final isSelectedEvent =
        eventGetxController.eventRemindMeBefore.value == 0;

    if (isSelectedEvent) {
      await handleRemindMeBefore(
        option: eventGetxController.eventRemindMeBefore,
        timeOfDay: pickedTime.value,
        timeController: xTimeUnitController,
        unitController: selectedValue,
        title: "Reminder before your event",
        body: "Your event is coming in ",
        category: "Event",
      );
    }


    if (pickedTime.value == null &&
        (selectedCategory.value == "Medicine" ||
            selectedCategory.value == "Meal" ||
            selectedCategory.value == "Event")) {
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Please select a ${selectedCategory.value.toLowerCase()} time',
      );
      return false;
    }
    if (editingId.value != null) {
      updateReminderFromLocal(
        context,
        id: editingId.value,
        category: selectedCategory.value,
        timeOfDay: pickedTime.value!,
      );
      return true;
    }

    if (selectedCategory.value == "Medicine") {
      if (dosage == null || dosage <= 0) {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Please enter a valid dosage',
        );
        return false;
      }
    }

    switch (selectedCategory.value) {
      case "Medicine":
        CustomSnackbar.showSnackbar(
          context: context,
          title: "Work In Progress",
          message: "",
        );

        medicineGetxController.addMedicineAlarm(
          context: context,
          dosage: dosage
        );

        if (medicineGetxController.medicineReminderOption.value == Option.interval) {
          final intervalHours = int.tryParse(
            medicineGetxController.everyHourController.text,
          ) ?? 0;

          final startDateTime = startDate.value ?? DateTime.now();
          final endDateTime = endDate.value ?? DateTime.now();

          medicineGetxController.addMedicineIntervalAlarm(
            context: context,
            startDateTime: startDateTime,
            endDateTime: endDateTime,
            dosage : dosage,
            intervalHours: intervalHours,
          );
        }

      case "Meal":
      case "Event":
        addAlarm(
          context,
          timeOfDay: pickedTime.value!,
          category: selectedCategory.value,
        );
        break;

      case "Water":
        waterController.validateAndSaveWaterReminder(context);
        break;

      default:
        print("⚠️ Unknown category: ${selectedCategory.value}");
    }

    return true;
  }

  Future<void> refreshAllData(BuildContext context) async {
    await loadAllReminderLists();
  }

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

  // Color getCategoryColor(String category) {
  //   return AppColors.primaryColor;
  // }

  void resetForm() {
    titleController.clear();
    timeController.clear();

    // medicineList.clear(); // FIX: Do not clear reminder list on reset
    notesController.clear();
    waterController.resetControllers();

    selectedCategory.value = 'Medicine';
    editingId.value = null; // Clear ID so next add is fresh
    startDate.value = DateTime.now();
    endDate.value = null;
    pickedTime.value = null;
    waterController.waterReminderOption.value = Option.interval;
    //savedInterval.value = 0;

    enableNotifications.value = true;
    soundVibrationToggle.value = true;
    remindTimes.clear();
  }

  void loadReminderData(Map<String, dynamic> reminder) {
    titleController.text = reminder['Title'] ?? '';
    notesController.text = reminder['Description'] ?? '';
    selectedCategory.value = reminder['Category'] ?? 'Medicine';
    editingId.value = reminder['id']; // Populate ID from the opened reminder

    if (selectedCategory.value == 'Medicine') {
      medicineGetxController.medicineController.text = reminder['MedicineName'] ?? '';
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

    waterController.everyHourController.text =
        reminder['RemindFrequencyHour']?.toString() ?? '';
    waterController.timesPerDayController.text =
        reminder['RemindFrequencyCount']?.toString() ?? '';
    enableNotifications.value = reminder['EnablePushNotification'] ?? false;
  }
}
