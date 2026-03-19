import 'dart:async';
import 'package:flutter/widgets.dart';
import 'dart:convert';

import 'package:alarm/alarm.dart';
import 'package:alarm/model/alarm_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
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
import 'package:snevva/services/reminder/reminder_scheduler.dart';

import '../../common/global_variables.dart';
import '../../models/reminders/medicine_reminder_model.dart'
    as medicine_payload;
import '../../models/reminders/water_reminder_model.dart';
import '../../services/hive_service.dart';

List<Map<String, dynamic>> _decodeReminderEntries(List<String> encodedItems) {
  final decoded = <Map<String, dynamic>>[];
  for (final raw in encodedItems) {
    try {
      final item = jsonDecode(raw);
      if (item is Map) {
        decoded.add(Map<String, dynamic>.from(item));
      }
    } catch (_) {}
  }
  return decoded;
}

List<int> _collectExpiredBeforeAlarmIds(Map<String, dynamic> payload) {
  final now = DateTime.fromMillisecondsSinceEpoch(payload['nowEpochMs'] as int);
  final alarms = (payload['alarms'] as List).cast<Map<String, dynamic>>();
  final expiredIds = <int>[];

  for (final alarm in alarms) {
    final payloadRaw = alarm['payload'];
    if (payloadRaw is! String) continue;

    try {
      final decoded = jsonDecode(payloadRaw);
      if (decoded is! Map<String, dynamic>) continue;
      if (decoded['type'] != 'before') continue;

      final mainTimeRaw = decoded['mainTime'];
      if (mainTimeRaw is! String) continue;

      final mainTime = DateTime.tryParse(mainTimeRaw);
      if (mainTime == null) continue;

      if (now.isAfter(mainTime)) {
        final id = alarm['id'];
        if (id is int) {
          expiredIds.add(id);
        }
      }
    } catch (_) {}
  }

  return expiredIds;
}

