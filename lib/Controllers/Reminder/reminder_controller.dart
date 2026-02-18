import 'dart:async';
import 'package:flutter/widgets.dart';
import 'dart:convert';

import 'package:alarm/alarm.dart';
import 'package:alarm/model/alarm_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:snevva/Controllers/Reminder/event_controller.dart';
import 'package:snevva/Controllers/Reminder/meal_controller.dart';
import 'package:snevva/Controllers/Reminder/medicine_controller.dart';
import 'package:snevva/Controllers/Reminder/water_controller.dart';
import 'package:snevva/common/custom_snackbar.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/env/env.dart';
import 'package:snevva/models/hive_models/reminder_payload_model.dart'
    as reminder_payload;
import 'package:snevva/services/api_service.dart';

import '../../common/global_variables.dart';
import '../../models/reminders/medicine_reminder_model.dart'
    as medicine_payload;
import '../../models/reminders/water_reminder_model.dart';
import '../../services/hive_service.dart';

class ReminderController extends GetxController {
  final titleController = TextEditingController();
  final timeController = TextEditingController();
  final notesController = TextEditingController();
  Rx<TimeOfDay?> waterStartTime = Rx<TimeOfDay?>(TimeOfDay(hour: 8, minute: 0));
  Rx<TimeOfDay?> waterEndTime = Rx<TimeOfDay?>(TimeOfDay(hour: 22, minute: 0));
  Rxn<dynamic> editingId = Rxn<dynamic>();
  final xTimeUnitController = TextEditingController();
  var reminders = <reminder_payload.ReminderPayloadModel>[].obs;
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

  var selectedCategory = 'medicine'.obs;
  var enableNotifications = true.obs;
  var soundVibrationToggle = true.obs;
  final RxnInt remindMeBefore = RxnInt();
  static const int maxTitleLength = 45;

  Rx<DateTime?> startDate = Rx<DateTime?>(null);
  Rx<DateTime?> endDate = Rx<DateTime?>(null);
  Rx<TimeOfDay?> pickedTime = Rx<TimeOfDay?>(null);

  static StreamSubscription<AlarmSettings>? subscription;
  bool listenerAttached = false;

  final List<String> categories = ['medicine', 'water', 'meal', 'event'];