class ReminderController extends GetxController {
  static const int _computeThreshold = 120;
  static const String _deletedReminderGroupIdsKey =
      'deleted_reminder_group_ids_v1';
  static const String _deletedReminderAlarmIdsKey =
      'deleted_reminder_alarm_ids_v1';
  bool _isSaving = false;
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runDeferredInit());
    });
  }

  Future<void> _runDeferredInit() async {
    // await checkAndroidNotificationPermission();
    await checkAndroidScheduleExactAlarmPermission();
    await cleanupExpiredBeforeAlarms();
    await loadAlarms();
    await loadAllReminderLists();
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
    if (alarms.isEmpty) return;

    final scanInput = alarms
        .where((alarm) => alarm.payload != null)
        .map(
          (alarm) => <String, dynamic>{
            'id': alarm.id,
            'payload': alarm.payload!,
          },
        )
        .toList(growable: false);

    if (scanInput.isEmpty) return;

    final payload = <String, dynamic>{
      'nowEpochMs': DateTime.now().millisecondsSinceEpoch,
      'alarms': scanInput,
    };

    final expiredIds =
        scanInput.length >= _computeThreshold
            ? await compute(_collectExpiredBeforeAlarmIds, payload)
            : _collectExpiredBeforeAlarmIds(payload);

    for (final id in expiredIds) {
      await Alarm.stop(id);
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

    final normalizedCategory = category.trim().toLowerCase();
    final resolvedTime =
        timeOfDay ?? _resolveTimeForCategory(normalizedCategory);

    var scheduledTime = DateTime(
      startDate.value?.year ?? now.year,
      startDate.value?.month ?? now.month,
      startDate.value?.day ?? now.day,
      resolvedTime?.hour ?? now.hour,
      resolvedTime?.minute ?? now.minute,
    );

    print("🕒 initial scheduledTime → $scheduledTime");

    if (scheduledTime.isBefore(now) || scheduledTime.isAtSameMomentAs(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
      print("⏭️ time was past → moved to $scheduledTime");
    }

    if (normalizedCategory == 'water') {
      await waterController.updateWaterReminderFromLocal(context, id, times);
    } else {
      print("🔁 Updating single alarm → $category with id=$id");

      switch (normalizedCategory) {
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
    CustomSnackbar().showReminderBar(context);
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

    // Persist a local "tombstone" so future API refreshes can't resurrect
    // reminders that the user explicitly deleted on-device.
    await _recordLocalDeletion(reminder);

    debugPrint('🔄 Reloading all reminder lists');
    await loadAllReminderLists();
    debugPrint('✅ deleteReminder END');
  }

  Future<void> _recordLocalDeletion(
    reminder_payload.ReminderPayloadModel reminder,
  ) async {
    final normalizedCategory = _normalizeCategory(reminder.category);
    final groupIdsToAdd = <int>{};
    final alarmIdsToAdd = <int>{};

    switch (normalizedCategory) {
      case 'medicine':
      case 'water':
        groupIdsToAdd.add(reminder.id);
        break;
      case 'meal':
      case 'event':
        // Meal/Event UI entries use alarm ids. Tombstone the current id and,
        // when possible, also tombstone the deterministic scheduled id that
        // API sync will compute (groupId + time -> alarmId).
        alarmIdsToAdd.add(reminder.id);

        final rawTimes = reminder.customReminder.timesPerDay?.list ?? const [];
        if (rawTimes.isNotEmpty) {
          final parsed = DateTime.tryParse(rawTimes.first.trim());
          if (parsed != null) {
            final scheduled = parsed.isUtc ? parsed.toLocal() : parsed;

            // 1) Treat current id as a group id (legacy local alarms use this).
            alarmIdsToAdd.add(
              ReminderScheduler.scheduledReminderId(
                reminderId: reminder.id,
                time: scheduled,
              ),
            );

            // 2) Treat current id as an encoded scheduled id and derive group id.
            final derivedGroupId = reminder.id ~/ 100000;
            if (derivedGroupId > 0) {
              alarmIdsToAdd.add(
                ReminderScheduler.scheduledReminderId(
                  reminderId: derivedGroupId,
                  time: scheduled,
                ),
              );
            }
          }
        }
        break;
      default:
        // Unknown category: do nothing.
        return;
    }

    if (groupIdsToAdd.isEmpty && alarmIdsToAdd.isEmpty) return;

    final box = await HiveService().remindersBox();
    final existingGroupIds = await _readIntSet(box, _deletedReminderGroupIdsKey);
    final existingAlarmIds = await _readIntSet(box, _deletedReminderAlarmIdsKey);

    existingGroupIds.addAll(groupIdsToAdd);
    existingAlarmIds.addAll(alarmIdsToAdd);

    await box.put(
      _deletedReminderGroupIdsKey,
      existingGroupIds.toList(growable: false),
    );
    await box.put(
      _deletedReminderAlarmIdsKey,
      existingAlarmIds.toList(growable: false),
    );
  }

  Future<Set<int>> _readIntSet(Box box, String key) async {
    final raw = box.get(key);
    if (raw is List) {
      final set = <int>{};
      for (final item in raw) {
        if (item is int) {
          set.add(item);
        } else if (item is String) {
          final parsed = int.tryParse(item);
          if (parsed != null) set.add(parsed);
        } else if (item != null) {
          final parsed = int.tryParse(item.toString());
          if (parsed != null) set.add(parsed);
        }
      }
      return set;
    }
    return <int>{};
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
    final box = await HiveService().remindersBox();
    final List<dynamic>? storedList = box.get(keyName);

    if (storedList == null) {
      print('⚠️ No data found for $keyName');
      return [];
    }

    print('📄 Raw list length [$keyName]: ${storedList.length}');

    final List<String> stringList = storedList.cast<String>();
    final decodedEntries =
        stringList.length >= _computeThreshold
            ? await compute(_decodeReminderEntries, stringList)
            : _decodeReminderEntries(stringList);

    final result = <Map<String, AlarmSettings>>[];
    for (final decoded in decodedEntries) {
      final mapped = <String, AlarmSettings>{};
      decoded.forEach((key, value) {
        if (value is Map) {
          mapped[key] = AlarmSettings.fromJson(
            Map<String, dynamic>.from(value),
          );
        }
      });
      result.add(mapped);
    }

    print('✅ Loaded ${result.length} alarms for $keyName');
    return result;
  }

  Future<void> saveReminderList(RxList<dynamic> list, String keyName) async {
    print('💾 Saving reminders → key: $keyName');
    print('📦 Total items to save: ${list.length}');

    // final box = Hive.box('reminders_box');
    final box = await HiveService().remindersBox();

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
      await getReminderFromAPI(context);
    } catch (e) {
      print("Error fetching reminders");
    } finally {
      isLoading(false);
    }
  }

  Future<List<reminder_payload.ReminderPayloadModel>> getReminderFromAPI(BuildContext context) async {
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
      final decodedBody = jsonDecode(enc);
      final List remindersList = decodedBody['data']['Reminders'] as List;

      final List<reminder_payload.ReminderPayloadModel> reminders = remindersList
          .map((e) {
        final map = e as Map<String, dynamic>;

        if (map['Category'] != null && map['Category'] is String) {
          map['Category'] =
              map['Category'][0].toLowerCase() + map['Category'].substring(1);
        }

        return reminder_payload.ReminderPayloadModel.fromJson(map);
      })
          .toList();

      final box = await HiveService().remindersBox();
      final deletedGroupIds = await _readIntSet(box, _deletedReminderGroupIdsKey);
      final deletedAlarmIds = await _readIntSet(box, _deletedReminderAlarmIdsKey);

      await clearAllReminderBoxes();

      // 🔥 STEP 2: SAVE INTO CORRECT CATEGORY LISTS
      await _saveToCategoryWiseLists(
        reminders,
        deletedGroupIds: deletedGroupIds,
        deletedAlarmIds: deletedAlarmIds,
      );

      // Ensure UI reflects persisted (and filtered) state, not raw API payload.
      await loadAllReminderLists();

      logLong("getRemindersFromAPI", reminders.toString());
      // Scheduling many alarms can take time and shouldn't block the caller
      // (e.g. post-login flow), otherwise UI loaders may appear "stuck".
      unawaited(
        ReminderScheduler().scheduleAll(
          reminders,
          deletedGroupIds: deletedGroupIds,
          deletedAlarmIds: deletedAlarmIds,
        ),
      );
      return reminders;
    } catch (e) {
      return [];
    }
  }

  Future<void> clearAllReminderBoxes() async {
    final box = await HiveService().remindersBox();
    await box.delete("meals_list");
    await box.delete("event_list");
    await box.delete("medicine_list");
    await box.delete("water_list");

    debugPrint('All reminder boxes cleared');
  }


  Future<void> _saveToCategoryWiseLists(
    List<reminder_payload.ReminderPayloadModel> reminders, {
    Set<int> deletedGroupIds = const {},
    Set<int> deletedAlarmIds = const {},
  }) async {

    final meals = <Map<String, AlarmSettings>>[];
    final events = <Map<String, AlarmSettings>>[];
    final medicine = <medicine_payload.MedicineReminderModel>[];
    final water = <WaterReminderModel>[];

    for (final reminder in reminders) {
      final category = _normalizeCategory(reminder.category);
      try {
        switch (category) {
          case 'meal':
            // Meal alarms are stored as individual AlarmSettings entries.
            final times = _parseScheduledTimes(
              reminder.customReminder.timesPerDay?.list,
              dateHint: reminder.startDate,
            );
            if (times.isEmpty) {
              _logConversion(
                'Skip meal reminder ${reminder.id}: no valid times found.',
              );
              break;
            }
            for (var i = 0; i < times.length; i++) {
              final entry = _convertToMealMap(reminder, scheduledTime: times[i]);
              final alarmId = entry.values.first.id;
              if (deletedAlarmIds.contains(alarmId)) {
                _logConversion(
                  'Skip deleted meal occurrence (alarmId=$alarmId, groupId=${reminder.id}).',
                );
                continue;
              }
              meals.add(entry);
            }
            break;

          case 'event':
            final times = _parseScheduledTimes(
              reminder.customReminder.timesPerDay?.list,
              dateHint: reminder.startDate,
            );
            if (times.isEmpty) {
              _logConversion(
                'Skip event reminder ${reminder.id}: no valid times found.',
              );
              break;
            }
            for (var i = 0; i < times.length; i++) {
              final entry = _convertToEventMap(reminder, scheduledTime: times[i]);
              final alarmId = entry.values.first.id;
              if (deletedAlarmIds.contains(alarmId)) {
                _logConversion(
                  'Skip deleted event occurrence (alarmId=$alarmId, groupId=${reminder.id}).',
                );
                continue;
              }
              events.add(entry);
            }
            break;

          case 'medicine':
            if (deletedGroupIds.contains(reminder.id)) {
              _logConversion(
                'Skip deleted medicine reminder (groupId=${reminder.id}).',
              );
              break;
            }
            medicine.add(_convertToMedicineModel(reminder));
            break;

          case 'water':
            if (deletedGroupIds.contains(reminder.id)) {
              _logConversion(
                'Skip deleted water reminder (groupId=${reminder.id}).',
              );
              break;
            }
            water.add(_convertToWaterModel(reminder));
            break;

          default:
            _logConversion(
              'Skip reminder ${reminder.id}: unknown category "${reminder.category}".',
            );
        }
      } catch (e, s) {
        _logConversion(
          'Failed converting reminder ${reminder.id} (category="${reminder.category}"): $e',
          stackTrace: s,
        );
      }
    }

    await saveReminderList(meals.obs, "meals_list");
    await saveReminderList(events.obs, "event_list");
    await saveReminderList(medicine.obs, "medicine_list");
    await saveReminderList(water.obs, "water_list");
  }

  // ---------------------------------------------------------------------------
  // Converters (API payload -> local persisted models)
  // ---------------------------------------------------------------------------

  Map<String, AlarmSettings> _convertToMealMap(
    reminder_payload.ReminderPayloadModel reminder, {
    DateTime? scheduledTime,
  }) {
    final title = _displayTitle(
      rawTitle: reminder.title,
      fallback: 'MEAL REMINDER',
    );

    final parsedTimes = _parseScheduledTimes(
      reminder.customReminder.timesPerDay?.list,
      dateHint: reminder.startDate,
    );

    final resolvedTime =
        scheduledTime ??
        (parsedTimes.isNotEmpty ? parsedTimes.first : null) ??
        DateTime.now().add(const Duration(minutes: 1));

    final alarm = _buildAlarmSettings(
      reminderGroupId: reminder.id,
      scheduledTime: resolvedTime,
      notificationTitle: title,
      notificationBody: (reminder.notes ?? '').trim(),
      payload: jsonEncode({
        'groupId': reminder.id.toString(),
        'category': 'meal',
        'type': 'times',
      }),
    );

    return {title: alarm};
  }

  Map<String, AlarmSettings> _convertToEventMap(
    reminder_payload.ReminderPayloadModel reminder, {
    DateTime? scheduledTime,
  }) {
    final title = _displayTitle(
      rawTitle: reminder.title,
      fallback: 'EVENT REMINDER',
    );

    final parsedTimes = _parseScheduledTimes(
      reminder.customReminder.timesPerDay?.list,
      dateHint: reminder.startDate,
    );

    final resolvedTime =
        scheduledTime ??
        (parsedTimes.isNotEmpty ? parsedTimes.first : null) ??
        DateTime.now().add(const Duration(minutes: 1));

    final payload = jsonEncode({
      'groupId': reminder.id.toString(),
      'category': 'event',
      'type': 'times',
      'startDate': _normalizeIsoDate(reminder.startDate),
      'remindBefore':
          reminder.remindBefore == null
              ? null
              : {
                'time': reminder.remindBefore!.time,
                'unit': reminder.remindBefore!.unit,
              },
    });

    final alarm = _buildAlarmSettings(
      reminderGroupId: reminder.id,
      scheduledTime: resolvedTime,
      notificationTitle: title,
      notificationBody: (reminder.notes ?? '').trim(),
      payload: payload,
    );

    return {title: alarm};
  }

  medicine_payload.MedicineReminderModel _convertToMedicineModel(
    reminder_payload.ReminderPayloadModel reminder,
  ) {
    final title = _displayTitle(
      rawTitle: reminder.title,
      fallback: 'MEDICINE REMINDER',
    );

    final category = ReminderCategory.medicine.toString();
    final medicineName = (reminder.medicineName ?? '').trim();
    final medicineType = (reminder.medicineType ?? '').trim();
    final whenToTake = (reminder.whenToTake ?? '').trim();
    final notes = (reminder.notes ?? '').trim();

    if (medicineName.isEmpty || medicineType.isEmpty || whenToTake.isEmpty) {
      _logConversion(
        'Medicine reminder ${reminder.id} missing required fields '
        '(medicineName="$medicineName", medicineType="$medicineType", whenToTake="$whenToTake").',
      );
    }

    final dosage =
        reminder.dosage == null
            ? medicine_payload.Dosage(value: 0, unit: '')
            : medicine_payload.Dosage(
              value: reminder.dosage!.value,
              unit: reminder.dosage!.unit,
            );

    final payloadCustom = reminder.customReminder;
    final inferredType = _inferOption(payloadCustom);

    final medicineCustom =
        inferredType == Option.interval
            ? medicine_payload.CustomReminder(
              type: Option.interval,
              timesPerDay: null,
              everyXHours: medicine_payload.EveryXHours(
                hours: (payloadCustom.everyXHours?.hours ?? 0).toString(),
                startTime: (payloadCustom.everyXHours?.startTime ?? '').trim(),
                endTime: (payloadCustom.everyXHours?.endTime ?? '').trim(),
              ),
            )
            : medicine_payload.CustomReminder(
              type: Option.times,
              everyXHours: null,
              timesPerDay: medicine_payload.TimesPerDay(
                count: (payloadCustom.timesPerDay?.count ?? '0').toString(),
                list: _normalizeIsoDateTimes(payloadCustom.timesPerDay?.list),
              ),
            );

    final remindBefore =
        reminder.remindBefore == null
            ? null
            : medicine_payload.RemindBefore(
              time: reminder.remindBefore!.time,
              unit: reminder.remindBefore!.unit,
            );

    return medicine_payload.MedicineReminderModel(
      id: reminder.id,
      alarmIds: const [],
      title: title,
      category: category,
      medicineName: medicineName,
      medicineType: medicineType,
      whenToTake: whenToTake,
      dosage: dosage,
      medicineFrequencyPerDay: (reminder.medicineFrequencyPerDay ?? '').trim(),
      reminderFrequencyType: (reminder.reminderFrequencyType ?? '').trim(),
      customReminder: medicineCustom,
      remindBefore: remindBefore,
      startDate: _normalizeIsoDate(reminder.startDate),
      endDate: _normalizeIsoDate(reminder.endDate),
      notes: notes,
    );
  }

  WaterReminderModel _convertToWaterModel(
    reminder_payload.ReminderPayloadModel reminder,
  ) {
    final title = _displayTitle(
      rawTitle: reminder.title,
      fallback: 'WATER REMINDER',
    );

    final payloadCustom = reminder.customReminder;
    final inferredType = _inferOption(payloadCustom);

    final notes = (reminder.notes ?? '').trim();
    final start = (reminder.startWaterTime ?? '').trim();
    final end = (reminder.endWaterTime ?? '').trim();

    if (inferredType == Option.interval) {
      final hours = payloadCustom.everyXHours?.hours ?? 0;
      final intervalStart =
          (payloadCustom.everyXHours?.startTime ?? start).trim();
      final intervalEnd = (payloadCustom.everyXHours?.endTime ?? end).trim();

      final alarms = _buildWaterAlarmsForInterval(
        reminderGroupId: reminder.id,
        title: title,
        body: notes.isNotEmpty ? notes : 'Time to drink water!',
        intervalHours: hours,
        startTime: intervalStart,
        endTime: intervalEnd,
      );

      return WaterReminderModel(
        id: reminder.id,
        title: title,
        category: ReminderCategory.water.name,
        type: Option.interval,
        alarms: alarms,
        timesPerDay: '',
        waterReminderStartTime: intervalStart.isNotEmpty ? intervalStart : start,
        waterReminderEndTime: intervalEnd.isNotEmpty ? intervalEnd : end,
        interval: hours.toString(),
        notes: notes,
      );
    }

    final countRaw = payloadCustom.timesPerDay?.count?.toString() ?? '0';
    final timesPerDay = (int.tryParse(countRaw) ?? 0).clamp(0, 200);

    final alarms = _buildWaterAlarmsForTimes(
      reminderGroupId: reminder.id,
      title: title,
      body: notes.isNotEmpty ? notes : 'Time to drink water!',
      timesPerDay: timesPerDay,
      startTime: start,
      endTime: end,
      explicitTimes: payloadCustom.timesPerDay?.list,
    );

    return WaterReminderModel(
      id: reminder.id,
      title: title,
      category: ReminderCategory.water.name,
      type: Option.times,
      alarms: alarms,
      timesPerDay: timesPerDay.toString(),
      waterReminderStartTime: start.isNotEmpty ? start : '08:00 AM',
      waterReminderEndTime: end.isNotEmpty ? end : '10:00 PM',
      notes: notes,
    );
  }

  // ---------------------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------------------

  void _logConversion(
    String message, {
    StackTrace? stackTrace,
  }) {
    if (!kDebugMode) return;
    debugPrint('[ReminderPayloadMapper] $message');
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }

  String _normalizeCategory(String raw) => raw.trim().toLowerCase();

  Option _inferOption(reminder_payload.CustomReminder custom) {
    if (custom.type != null) return custom.type!;
    if (custom.everyXHours != null) return Option.interval;
    return Option.times;
  }

  String _displayTitle({required String rawTitle, required String fallback}) {
    final trimmed = rawTitle.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  AlarmSettings _buildAlarmSettings({
    required int reminderGroupId,
    required DateTime scheduledTime,
    required String notificationTitle,
    required String notificationBody,
    required String? payload,
  }) {
    return AlarmSettings(
      id: ReminderScheduler.scheduledReminderId(
        reminderId: reminderGroupId,
        time: scheduledTime,
      ),
      dateTime: scheduledTime,
      assetAudioPath: alarmSound,
      androidFullScreenIntent: true,
      volumeSettings: VolumeSettings.fade(
        volume: 0.8,
        fadeDuration: const Duration(seconds: 5),
        volumeEnforced: true,
      ),
      payload: payload,
      notificationSettings: NotificationSettings(
        title: notificationTitle,
        body: notificationBody,
        stopButton: 'Stop',
        icon: 'alarm',
        iconColor: AppColors.primaryColor,
      ),
    );
  }

  List<DateTime> _parseScheduledTimes(
    List<String>? rawTimes, {
    String? dateHint,
  }) {
    if (rawTimes == null || rawTimes.isEmpty) return const [];
    final parsed = <DateTime>[];
    for (final raw in rawTimes) {
      final dt = _tryParseDateTime(raw, dateHint: dateHint);
      if (dt != null) parsed.add(dt);
    }
    return parsed;
  }

  DateTime? _tryParseDateTime(String raw, {String? dateHint}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    // 1) Full datetime (ISO or Dart's DateTime.toString() format).
    final parsedDirect = DateTime.tryParse(trimmed);
    if (parsedDirect != null) {
      return parsedDirect.isUtc ? parsedDirect.toLocal() : parsedDirect;
    }

    // 2) "hh:mm a" (AM/PM).
    final hasMeridiem = RegExp(
      r'\b(am|pm)\b',
      caseSensitive: false,
    ).hasMatch(trimmed.replaceAll('.', ''));
    if (hasMeridiem) {
      final tod = _tryParseTimeOfDay(trimmed);
      if (tod == null) return null;
      return _combineWithDateHint(tod, dateHint: dateHint);
    }

    // 3) "HH:mm" (24h).
    final parts = trimmed.split(':');
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) return null;
      final tod = TimeOfDay(hour: hour, minute: minute);
      return _combineWithDateHint(tod, dateHint: dateHint);
    }

    return null;
  }

  TimeOfDay? _tryParseTimeOfDay(String raw) {
    try {
      return parseTimeNew(raw);
    } catch (_) {
      return null;
    }
  }

  DateTime _combineWithDateHint(TimeOfDay time, {String? dateHint}) {
    final hint = (dateHint ?? '').trim();
    if (hint.isNotEmpty) {
      final parsed = DateTime.tryParse(hint);
      if (parsed != null) {
        final local = parsed.isUtc ? parsed.toLocal() : parsed;
        return DateTime(
          local.year,
          local.month,
          local.day,
          time.hour,
          time.minute,
        );
      }
    }

    final nowLocal = DateTime.now();
    var scheduled = DateTime(
      nowLocal.year,
      nowLocal.month,
      nowLocal.day,
      time.hour,
      time.minute,
    );
    if (scheduled.isBefore(nowLocal)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  String _normalizeIsoDate(String? raw) {
    final trimmed = (raw ?? '').trim();
    if (trimmed.isEmpty) return '';
    final parsed = DateTime.tryParse(trimmed);
    if (parsed == null) return trimmed;
    final local = parsed.isUtc ? parsed.toLocal() : parsed;
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  List<String> _normalizeIsoDateTimes(List<String>? rawTimes) {
    if (rawTimes == null || rawTimes.isEmpty) return const [];
    final normalized = <String>[];
    for (final raw in rawTimes) {
      final dt = DateTime.tryParse(raw.trim());
      if (dt == null) continue;
      final local = dt.isUtc ? dt.toLocal() : dt;
      normalized.add(local.toIso8601String());
    }
    return normalized;
  }

  List<AlarmSettings> _buildWaterAlarmsForTimes({
    required int reminderGroupId,
    required String title,
    required String body,
    required int timesPerDay,
    required String startTime,
    required String endTime,
    required List<String>? explicitTimes,
  }) {
    final times =
        explicitTimes != null && explicitTimes.isNotEmpty
            ? _parseScheduledTimes(explicitTimes)
                .map(_nextDailyOccurrence)
                .toList()
            : _generateTimesBetween(
              startTime: startTime,
              endTime: endTime,
              times: timesPerDay,
            ).map(_nextDailyOccurrence).toList();

    return times
        .map(
          (t) => AlarmSettings(
            id: ReminderScheduler.scheduledReminderId(
              reminderId: reminderGroupId,
              time: t,
            ),
            dateTime: t,
            assetAudioPath: alarmSound,
            loopAudio: false,
            androidFullScreenIntent: true,
            volumeSettings: VolumeSettings.fade(
              volume: 0.8,
              fadeDuration: const Duration(seconds: 5),
              volumeEnforced: true,
            ),
            payload: jsonEncode({
              'groupId': reminderGroupId.toString(),
              'type': 'times',
              'category': ReminderCategory.water.name,
            }),
            notificationSettings: NotificationSettings(
              title: title,
              body: body,
              stopButton: 'Stop',
              icon: 'alarm',
              iconColor: AppColors.primaryColor,
            ),
          ),
        )
        .toList();
  }

  List<AlarmSettings> _buildWaterAlarmsForInterval({
    required int reminderGroupId,
    required String title,
    required String body,
    required int intervalHours,
    required String startTime,
    required String endTime,
  }) {
    final start = _tryParseTimeOfDay(startTime);
    final end = _tryParseTimeOfDay(endTime);
    if (start == null || end == null || intervalHours <= 0) return const [];

    final times = _generateEveryXHours(
      start: start,
      end: end,
      intervalHours: intervalHours,
    ).map(_nextDailyOccurrence).toList();

    return times
        .map(
          (t) => AlarmSettings(
            id: ReminderScheduler.scheduledReminderId(
              reminderId: reminderGroupId,
              time: t,
            ),
            dateTime: t,
            assetAudioPath: alarmSound,
            loopAudio: false,
            androidFullScreenIntent: true,
            volumeSettings: VolumeSettings.fade(
              volume: 0.8,
              fadeDuration: const Duration(seconds: 5),
              volumeEnforced: true,
            ),
            payload: jsonEncode({
              'groupId': reminderGroupId.toString(),
              'type': 'interval',
              'category': ReminderCategory.water.name,
            }),
            notificationSettings: NotificationSettings(
              title: title,
              body: body,
              stopButton: 'Stop',
              icon: 'alarm',
              iconColor: AppColors.primaryColor,
            ),
          ),
        )
        .toList();
  }

  DateTime _nextDailyOccurrence(DateTime original) {
    final nowLocal = DateTime.now();
    var scheduled = DateTime(
      nowLocal.year,
      nowLocal.month,
      nowLocal.day,
      original.hour,
      original.minute,
    );
    if (scheduled.isBefore(nowLocal)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  List<DateTime> _generateTimesBetween({
    required String startTime,
    required String endTime,
    required int times,
  }) {
    if (times <= 0) return const [];
    final start = _tryParseTimeOfDay(startTime);
    final end = _tryParseTimeOfDay(endTime);
    if (start == null || end == null) return const [];

    var startDT = toDateTimeToday(start);
    var endDT = toDateTimeToday(end);
    if (endDT.isBefore(startDT)) {
      endDT = endDT.add(const Duration(days: 1));
    }

    final totalMinutes = endDT.difference(startDT).inMinutes;
    if (totalMinutes <= 0) return [startDT];

    final gap = (totalMinutes / times).floor().clamp(1, totalMinutes);
    return List.generate(
      times,
      (i) => startDT.add(Duration(minutes: gap * i)),
    );
  }

  List<DateTime> _generateEveryXHours({
    required TimeOfDay start,
    required TimeOfDay end,
    required int intervalHours,
  }) {
    if (intervalHours <= 0) return const [];
    final window = buildTimeWindow(start, end);
    final reminders = <DateTime>[];

    DateTime current = window.start.add(Duration(hours: intervalHours));
    int counter = 0;
    while (!current.isAfter(window.end)) {
      reminders.add(current);
      current = current.add(Duration(hours: intervalHours));
      counter++;
      if (counter > 100) break;
    }

    return reminders;
  }

  Future<void> _reloadAllControllers() async {
    mealController.mealsList.value =
    await loadReminderList("meals_list");

    eventGetxController.eventList.value =
    await loadReminderList("event_list");

    medicineGetxController.medicineList.value =
    await medicineGetxController.loadMedicineReminderList("medicine_list");

    waterController.waterList.value =
    await waterController.loadWaterReminderList("water_list");
  }

  Future<void> addRemindertoAPI(
      reminder_payload.ReminderPayloadModel reminderData,
      BuildContext context,
      ) async {
    try {
      if (kDebugMode) {
        debugPrint("🚀 addRemindertoAPI called");
        debugPrint("📦 Payload: ${reminderData.toJson()}");
        debugPrint("🌐 Hitting API: $addreminderApi");
      }

      final response = await ApiService.post(
        addreminderApi,
        reminderData.toJson(),
        withAuth: true,
        encryptionRequired: true,
      );

      if (kDebugMode) {
        debugPrint("📡 Raw Response: $response");
      }

      if (!context.mounted) return;

      if (kDebugMode) {
        debugPrint("✅ Reminder saved successfully, fetching updated reminders...");
      }
      await getReminders(context);
      if (kDebugMode) {
        debugPrint("🔄 getReminders completed");
      }
    } on ApiException catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint("🔥 API Exception while saving Reminder record: $e");
        debugPrint("📍 StackTrace: $stackTrace");
      }
      _showApiError(context, e);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint("🔥 Exception while saving Reminder record: $e");
        debugPrint("📍 StackTrace: $stackTrace");
      }
      _showApiError(
        context,
        ApiException(
          statusCode: 0,
          endpoint: addreminderApi,
          rawBody: e.toString(),
        ),
      );
    }
  }

  void _showApiError(BuildContext context, ApiException error) {
    final message =
        (error.decryptedBody?.trim().isNotEmpty ?? false)
            ? error.decryptedBody!.trim()
            : (error.message?.trim().isNotEmpty ?? false)
            ? error.message!.trim()
            : 'Failed to save reminder (HTTP ${error.statusCode}).';

    if (context.mounted && ScaffoldMessenger.maybeOf(context) != null) {
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: message,
      );
      return;
    }

    Get.snackbar(
      'Error',
      message,
      snackPosition: SnackPosition.TOP,
      colorText: white,
      backgroundColor: AppColors.primaryColor,
      duration: const Duration(seconds: 3),
    );
  }
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


  Future<void> deleteReminderFromAPI(
    String reminderId,
    BuildContext context,
  ) async {
    try {
      final response = await ApiService.post(
        deletereminderApi,
        {"id": reminderId},
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response && response.statusCode >= 400) {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Failed to delete Reminder record: ${response.statusCode}',
        );
      }
      // else {
      //   await getReminders(context);
      // }
    } catch (e) {
      debugPrint("Exception while deleting Reminder record: $e");
    }
  }

  Future<bool> validateAndSave({
    required BuildContext context,
    num? dosage,
  }) async {
    if (_isSaving) {
      if (kDebugMode) {
        debugPrint('⏳ validateAndSave() ignored: already saving');
      }
      return false;
    }
    _isSaving = true;
    final category = selectedCategory.value.trim().toLowerCase();
    if (selectedCategory.value != category) {
      selectedCategory.value = category;
    }

    try {
      debugPrint("🟢 validateAndSave() called");
      debugPrint("📂 Selected category: $category");
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

      final isSelectedEvent =
          eventGetxController.eventRemindMeBefore.value == 0;

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

      // ---------------------------------------------------------------------------
      // Edit mode
      // ---------------------------------------------------------------------------

      if (editingId.value != null) {
        debugPrint("✏️ Editing existing reminder → id=${editingId.value}");

        final resolvedTime =
            pickedTime.value ?? _resolveTimeForCategory(category);
        if ((category == 'meal' || category == 'event') &&
            resolvedTime == null) {
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
          id: editingId.value.toString(),
          category: category,
          timeOfDay: resolvedTime,
        );
        return true;
      }

      // ---------------------------------------------------------------------------
      // Category-specific validation
      // ---------------------------------------------------------------------------

      if (category == "medicine") {
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

      debugPrint("🚦 Processing category: $category");

      switch (category) {
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
          final resolvedTime =
              pickedTime.value ?? _resolveTimeForCategory(category);
          if (resolvedTime == null) {
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

          debugPrint("🍽️ / 📅 Adding $category alarm");

          await addAlarm(context, timeOfDay: resolvedTime, category: category);
          break;

        case "water":
          debugPrint("💧 Delegating to WaterController");
          final ok =
              await waterController.validateAndSaveWaterReminder(context);
          if (!ok) {
            return false;
          }
          break;

        default:
          debugPrint("⚠️ Unknown category: ${selectedCategory.value}");
      }

      debugPrint("✅ validateAndSave() completed successfully");
      return true;
    } finally {
      _isSaving = false;
    }
  }

  Future<bool> validateAndUpdate({
    required BuildContext context,
    num? dosage,
    required reminder_payload.ReminderPayloadModel reminder,
  }) async {
    final category = selectedCategory.value.trim().toLowerCase();
    if (selectedCategory.value != category) {
      selectedCategory.value = category;
    }

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
          reminderId: reminder.id,
        );

      case "water":
        if (!waterController.validateWaterInput(context)) {
          return false;
        }
        waterController.waterList.value = await waterController
            .loadWaterReminderList("water_list");
        await waterController.deleteWaterReminder(reminder.id);
        return waterController.validateAndSaveWaterReminder(context);

      case "meal":
      case "event":
        final resolvedTime =
            pickedTime.value ?? _resolveTimeForCategory(category);

        if (resolvedTime == null) {
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
          id: reminder.id.toString(),
          category: category,
          timeOfDay: resolvedTime,
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

    selectedCategory.value = 'medicine';
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

  TimeOfDay? _resolveTimeForCategory(String category) {
    String source = '';
    switch (category) {
      case 'meal':
        source = mealController.timeController.text.trim();
        break;
      case 'event':
        source = timeController.text.trim();
        break;
      default:
        return null;
    }

    if (source.isEmpty) return null;

    try {
      return parseTime(source);
    } catch (_) {
      return null;
    }
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