  @override
  void onInit() {
    super.onInit();
    waterController = Get.find<WaterController>();
    medicineGetxController = Get.find<MedicineController>();
    mealController = Get.find<MealController>();
    eventGetxController = Get.find<EventController>();
    startDate.value = DateTime.now();
    initAlarmListener();

    startDateString.value = "Start Date";
    endDateString.value = "End Date";

    Future.microtask(() async {
      await checkAndroidNotificationPermission();
      await checkAndroidScheduleExactAlarmPermission();
      await cleanupExpiredBeforeAlarms();
      await loadAlarms();
      await loadAllReminderLists();
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

  // BoxShadow(
  // color: Colors.grey.withOpacity(0.4), // Shadow color
  // spreadRadius: 2, // How widely the shadow spreads
  // blurRadius: 6, // How blurry the shadow is

  // offset: Offset(0, 0), // Horizontal and vertical offset
  // ),

  Future<void> handleRemindMeBefore({
    required RxnInt option,
    required TimeOfDay? timeOfDay,
    required TextEditingController timeController,
    required RxString unitController,
    required String timeBefore,
    required String category,
    required String title,
    required String body,
  }) async {
    if (option.value != 0) {
      return;
    }

    debugPrint('📢 handleRemindMeBefore triggered');
    debugPrint('   ↳ Category: $category');
    debugPrint('   ↳ Option Value: ${option.value}');
    debugPrint('   ↳ Selected Unit: ${unitController.value}');
    debugPrint('   ↳ Raw Time Input: "$timeBefore"');

    final parsedTimeBefore = int.tryParse(timeBefore.trim()) ?? 0;
    if (parsedTimeBefore <= 0) {
      debugPrint('🛑 Guard hit: invalid remind-before value. Exiting...');
      return;
    }

    if (timeOfDay == null) {
      debugPrint('🛑 Guard hit: timeOfDay is null. Exiting...');
      return;
    }

    // 3️⃣ Calculate scheduled time
    final now = DateTime.now();
    debugPrint('🕒 Current Time (now): $now');

    DateTime scheduledTime = DateTime(
      startDate.value?.year ?? now.year,
      startDate.value?.month ?? now.month,
      startDate.value?.day ?? now.day,
      timeOfDay.hour,
      timeOfDay.minute,
    );

    debugPrint('📅 Initial Scheduled Time: $scheduledTime');
    debugPrint('📅 StartDate Source: ${startDate.value}');

    // 4️⃣ Adjust if in past
    if (scheduledTime.isBefore(now)) {
      debugPrint('⚠️ Scheduled time is in the past. Adding 1 day...');
      scheduledTime = scheduledTime.add(const Duration(days: 1));
      debugPrint('📅 New Adjusted Scheduled Time: $scheduledTime');
    }

    // 5️⃣ Schedule alarm
    debugPrint('🚀 Passing to setBeforeReminderAlarm...');
    debugPrint('   ↳ MainTime: $scheduledTime');
    debugPrint('   ↳ Title: $title');
    debugPrint('   ↳ Body: $body');

    await setBeforeReminderAlarm(
      mainTime: scheduledTime,
      timeBefore: timeBefore,
      title: title,
      category: category,
      body: body,
    );

    debugPrint('✅ handleRemindMeBefore logic finished');
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
    if (subscription != null) return;
    subscription = Alarm.ringStream.stream.listen((
      AlarmSettings alarmSettings,
    ) async {
      final payload = alarmSettings.payload;
      if (payload == null) return;
      late final Map<String, dynamic> decoded;
      try {
        decoded = jsonDecode(payload);
      } catch (_) {
        return;
      }
      if (decoded['category'] != 'water') return;
      await waterController.onWaterAlarmRang(alarmSettings.id);
    });
  }

  // ==================== Alarm Management ====================

  Future<void> loadAlarms() async {
    final loadedAlarms = await Alarm.getAlarms();
    loadedAlarms.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    alarms.value = loadedAlarms;
  }

  Future<void> setBeforeReminderAlarm({
    required DateTime mainTime,
    required String timeBefore,
    required String category,
    required String title,
    required String body,
  }) async {
    debugPrint('🔔 [setBeforeReminderAlarm] START');
    debugPrint('   ↳ Main Event Time: $mainTime');

    // 1️⃣ Read inputs
    final rawAmount = timeBefore;
    final amount = int.tryParse(rawAmount) ?? 0;
    final unit = selectedValue.value;

    debugPrint('   ↳ Offset Input: $rawAmount ($unit)');

    // 2️⃣ Calculate offset
    final offset =
        unit == "minutes" ? Duration(minutes: amount) : Duration(hours: amount);
    debugPrint('   ↳ Calculated Duration Offset: $offset');

    // 3️⃣ Calculate before time
    DateTime beforeTime = mainTime.subtract(offset);
    debugPrint('   ↳ Calculated BeforeTime (Main - Offset): $beforeTime');

    // 4️⃣ Adjust if in past
    final now = DateTime.now();
    if (beforeTime.isBefore(now)) {
      debugPrint('   ⚠️ BeforeTime ($beforeTime) is earlier than Now ($now)');
      beforeTime = beforeTime.add(const Duration(days: 1));
      debugPrint('   ↳ Adjusted BeforeTime (+1 Day): $beforeTime');
    }

    // 5️⃣ Build alarm settings
    final alarmId = alarmsId();
    debugPrint('   ↳ Generated Before-Alarm ID: $alarmId');

    final alarmSettings = AlarmSettings(
      id: alarmId,
      dateTime: beforeTime,
      assetAudioPath: alarmSound,
      loopAudio: false,
      allowAlarmOverlap: true,
      vibrate: soundVibrationToggle.value,
      androidFullScreenIntent: true,
      notificationSettings: NotificationSettings(
        title: title,
        body: "$body $amount $unit",
        stopButton: "Stop",
        icon: "alarm",
      ),
      payload: jsonEncode({
        "type": "before",
        "category": category,
        "mainTime": mainTime.toIso8601String(),
      }),
      volumeSettings: VolumeSettings.fade(
        fadeDuration: const Duration(seconds: 2),
      ),
    );

    // 6️⃣ Set alarm
    debugPrint('   🚀 Setting "Before" Alarm at: ${alarmSettings.dateTime}');
    final success = await Alarm.set(alarmSettings: alarmSettings);

    if (success) {
      debugPrint('✅ [setBeforeReminderAlarm] Alarm set successfully');
    } else {
      debugPrint('❌ [setBeforeReminderAlarm] Alarm.set FAILED');
    }
  }

  Future<void> cleanupExpiredBeforeAlarms() async {
    final alarms = await Alarm.getAlarms();
    final now = DateTime.now();
    for (final alarm in alarms) {
      final payload = alarm.payload;
      if (payload == null) continue;
      final decoded = jsonDecode(payload);
      if (decoded['type'] == 'before') {
        try {
          final decoded = jsonDecode(payload);
          if (decoded['type'] == 'before') {
            final mainTime = DateTime.parse(decoded['mainTime']);
            if (now.isAfter(mainTime)) {
              debugPrint(
                "Cancelling expired before-alarm ${alarm.notificationSettings.title}",
              );
              await Alarm.stop(alarm.id);
            }
          }
        } catch (_) {}
      }
    }
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
    print("Add Alarm category $category");

    switch (category) {
      // case "Medicine":
      //   await medicineGetxController.addMedicineAlarm(scheduledTime, context);
      //   break;
      case "meal":
        await mealController.addMealAlarm(scheduledTime, context);
        break;
      case "event":
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

    if (category == 'water') {
      waterController.updateWaterReminderFromLocal(context, id, times);
    } else {
      print("🔁 Updating single alarm → $category with id=$id");

      switch (category) {
        case 'medicine':
          await medicineGetxController.updateMedicineAlarm(
            scheduledTime,
            context,
            int.parse(id),
          );
          break;
        case 'meal':
          await mealController.updateMealAlarm(
            scheduledTime,
            context,
            int.parse(id),
          );
          break;
        case 'event':
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
      payload: jsonEncode({
        "type": "interval",
        "category": "water",
        "intervalHours": intervalHours.toString(),
      }),
      notificationSettings: NotificationSettings(
        title: titleController.text,
        body: notesController.text,
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
    if (identical(list, medicineGetxController.medicineList))
      return "medicine_list";
    if (identical(list, mealController.mealsList)) return "meals_list";
    if (identical(list, eventGetxController.eventList)) return "event_list";
    if (identical(list, waterController.waterList)) return "water_list";
    return "";
  }

  Future<void> deleteReminder(
    reminder_payload.ReminderPayloadModel reminder,
  ) async {
    final id = reminder.id;
    final category = reminder.category;

    debugPrint(
      '🗑️ deleteReminder START → '
      'category=$category, id=$id (type=${id.runtimeType})',
    );

    switch (category) {
      case 'medicine':
        debugPrint('➡️ Deleting Medicine');
        await medicineGetxController.deleteMedicineReminder(id);
        break;

      case 'meal':
        debugPrint('➡️ Deleting Meal');
        await _deleteFromListById(mealController.mealsList, id, "meals_list");
        break;

      case 'event':
        debugPrint('➡️ Deleting Event');
        await _deleteFromListById(
          eventGetxController.eventList,
          id,
          "event_list",
        );
        break;

      case 'water':
        debugPrint('➡️ Deleting Water');
        //"water_list";
        await waterController.deleteWaterReminder(id);

        break;

      default:
        debugPrint('⚠️ Unknown category: $category');
    }

    debugPrint('🔄 Reloading all reminder lists');
    await loadAllReminderLists();
    debugPrint('✅ deleteReminder END');
  }

  Future<void> _deleteFromListById(
    RxList<dynamic> list,
    int id,
    String keyName,
  ) async {
    debugPrint('🗑️ Delete requested → id: $id | key: $keyName');
    debugPrint('📦 List length: ${list.length}');

    int index = -1;

    for (int i = 0; i < list.length; i++) {
      final item = list[i];
      debugPrint('🔍 Checking index $i → type: ${item.runtimeType}');

      // Handle Map<String, AlarmSettings>
      if (item is Map<String, AlarmSettings>) {
        final alarmId = item.values.first.id;
        debugPrint('   Map Alarm ID: $alarmId');

        if (alarmId == id) {
          debugPrint('   ✅ Match found at index $i (Map)');
          index = i;
          break;
        }
      }
      // Handle MedicineReminderModel
      else if (item is medicine_payload.MedicineReminderModel) {
        debugPrint('   MedicineReminderModel ID: ${item.id}');

        if (item.id == id) {
          debugPrint('   ✅ Match found at index $i (MedicineReminderModel)');
          index = i;
          break;
        }
      } else {
        debugPrint('   ⚠️ Unknown item type at index $i');
      }
    }

    if (index != -1) {
      debugPrint('🧹 Removing item at index $index');
      await Alarm.stop(id);
      list.removeAt(index);
      await saveReminderList(list, keyName);
      debugPrint('💾 Item deleted and list saved');
    } else {
      debugPrint('❌ No item found with id: $id');
    }
  }

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

    // final box = Hive.box('reminders_box');
    final box = HiveService().reminders;
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

    // final box = Hive.box('reminders_box');
    final box = HiveService().reminders;

    List<String> stringList =
        list.map((item) {
          if (item is Map<String, AlarmSettings>) {
            print('🗂 Saving Map<String, AlarmSettings>');
            final jsonMap = item.map((key, value) {
              print('   ➜ Alarm: $key | id=${value.id}');
              return MapEntry(key, value.toJson());
            });
            return jsonEncode(jsonMap);
          } else if (item is medicine_payload.MedicineReminderModel) {
            print('💊 Saving MedicineReminderModel → ${item.title}');
            return jsonEncode(item.toJson());
          } else if (item is WaterReminderModel) {
            print(
              '💧 Saving WaterReminderModel → '
              'id=${item.id}, '
              'title=${item.title}, '
              'alarms=${item.alarms.length}, '
              'waterReminderStartTime=${item.waterReminderStartTime}, '
              'waterReminderEndTime=${item.waterReminderEndTime}, '
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

      final List<reminder_payload.ReminderPayloadModel> combined = [];

      print('🧩 Building combined reminder list');

      for (var item in medicineGetxController.medicineList) {
        print('➕ Add Medicine → ${item.title}');
        print('Description Med: ${item.notes ?? ""}');
        final isTimesBased = item.customReminder.type == Option.times;
        final isIntervalBased = item.customReminder.type == Option.interval;
        combined.add(
          reminder_payload.ReminderPayloadModel(
            id: item.id,
            category: "medicine",
            title: item.title,
            whenToTake: item.whenToTake,
            medicineName: item.medicineName,
            dosage: reminder_payload.Dosage(
              value: item.dosage.value,
              unit: item.dosage.unit,
            ),
            medicineType: item.medicineType,
            notes: item.notes,
            medicineFrequencyPerDay: item.medicineFrequencyPerDay,
            customReminder: reminder_payload.CustomReminder(
              type: item.customReminder.type,
              timesPerDay:
                  isTimesBased
                      ? reminder_payload.TimesPerDay(
                        count: item.customReminder.timesPerDay?.count ?? '',
                        list: item.customReminder.timesPerDay?.list ?? [],
                      )
                      : null,
              everyXHours:
                  isIntervalBased
                      ? reminder_payload.EveryXHours(
                        hours:
                            int.tryParse(
                              item.customReminder.everyXHours?.hours ?? '',
                            ) ??
                            0,
                        startTime:
                            item.customReminder.everyXHours?.startTime ?? '',
                        endTime: item.customReminder.everyXHours?.endTime ?? '',
                      )
                      : null,
            ),
            remindBefore:
                item.remindBefore != null
                    ? reminder_payload.RemindBefore(
                      time: item.remindBefore!.time,
                      unit: item.remindBefore!.unit,
                    )
                    : null,
            startDate: item.startDate,
            endDate: item.endDate,
          ),
        );
      }

      for (var item in mealController.mealsList) {
        item.forEach((title, alarm) {
          combined.add(
            reminder_payload.ReminderPayloadModel(
              id: alarm.id,
              category: "meal",
              title: title,
              notes: alarm.notificationSettings.body,
              customReminder: reminder_payload.CustomReminder(
                timesPerDay: reminder_payload.TimesPerDay(
                  count: 1.toString(),
                  list: [alarm.dateTime.toString()],
                ),
              ),
            ),
          );
        });
      }

      for (var item in eventGetxController.eventList) {
        item.forEach((title, alarm) {
          reminder_payload.RemindBefore? remindBefore;
          String? startDate;
          if (alarm.payload != null) {
            Map<String, dynamic> data = jsonDecode(alarm.payload!);
            startDate = data['startDate'] ?? '';

            if (data['remindBefore'] != null) {
              Map<String, dynamic> remindData = data['remindBefore'];
              int time = remindData['time'] ?? 0;
              String unit = remindData['unit'] ?? 'minutes';
              remindBefore = reminder_payload.RemindBefore(
                time: time,
                unit: unit,
              );
              debugPrint("event remind me before $time and $unit");
            }
          }

          combined.add(
            reminder_payload.ReminderPayloadModel(
              id: alarm.id,
              category: "event",
              title: title,
              customReminder: reminder_payload.CustomReminder(
                timesPerDay: reminder_payload.TimesPerDay(
                  count: 1.toString(),
                  list: [alarm.dateTime.toString()],
                ),
              ),
              remindBefore: remindBefore,
              startDate: startDate,
              notes: alarm.notificationSettings.body,
            ),
          );
          print(("event combined ${combined.last}"));
        });
      }

      for (var item in waterController.waterList) {
        print(
          '➕ Add Water → '
          'id=${item.id}, '
          'title=${item.title}, '
          'alarms=${item.alarms.length}, '
          'start_water_time=${item.waterReminderStartTime}, '
          'end_water_time=${item.waterReminderEndTime}, '
          'timesPerDay=${item.timesPerDay}, '
          'interval=${item.interval}, '
          'type=${item.type.name}',
        );

        final bool isTimesBased = item.type == Option.times;
        final bool isIntervalBased = item.type == Option.interval;

        combined.add(
          reminder_payload.ReminderPayloadModel(
            id: item.id,
            category: "water",
            title: item.title,
            // ✅ FIXED
            customReminder: reminder_payload.CustomReminder(
              type: item.type, // ✅ FIXED
              timesPerDay:
                  isTimesBased
                      ? reminder_payload.TimesPerDay(
                        count: item.timesPerDay,
                        list: [],
                      )
                      : null,
              everyXHours:
                  isIntervalBased
                      ? reminder_payload.EveryXHours(
                        hours: int.parse(item.interval ?? ''),
                        // SAFE because type enforces it
                        startTime: '',
                        endTime: '',
                      )
                      : null,
            ),
            startWaterTime: item.waterReminderStartTime,
            endWaterTime: item.waterReminderEndTime,
          ),
        );
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
      var reminders = result as List<reminder_payload.ReminderPayloadModel>;
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

  // Future<void> addRemindertoAPI(
  //   reminder_payload.ReminderPayloadModel reminderData,
  //   BuildContext context,
  // ) async {
  //   try {
  //     final response = await ApiService.post(
  //       addreminderApi,
  //       reminderData.toJson(),
  //       withAuth: true,
  //       encryptionRequired: true,
  //     );
  //
  //     print("response addRemindertoAPI $response");
  //
  //     if (response is http.Response && response.statusCode >= 400) {
  //       CustomSnackbar.showError(
  //         context: context,
  //         title: 'Error',
  //         message: 'Failed to save Reminder record: ${response.statusCode}',
  //       );
  //     }
  //     // else {
  //     //   await getReminders(context);
  //     // }
  //   } catch (e) {
  //     debugPrint("Exception while saving Reminder record: $e");
  //   }
  // }

  Future<void> updateReminder(
    reminder_payload.ReminderPayloadModel reminderData,
    BuildContext context,
  ) async {
    try {
      final response = await ApiService.post(
        editreminderApi,
        reminderData.toJson(),
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

  Future<bool> validateAndSave({
    required BuildContext context,
    num? dosage,
  }) async {
    debugPrint("🟢 validateAndSave() called");
    debugPrint("📂 Selected category: ${selectedCategory.value}");
    debugPrint("✏️ Title: '${titleController.text}'");
    debugPrint("🧪 Dosage: $dosage");

    final isSelected =
        medicineGetxController.medicineRemindMeBeforeOption.value == 0;

    debugPrint("⏳ Medicine remind-before selected: $isSelected");

    if (isSelected) {
      debugPrint("➡️ Handling medicine remind-before");
      await handleRemindMeBefore(
        option: medicineGetxController.medicineRemindMeBeforeOption,
        timeBefore: medicineGetxController.medicineTimeBeforeController.text,
        timeOfDay: pickedTime.value,
        timeController: xTimeUnitController,
        unitController: selectedValue,
        category: "medicine",
        title: "Upcoming Medicine Reminder",
        body: "It’s almost time to take your medicine in ",
      );
    }

    final isSelectedEvent = eventGetxController.eventRemindMeBefore.value == 0;

    debugPrint("⏳ Event remind-before selected: $isSelectedEvent");

    if (isSelectedEvent) {
      debugPrint("➡️ Handling event validate and save remind-before");
      await handleRemindMeBefore(
        option: eventGetxController.eventRemindMeBefore,
        timeOfDay: pickedTime.value,
        timeBefore: eventGetxController.eventTimeBeforeController.text,
        timeController: eventGetxController.eventTimeBeforeController,
        unitController: selectedValue,
        title: "Upcoming Event Reminder",
        body: "Your scheduled event will start in ",
        category: "event",
      );
    }

    // ---------------------------------------------------------------------------
    // Basic validation
    // ---------------------------------------------------------------------------

    if (titleController.text.trim().isEmpty) {
      debugPrint("❌ Validation failed: title is empty");

      Get.snackbar(
        "Almost there",
        "Add a title for your ${selectedCategory.value} reminder",
        snackPosition: SnackPosition.TOP,
        colorText: white,
        backgroundColor: AppColors.primaryColor,
        duration: const Duration(seconds: 2),
      );
      return false;
    }

    if (titleController.text.trim().length >= maxTitleLength) {
      debugPrint("❌ Validation failed: title too long");

      Get.snackbar(
        "Title too long",
        "You can keep the title short and add extra details in Notes",
        snackPosition: SnackPosition.TOP,
        colorText: white,
        backgroundColor: AppColors.primaryColor,
        duration: const Duration(seconds: 2),
      );
      return false;
    }

    final isInterval =
        medicineGetxController.medicineReminderOption.value == Option.interval;

    debugPrint("⏱ Is interval mode (medicine): $isInterval");

    if (!isInterval && pickedTime.value == null) {
      debugPrint("❌ Validation failed: pickedTime is null");

      Get.snackbar(
        "Almost there",
        "Pick a time for your ${selectedCategory.value} reminder",
        snackPosition: SnackPosition.TOP,
        colorText: white,
        backgroundColor: AppColors.primaryColor,
        duration: const Duration(seconds: 2),
      );
      return false;
    }

    // ---------------------------------------------------------------------------
    // Edit mode
    // ---------------------------------------------------------------------------

    if (editingId.value != null) {
      debugPrint("✏️ Editing existing reminder → id=${editingId.value}");

      updateReminderFromLocal(
        context,
        id: editingId.value,
        category: selectedCategory.value,
        timeOfDay: pickedTime.value!,
      );
      return true;
    }

    // ---------------------------------------------------------------------------
    // Category-specific validation
    // ---------------------------------------------------------------------------

    if (selectedCategory.value == "medicine") {
      if (dosage == null || dosage <= 0) {
        debugPrint("❌ Validation failed: invalid dosage");

        Get.snackbar(
          "Oops!",
          "That dosage doesn’t look right. Please enter a valid one.",
          snackPosition: SnackPosition.TOP,
          colorText: white,
          backgroundColor: AppColors.primaryColor,
          duration: const Duration(seconds: 2),
        );
        return false;
      }
    }

    // ---------------------------------------------------------------------------
    // Category switch
    // ---------------------------------------------------------------------------

    debugPrint("🚦 Processing category: ${selectedCategory.value}");

    switch (selectedCategory.value) {
      case "medicine":
        final isInterval =
            medicineGetxController.medicineReminderOption.value ==
            Option.interval;

        debugPrint("💊 Medicine reminder | Interval=$isInterval");

        if (!isInterval) {
          final expectedTimes =
              medicineGetxController.getEffectiveTimesPerDay();

          final filledTimes =
              medicineGetxController.timeControllers
                  .where((ctrl) => ctrl.text.trim().isNotEmpty)
                  .length;

          debugPrint(
            "⏰ Medicine times filled=$filledTimes expected=$expectedTimes",
          );

          if (filledTimes < expectedTimes) {
            final missing = expectedTimes - filledTimes;

            debugPrint("❌ Missing $missing medicine time(s)");

            Get.snackbar(
              "Missing time${missing > 1 ? 's' : ''}",
              "You selected '${medicineGetxController.selectedFrequency.value}'. "
                  "Please add $missing more time${missing > 1 ? 's' : ''}.",
              snackPosition: SnackPosition.TOP,
              colorText: white,
              backgroundColor: AppColors.primaryColor,
              duration: const Duration(seconds: 3),
            );

            return false;
          }
          debugPrint("✅ Adding medicine times-based alarm");
          final ok = await medicineGetxController.addMedicineAlarm(
            context: context,
            dosage: dosage,
          );
          if (!ok) {
            return false;
          }
        } else {
          debugPrint("⏱ Processing medicine interval alarm");

          if (medicineGetxController.startMedicineTimeController.text
                  .trim()
                  .isEmpty ||
              medicineGetxController.endMedicineTimeController.text
                  .trim()
                  .isEmpty) {
            debugPrint("❌ Missing start/end time for interval");

            Get.snackbar(
              "Missing time",
              "Please select both start and end time for interval reminders.",
              snackPosition: SnackPosition.TOP,
              colorText: white,
              backgroundColor: AppColors.primaryColor,
              duration: const Duration(seconds: 3),
            );
            return false;
          }

          final ok = await medicineGetxController.addMedicineIntervalAlarm(
            context: context,
            dosage: dosage,
          );
          if (!ok) {
            return false;
          }
        }
        break;

      case "meal":
      case "event":
        debugPrint("🍽️ / 📅 Adding ${selectedCategory.value} alarm");

        addAlarm(
          context,
          timeOfDay: pickedTime.value!,
          category: selectedCategory.value,
        );
        break;

      case "water":
        debugPrint("💧 Delegating to WaterController");
        final ok = await waterController.validateAndSaveWaterReminder(context);
        if (!ok) {
          return false;
        }
        break;

      default:
        debugPrint("⚠️ Unknown category: ${selectedCategory.value}");
    }

    debugPrint("✅ validateAndSave() completed successfully");
    return true;
  }

  Future<bool> validateAndUpdate({
    required BuildContext context,
    num? dosage,
    required reminder_payload.ReminderPayloadModel reminder,
  }) async {
    final category = selectedCategory.value.trim().toLowerCase();

    if (titleController.text.trim().isEmpty) {
      Get.snackbar(
        "Almost there",
        "Add a title for your ${selectedCategory.value} reminder",
        snackPosition: SnackPosition.TOP,
        colorText: white,
        backgroundColor: AppColors.primaryColor,
        duration: const Duration(seconds: 2),
      );
      return false;
    }

    if (titleController.text.trim().length >= maxTitleLength) {
      Get.snackbar(
        "Title too long",
        "You can keep the title short and add extra details in Notes",
        snackPosition: SnackPosition.TOP,
        colorText: white,
        backgroundColor: AppColors.primaryColor,
        duration: const Duration(seconds: 2),
      );
      return false;
    }

    switch (category) {
      case "medicine":
        if (dosage == null || dosage <= 0) {
          Get.snackbar(
            "Oops!",
            "That dosage doesn’t look right. Please enter a valid one.",
            snackPosition: SnackPosition.TOP,
            colorText: white,
            backgroundColor: AppColors.primaryColor,
            duration: const Duration(seconds: 2),
          );
          return false;
        }

        final isInterval =
            medicineGetxController.medicineReminderOption.value ==
            Option.interval;

        if (!isInterval) {
          final expectedTimes =
              medicineGetxController.getEffectiveTimesPerDay();
          final filledTimes =
              medicineGetxController.timeControllers
                  .where((ctrl) => ctrl.text.trim().isNotEmpty)
                  .length;

          if (filledTimes < expectedTimes) {
            final missing = expectedTimes - filledTimes;
            Get.snackbar(
              "Missing time${missing > 1 ? 's' : ''}",
              "You selected '${medicineGetxController.selectedFrequency.value}'. "
                  "Please add $missing more time${missing > 1 ? 's' : ''}.",
              snackPosition: SnackPosition.TOP,
              colorText: white,
              backgroundColor: AppColors.primaryColor,
              duration: const Duration(seconds: 3),
            );
            return false;
          }
        } else {
          if (medicineGetxController.startMedicineTimeController.text
                  .trim()
                  .isEmpty ||
              medicineGetxController.endMedicineTimeController.text
                  .trim()
                  .isEmpty) {
            Get.snackbar(
              "Missing time",
              "Please select both start and end time for interval reminders.",
              snackPosition: SnackPosition.TOP,
              colorText: white,
              backgroundColor: AppColors.primaryColor,
              duration: const Duration(seconds: 3),
            );
            return false;
          }
        }

        return _updateMedicineReminderLocally(
          context: context,
          dosage: dosage,
          reminderId: reminder?.id ?? 0000,
        );

      case "water":
        waterController.waterList.value = await waterController
            .loadWaterReminderList("water_list");
        await waterController.deleteWaterReminder(reminder?.id ?? 000);
        return waterController.validateAndSaveWaterReminder(context);

      case "meal":
      case "event":
        if (pickedTime.value == null) {
          Get.snackbar(
            "Almost there",
            "Pick a time for your ${selectedCategory.value} reminder",
            snackPosition: SnackPosition.TOP,
            colorText: white,
            backgroundColor: AppColors.primaryColor,
            duration: const Duration(seconds: 2),
          );
          return false;
        }

        await updateReminderFromLocal(
          context,
          id: reminder?.id.toString() ?? '',
          category: category,
          timeOfDay: pickedTime.value!,
        );
        return true;

      default:
        Get.snackbar(
          "Error",
          "Unsupported reminder category: ${selectedCategory.value}",
          snackPosition: SnackPosition.TOP,
          colorText: white,
          backgroundColor: AppColors.primaryColor,
          duration: const Duration(seconds: 2),
        );
        return false;
    }
  }

  Future<bool> _updateMedicineReminderLocally({
    required BuildContext context,
    required num? dosage,
    required int reminderId,
  }) async {
    if (reminderId == 0000) {
      return false;
    }
    final isInterval =
        medicineGetxController.medicineReminderOption.value == Option.interval;
    final medicineName = medicineGetxController.medicineController.text.trim();
    if (medicineName.isEmpty) {
      Get.snackbar(
        "Medicine name missing",
        "Please enter the medicine name to continue.",
        snackPosition: SnackPosition.TOP,
        colorText: white,
        backgroundColor: AppColors.primaryColor,
        duration: const Duration(seconds: 2),
      );
      return false;
    }

    medicineGetxController.medicineList.value = await medicineGetxController
        .loadMedicineReminderList("medicine_list");
    final index = medicineGetxController.medicineList.indexWhere(
      (e) => e.id == reminderId,
    );
    if (index == -1) {
      return false;
    }

    final oldModel = medicineGetxController.medicineList[index];
    final existingAlarmIds =
        oldModel.alarmIds.isNotEmpty ? [...oldModel.alarmIds] : [oldModel.id];

    final targetTimes = <DateTime>[];
    if (isInterval) {
      final intervalHours =
          int.tryParse(
            medicineGetxController.everyHourController.text.trim(),
          ) ??
          0;
      if (intervalHours <= 0) {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Please enter a valid hours interval',
        );
        return false;
      }

      final start = stringToTimeOfDay(
        medicineGetxController.startMedicineTimeController.text.trim(),
      );
      final end = stringToTimeOfDay(
        medicineGetxController.endMedicineTimeController.text.trim(),
      );
      targetTimes.addAll(
        medicineGetxController.generateEveryXHours(
          start: start,
          end: end,
          intervalHours: intervalHours,
        ),
      );
    } else {
      final baseDate = startDate.value ?? DateTime.now();
      for (final controller in medicineGetxController.timeControllers) {
        final rawTime = controller.text.trim();
        if (rawTime.isEmpty) continue;
        try {
          final tod = stringToTimeOfDay(rawTime);
          var scheduled = DateTime(
            baseDate.year,
            baseDate.month,
            baseDate.day,
            tod.hour,
            tod.minute,
          );
          if (scheduled.isBefore(DateTime.now())) {
            scheduled = scheduled.add(const Duration(days: 1));
          }
          targetTimes.add(scheduled);
        } catch (_) {}
      }
    }

    if (targetTimes.isEmpty) {
      Get.snackbar(
        "Missing time",
        "Please add at least one valid medicine time.",
        snackPosition: SnackPosition.TOP,
        colorText: white,
        backgroundColor: AppColors.primaryColor,
        duration: const Duration(seconds: 2),
      );
      return false;
    }

    final title = titleController.text.trim();
    final notes = notesController.text.trim();
    final medicineType = medicineGetxController.selectedType.value;
    final unit = medicineGetxController.typeToDosage[medicineType] ?? 'DROP';
    final normalizedStartDate =
        medicineGetxController.startDateString.value == 'Start Date'
            ? ''
            : medicineGetxController.startDateString.value;
    final normalizedEndDate =
        medicineGetxController.endDateString.value == 'End Date'
            ? ''
            : medicineGetxController.endDateString.value;
    final timesPerDay = medicineGetxController.getEffectiveTimesPerDay();
    final everyXHours = medicineGetxController.everyHourController.text.trim();
    final reminderFrequencyType =
        medicineGetxController.selectedFrequency.value;
    final medicineFrequencyPerDay =
        medicineGetxController
            .frequencyNum[medicineGetxController.selectedFrequency.value]
            .toString();
    final startTime =
        medicineGetxController.startMedicineTimeController.text.trim();
    final endTime =
        medicineGetxController.endMedicineTimeController.text.trim();
    final list =
        medicineGetxController.timeControllers
            .map((controller) => controller.text.trim())
            .where((e) => e.isNotEmpty)
            .toList();

    final updatedAlarmIds = <int>[];
    for (var i = 0; i < targetTimes.length; i++) {
      final alarmId =
          i < existingAlarmIds.length ? existingAlarmIds[i] : alarmsId();
      final alarmSettings = AlarmSettings(
        id: alarmId,
        dateTime: targetTimes[i],
        assetAudioPath: alarmSound,
        loopAudio: true,
        vibrate: true,
        androidFullScreenIntent: true,
        volumeSettings: VolumeSettings.fade(
          volume: 0.8,
          fadeDuration: const Duration(seconds: 5),
          volumeEnforced: true,
        ),
        payload: jsonEncode({
          "groupId": reminderId.toString(),
          "category": ReminderCategory.medicine.toString(),
          "type": isInterval ? "interval" : "times",
        }),
        notificationSettings: NotificationSettings(
          title: title.isNotEmpty ? title : 'MEDICINE REMINDER',
          body: medicineGetxController.buildMedicineNotificationText(
            medicineName: medicineName,
            dosage: dosage ?? 0,
          ),
          stopButton: 'Stop',
          icon: 'alarm',
          iconColor: AppColors.primaryColor,
        ),
      );
      final success = await Alarm.set(alarmSettings: alarmSettings);
      if (success) {
        updatedAlarmIds.add(alarmId);
      }
    }

    for (var i = targetTimes.length; i < existingAlarmIds.length; i++) {
      await Alarm.stop(existingAlarmIds[i]);
    }

    if (updatedAlarmIds.isEmpty) {
      return false;
    }

    medicine_payload.CustomReminder customReminder;
    if (isInterval) {
      customReminder = medicine_payload.CustomReminder(
        type: Option.interval,
        timesPerDay: null,
        everyXHours: medicine_payload.EveryXHours(
          hours: everyXHours,
          startTime: startTime,
          endTime: endTime,
        ),
      );
    } else {
      customReminder = medicine_payload.CustomReminder(
        type: Option.times,
        timesPerDay: medicine_payload.TimesPerDay(
          count: timesPerDay.toString(),
          list: list,
        ),
        everyXHours: null,
      );
    }

    final updatedModel = medicine_payload.MedicineReminderModel(
      id: reminderId,
      alarmIds: updatedAlarmIds,
      title: title,
      category: ReminderCategory.medicine.toString(),
      medicineName: medicineName,
      medicineType: medicineType,
      whenToTake: medicineGetxController.selectedWhenToTake.value,
      dosage: medicine_payload.Dosage(value: dosage ?? 0, unit: unit),
      medicineFrequencyPerDay: medicineFrequencyPerDay,
      reminderFrequencyType: reminderFrequencyType,
      customReminder: customReminder,
      remindBefore: medicineGetxController.buildRemindBefore(),
      startDate: normalizedStartDate,
      endDate: normalizedEndDate,
      notes: notes,
    );

    medicineGetxController.medicineList[index] = updatedModel;
    await saveReminderList(
      medicineGetxController.medicineList,
      "medicine_list",
    );
    await loadAllReminderLists();
    CustomSnackbar().showReminderBar(context);
    Get.back(result: true);
    return true;
  }

  Future<void> refreshAllData(BuildContext context) async {
    await loadAllReminderLists();
  }

  String getCategoryIcon(String category) {
    switch (category) {
      case 'medicine':
        return medicineIcon;
      case 'water':
        return waterReminderIcon;
      case 'meal':
        return mealIcon;
      case 'event':
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

  void loadReminderData(reminder_payload.ReminderPayloadModel reminder) {
    debugPrint("━━━━━━━━━━ LOAD REMINDER DATA ━━━━━━━━━━");
    debugPrint("Reminder ID: ${reminder.id}");
    debugPrint("Title: ${reminder.title}");
    debugPrint("Category: ${reminder.category}");
    debugPrint("Notes: ${reminder.notes}");
    debugPrint(
      "Start Time Interval: ${reminder.customReminder.everyXHours?.startTime}",
    );
    debugPrint(
      "End Time Interval: ${reminder.customReminder.everyXHours?.endTime}",
    );

    debugPrint("Medicine Name: ${reminder.medicineName}");
    debugPrint("Start Date: ${reminder.startDate}");
    debugPrint("Custom Reminder: ${reminder.customReminder}");

    // Basic fields
    titleController.text = reminder.title ?? '';
    notesController.text = reminder.notes ?? '';
    selectedCategory.value = reminder.category;
    editingId.value = reminder.id;

    debugPrint("→ titleController.text: ${titleController.text}");
    debugPrint("→ notesController.text: ${notesController.text}");
    debugPrint("→ selectedCategory: ${selectedCategory.value}");
    debugPrint("→ editingId: ${editingId.value}");

    // Medicine
    if (reminder.category == 'Medicine') {
      medicineGetxController.medicineController.text =
          reminder.medicineName ?? '';
      debugPrint(
        "→ medicineController.text: ${medicineGetxController.medicineController.text}",
      );
    }

    // Start date (SAFE)
    startDate.value =
        reminder.startDate != null && reminder.startDate!.isNotEmpty
            ? DateTime.tryParse(reminder.startDate!)
            : null;
    debugPrint("→ startDate.value: ${startDate.value}");

    // Water reminder
    if (reminder.category == ReminderCategory.water.name) {
      final custom = reminder.customReminder;
      debugPrint("→ Water reminder custom: $custom");

      if (waterController.waterReminderOption.value == Option.interval) {
        waterController.everyHourController.text =
            custom?.everyXHours?.hours.toString() ?? '';
        debugPrint(
          "→ everyHourController.text: ${waterController.everyHourController.text}",
        );
      }

      if (waterController.waterReminderOption.value == Option.times) {
        waterController.timesPerDayController.text =
            custom?.timesPerDay?.count.toString() ?? '';
        debugPrint(
          "→ timesPerDayController.text: ${waterController.timesPerDayController.text}",
        );
      }
    }
    debugPrint("━━━━━━━━━━ END LOAD REMINDER DATA ━━━━━━━━━━");
  }
}
