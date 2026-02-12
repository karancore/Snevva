import 'dart:convert';

import 'package:alarm/alarm.dart';
import 'package:alarm/model/alarm_settings.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pinput/pinput.dart';
import 'package:snevva/Controllers/Reminder/reminder_controller.dart';
import 'package:snevva/models/mappers/medicine_to_reminder_mapper.dart';

import '../../common/custom_snackbar.dart';
import '../../common/global_variables.dart';
import '../../consts/colors.dart';
import '../../consts/images.dart';
import '../../models/reminders/medicine_reminder_model.dart';

class MedicineController extends GetxController {
  ReminderController get reminderController =>
      Get.find<ReminderController>(tag: 'reminder');

  // RxList<MedicineItem> medicines = <MedicineItem>[].obs;
  RxList<String> medicineStrings = <String>[].obs;
  var medicineReminderOption = Option.times.obs;
  final RxnInt medicineRemindMeBefore = RxnInt();
  final medicineTimeBeforeController = TextEditingController();
  RxString medicineUnit = 'minutes'.obs;
  var timeBeforeReminder = (-1).obs;

  RxnInt medicineRemindMeBeforeOption = RxnInt();

  final everyHourController = TextEditingController();

  final timesPerDayController = TextEditingController();
  var savedTimes = 0.obs;
  var timesListLength = 4.obs;
  final everyXhours = 1.obs;
  final startMedicineTimeController = TextEditingController();
  final endMedicineTimeController = TextEditingController();
  Rx<DateTime?> startDate = Rx<DateTime?>(null);
  Rx<DateTime?> endDate = Rx<DateTime?>(null);
  final startMedicineDateController = TextEditingController();
  final endMedicineDateController = TextEditingController();
  final remindMeBeforeController = TextEditingController();

  var startDateString = 'Start Date'.obs;
  var endDateString = 'End Date'.obs;
  final medicineController = TextEditingController();
  var medicineList = <MedicineReminderModel>[].obs;
  var selectedMedicineIndex = (-1).obs;
  final List<String> types = ['Tablet', 'Syrup', 'Injection', 'Drops'];
  final List<String> mealOptions = ['Before food', 'After food', 'No Food'];
  final List<String> medicineFrequencies = [
    'Once',
    'Twice',
    'Thrice',
    'Custom',
  ];
  final Map<String, int> frequencyNum = {
    'Once': 1,
    'Twice': 2,
    'Thrice': 3,
    'Custom': 4,
  };
  final Map<String, String> typeToDosage = {
    'Tablet': 'TABLET',
    'Syrup': 'ML',
    'Injection': 'UNIT',
    'Drops': 'DROP',
  };

  final timeControllers = <TextEditingController>[].obs;
  RxList<DateTime> scheduledTimes = <DateTime>[].obs;

  var selectedWhenToTake = 'Before food'.obs;

  int get selectedFrequencyValue {
    return frequencyNum[selectedFrequency.value] ?? 0;
  }

  var selectedFrequency = 'Once'.obs;

  var selectedType = 'Tablet'.obs;

  @override
  void onInit() {
    super.onInit();

    ever(selectedFrequency, (_) {
      _syncTimeControllers();
    });
  }

  void _syncTimeControllers() {
    final length = frequencyNum[selectedFrequency.value] ?? 1;
    updateTimeControllers(length);
  }

  void updateTimeControllers(int count) {
    // Remove extra
    if (timeControllers.length > count) {
      timeControllers.removeRange(count, timeControllers.length);
    }

    // Add missing
    while (timeControllers.length < count) {
      timeControllers.add(TextEditingController());
    }
  }

  void addCustomTime() {
    timeControllers.add(TextEditingController());
    frequencyNum['Custom'] = timeControllers.length;
    timesPerDayController.text = timesPerDayController.length.toString();
  }

  void removeCustomTime(int index) {
    if (timeControllers.length <= 1) return;

    timeControllers[index].dispose();
    timeControllers.removeAt(index);
    frequencyNum['Custom'] = timeControllers.length;
    timesPerDayController.text = timesPerDayController.length.toString();
  }

  String getCategoryIcon(String category) {
    switch (category) {
      case 'Tablet':
        return tabletIcon;
      case 'Syrup':
        return syrupIcon;
      case 'Injection':
        return injectionIcon;
      case 'Drops':
        return dropsIcon;
      default:
        return "";
    }
  }

  String buildMedicineNotificationText({
    required String medicineName,
    required num dosage,
  }) {
    final type = selectedType.value;
    final unit = typeToDosage[type] ?? '';
    final plural = dosage > 1 ? 's' : '';

    switch (type) {
      case 'Tablet':
        return 'Take $dosage $medicineName tablet$plural.';
      case 'Syrup':
        return 'Take $dosage $unit of $medicineName.';

      case 'Injection':
        return 'Take $dosage $unit of $medicineName.';

      case 'Drops':
        return 'Take $dosage $unit of $medicineName.';

      default:
        return 'Take $medicineName.';
    }
  }

  Rx<num> dosageMed = 0.0.obs;

  Future<bool> addMedicineIntervalAlarm({
    required BuildContext context,
    required num? dosage,
  }) async {
    dosageMed.value = dosage ?? 0;
    final medicineName = medicineController.text.trim();
    if (medicineReminderOption.value != Option.interval) {
      return true;
    }

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

    final parsedIntervalHours = int.tryParse(everyHourController.text) ?? 0;
    if (parsedIntervalHours <= 0) {
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Please enter a valid hours interval',
      );
      return false;
    }

    final start = stringToTimeOfDay(startMedicineTimeController.text);
    final end = stringToTimeOfDay(endMedicineTimeController.text);
    final reminders = generateEveryXHours(
      start: start,
      end: end,
      intervalHours: parsedIntervalHours,
    );

    if (reminders.isEmpty) {
      return false;
    }

    final reminderGroupId = alarmsId();
    final List<int> alarmIds = [];
    final title = reminderController.titleController.text.trim();
    final notes = reminderController.notesController.text.trim();
    final medicineType = selectedType.value;
    final unit = typeToDosage[medicineType] ?? 'DROP';
    final normalizedStartDate =
        startDateString.value == 'Start Date' ? '' : startDateString.value;
    final normalizedEndDate =
        endDateString.value == 'End Date' ? '' : endDateString.value;

    for (final reminderTime in reminders) {
      final alarmId = alarmsId();
      final alarmSettings = AlarmSettings(
        id: alarmId,
        dateTime: reminderTime,
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
          "groupId": reminderGroupId.toString(),
          "category": ReminderCategory.medicine.toString(),
          "type": "interval",
        }),
        notificationSettings: NotificationSettings(
          title: title.isNotEmpty ? title : 'MEDICINE REMINDER',
          body: buildMedicineNotificationText(
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
        alarmIds.add(alarmId);
      }
    }

    if (alarmIds.isEmpty) {
      return false;
    }

    final medicine = MedicineReminderModel(
      id: reminderGroupId,
      alarmIds: alarmIds,
      title: title,
      category: ReminderCategory.medicine.toString(),
      medicineName: medicineName,
      medicineType: medicineType,
      whenToTake: selectedWhenToTake.value,
      dosage: Dosage(value: dosage ?? 0, unit: unit),
      medicineFrequencyPerDay:
          frequencyNum[selectedFrequency.value].toString(),
      reminderFrequencyType: selectedFrequency.value,
      customReminder: CustomReminder(
        type: Option.interval,
        timesPerDay: null,
        everyXHours: EveryXHours(
          hours: parsedIntervalHours.toString(),
          startTime: startMedicineTimeController.text.trim(),
          endTime: endMedicineTimeController.text.trim(),
        ),
      ),
      remindBefore: buildRemindBefore(),
      startDate: normalizedStartDate,
      endDate: normalizedEndDate,
      notes: notes,
    );

    medicineList.value = await loadMedicineReminderList("medicine_list");
    medicineList.add(medicine);
    await reminderController.saveReminderList(medicineList, "medicine_list");
    await reminderController.loadAllReminderLists();
    CustomSnackbar().showReminderBar(context);
    Get.back(result: true);
    return true;
  }

  int getEffectiveTimesPerDay() {
    if (selectedFrequency.value == "Custom") {
      return int.tryParse(timesPerDayController.text) ?? timeControllers.length;
    }
    return frequencyNum[selectedFrequency.value] ?? timeControllers.length;
  }

  Future<bool> addMedicineAlarm({
    required BuildContext context,
    required num? dosage,
  }) async {
    final medicineName = medicineController.text.trim();
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

    final reminderGroupId = alarmsId();
    final List<AlarmSettings> alarms = [];

    for (final scheduledTime in scheduledTimes) {
      final alarmId = alarmsId();

      final alarmSettings = AlarmSettings(
        id: alarmId,
        dateTime: scheduledTime,
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
          "groupId": reminderGroupId.toString(),
          "category": ReminderCategory.medicine.toString(),
          "type": "times",
        }),
        notificationSettings: NotificationSettings(
          title:
              reminderController.titleController.text.isNotEmpty
                  ? reminderController.titleController.text
                  : 'MEDICINE REMINDER',
          body: buildMedicineNotificationText(
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
        alarms.add(alarmSettings);
      }
    }

    if (alarms.isEmpty) {
      return false;
    }

    final id = reminderGroupId;
    final title = reminderController.titleController.text.trim();

    final notes = reminderController.notesController.text.trim();
    final medicineType = selectedType.value;
    final unit = typeToDosage[medicineType] ?? 'DROP';
    final normalizedStartDate =
        startDateString.value == 'Start Date' ? '' : startDateString.value;
    final normalizedEndDate =
        endDateString.value == 'End Date' ? '' : endDateString.value;
    final timesPerDay = getEffectiveTimesPerDay();
    final everyXHours = everyHourController.text.trim();
    final reminderFrequencyType = selectedFrequency.value;
    final medicineFrequencyPerDay =
        frequencyNum[selectedFrequency.value].toString();
    final startTime = startMedicineTimeController.text.trim();
    final endTime = endMedicineTimeController.text.trim();
    final list =
        timeControllers.map((controller) => controller.text.trim()).toList();

    CustomReminder customReminder;
    if (medicineReminderOption.value == Option.times) {
      customReminder = CustomReminder(
        type: Option.times,
        timesPerDay: TimesPerDay(count: timesPerDay.toString(), list: list),
        everyXHours: null,
      );
    } else {
      customReminder = CustomReminder(
        type: Option.interval,
        timesPerDay: null,
        everyXHours: EveryXHours(
          hours: everyXHours,
          startTime: startTime,
          endTime: endTime,
        ),
      );
    }

    final medicine = MedicineReminderModel(
      id: id,
      alarmIds: alarms.map((e) => e.id).toList(),
      title: title,
      category: ReminderCategory.medicine.toString(),
      medicineName: medicineName,
      medicineType: medicineType,
      whenToTake: selectedWhenToTake.value,
      dosage: Dosage(value: dosage ?? 0, unit: unit),
      medicineFrequencyPerDay: medicineFrequencyPerDay,
      reminderFrequencyType: reminderFrequencyType,
      customReminder: customReminder,
      remindBefore: buildRemindBefore(),
      startDate: normalizedStartDate,
      endDate: normalizedEndDate,
      notes: notes,
    );

    medicineList.add(medicine);
    //await saveMedicineReminderList("medicine_list", medicineList);
    await reminderController.saveReminderList(medicineList, "medicine_list");
    await reminderController.loadAllReminderLists();

    // await reminderController.addRemindertoAPI(
    //   medicine.toReminderPayload(),
    //   context,
    // );
    CustomSnackbar().showReminderBar(context);
    Get.back(result: true);
    return true;
  }

  RemindBefore? buildRemindBefore() {
    if (medicineRemindMeBeforeOption.value != 0) {
      return null;
    }
    final rawTime = medicineTimeBeforeController.text.trim();
    if (rawTime.isEmpty) return null;
    final time = int.tryParse(rawTime);
    if (time == null || time <= 0) return null;
    return RemindBefore(
      time: time,
      unit: reminderController.selectedValue.value,
    );
  }

  // Future<void> saveMedicineReminderList(
  //   String key,
  //   List<MedicineReminderModel> list,
  // ) async {
  //   final box = Hive.box(reminderBox);
  //
  //   debugPrint('━━━━━━━━ SAVE MEDICINE ━━━━━━━━');
  //   debugPrint('🧹 Clearing Hive box → medicine_list');
  //   debugPrint('📦 Items before clear: ${box.length}');
  //
  //   await box.clear();
  //
  //   debugPrint('📦 Items after clear: ${box.length}');
  //   debugPrint('💾 Saving ${list.length} medicine reminders');
  //
  //
  //   for (int i = 0; i < list.length; i++) {
  //     final item = list[i];
  //     final json = item.toJson();
  //
  //     debugPrint('➡ Saving index $i');
  //     debugPrint('   🆔 id: ${item.id}');
  //     debugPrint('   💊 name: ${item.medicineName}');
  //     debugPrint('   🔁 freqType: ${item.reminderFrequencyType}');
  //     debugPrint('   ⏰ timesPerDay.count: ${item.customReminder?.timesPerDay?.count}');
  //
  //     box.put(item.id, json);
  //   }
  //
  //   debugPrint('✅ Save completed. Hive count = ${box.length}');
  // }
  // ---------------------------------------------------------
  //  PASTE THIS INSIDE MedicineController class
  // ---------------------------------------------------------

  Future<void> saveMedicineReminderList(
    String key,
    // internal call should pass "medicine_list"
    List<MedicineReminderModel> list,
  ) async {
    final box = Hive.box(reminderBox); // Uses your constant

    // ❌ DELETED: await box.clear();  <-- THIS WAS THE BUG
    // We do NOT want to clear water reminders when saving medicine.

    // Convert list of models -> List of JSON Strings
    List<String> stringList =
        list.map((item) {
          return jsonEncode(item.toJson());
        }).toList();

    // Save the whole list under the key "medicine_list"
    await box.put(key, stringList);

    debugPrint('✅ Saved ${stringList.length} medicines to Hive key: $key');
  }

  Future<List<MedicineReminderModel>> loadMedicineReminderList(
    String key,
  ) async {
    debugPrint('📦 Loading medicine reminders from Hive Key: $key');
    final box = Hive.box(reminderBox);

    // Get the list of strings (safely)
    final List<dynamic>? storedList = box.get(key);

    if (storedList == null) return [];

    final List<MedicineReminderModel> loadedList = [];

    for (var item in storedList) {
      try {
        // Decode JSON String -> Map -> Model
        if (item is String) {
          final Map<String, dynamic> decoded = jsonDecode(item);
          final model = MedicineReminderModel.fromJson(decoded);
          loadedList.add(model);
        }
      } catch (e) {
        debugPrint('❌ Error parsing medicine: $e');
      }
    }

    return loadedList;
  }

  Future<void> updateMedicineAlarm(
    DateTime scheduledTime,
    BuildContext context,
    int alarmId,
  ) async {
    // 1. Re-set the alarm with the SAME ID
    final alarmSettings = AlarmSettings(
      id: alarmId,
      androidFullScreenIntent: true,
      dateTime: scheduledTime,
      assetAudioPath: alarmSound,
      loopAudio: true,
      vibrate: true,
      volumeSettings: VolumeSettings.fade(
        volume: 0.8,
        fadeDuration: const Duration(seconds: 5),
        volumeEnforced: true,
      ),
      notificationSettings: NotificationSettings(
        title:
            reminderController.titleController.text.isNotEmpty
                ? reminderController.titleController.text
                : 'MEDICINE REMINDER',
        body:
            'Take ${medicineController.text.trim()}. ${reminderController.notesController.text}',
        stopButton: 'Stop',
        icon: 'alarm',
        iconColor: AppColors.primaryColor,
      ),
    );

    await Alarm.set(alarmSettings: alarmSettings);

    // 2. Update the List in Hive
    medicineList.value = await loadMedicineReminderList("medicine_list");

    final id = alarmId;
    final title = reminderController.titleController.text.trim();
    final notes = reminderController.notesController.text.trim();
    final medicineType = selectedType.value;
    final unit = typeToDosage[medicineType] ?? 'DROP';
    final normalizedStartDate =
        startDateString.value == 'Start Date' ? '' : startDateString.value;
    final normalizedEndDate =
        endDateString.value == 'End Date' ? '' : endDateString.value;
    final timesPerDay = timesPerDayController.text.trim();
    final everyXHours = everyHourController.text.trim();
    final reminderFrequencyType = selectedFrequency.value;
    final medicineFrequencyPerDay =
        frequencyNum[selectedFrequency.value].toString();
    final startTime = startMedicineTimeController.text.trim();
    final endTime = endMedicineTimeController.text.trim();
    final list =
        timeControllers.map((controller) => controller.text.trim()).toList();
    final oldModel = medicineList.firstWhereOrNull((e) => e.id == alarmId);

    final medicineName =
        oldModel?.medicineName ?? medicineController.text.trim();
    CustomReminder customReminder;
    if (medicineReminderOption.value == Option.times) {
      customReminder = CustomReminder(
        type: Option.times,
        timesPerDay: TimesPerDay(count: timesPerDay, list: list),
        everyXHours: null,
      );
    } else {
      customReminder = CustomReminder(
        type: Option.interval,
        timesPerDay: null,
        everyXHours: EveryXHours(
          hours: everyXHours,
          startTime: startTime,
          endTime: endTime,
        ),
      );
    }

    // Create updated model
    final newModel = MedicineReminderModel(
      id: id,
      alarmIds: [alarmId],
      title: title,
      category: ReminderCategory.medicine.toString(),
      medicineName: medicineName,
      medicineType: medicineType,
      whenToTake: selectedWhenToTake.value,
      dosage: Dosage(value: dosageMed.value, unit: unit),
      medicineFrequencyPerDay: medicineFrequencyPerDay,
      reminderFrequencyType: reminderFrequencyType,
      customReminder: customReminder,
      remindBefore: buildRemindBefore(),
      startDate: normalizedStartDate,
      endDate: normalizedEndDate,
      notes: notes,
    );
    //medicineList.add(newModel);

    await reminderController.updateReminder(
      newModel.toReminderPayload(),
      context,
    );
    // Find index and replace
    final index = medicineList.indexWhere((e) => e.id == alarmId);
    if (index != -1) {
      medicineList[index] = newModel;
    } else {
      medicineList.add(newModel); // Fallback if not found
    }

    // 3. Save and Refresh
    await reminderController.finalizeUpdate(
      context,
      "medicine_list",
      medicineList,
    );

    CustomSnackbar().showReminderBar(context);
    Get.back(result: true);
  }

  Future<void> deleteMedicineReminder(int reminderId) async {
    medicineList.value = await loadMedicineReminderList("medicine_list");
    final index = medicineList.indexWhere((e) => e.id == reminderId);
    if (index == -1) return;

    final model = medicineList[index];
    final candidateTimes = _candidateReminderTimes(model);
    final idsToStop = <int>{...model.alarmIds, model.id};

    for (final id in idsToStop) {
      await Alarm.stop(id);
    }

    final activeAlarms = await Alarm.getAlarms();
    for (final alarm in activeAlarms) {
      final payload = alarm.payload;
      if (payload == null) continue;
      try {
        final decoded = jsonDecode(payload);
        if (decoded['category'] == ReminderCategory.medicine.toString() &&
            decoded['groupId'] == reminderId.toString()) {
          await Alarm.stop(alarm.id);
        }
      } catch (_) {}
    }

    // Backward compatibility for old records that did not persist alarm ids.
    if (model.alarmIds.isEmpty) {
      final title = model.title.isNotEmpty ? model.title : 'MEDICINE REMINDER';
      for (final alarm in activeAlarms) {
        final matchesTitle = alarm.notificationSettings.title == title;
        final matchesMedicine = alarm.notificationSettings.body.contains(
          model.medicineName,
        );
        final matchesTime = candidateTimes.any(
          (t) =>
              t.hour == alarm.dateTime.hour && t.minute == alarm.dateTime.minute,
        );
        if (matchesTitle && matchesMedicine && matchesTime) {
          await Alarm.stop(alarm.id);
        }
      }
    }

    // Stop "before reminder" alarms that are linked by category + mainTime.
    for (final alarm in activeAlarms) {
      final payload = alarm.payload;
      if (payload == null) continue;
      try {
        final decoded = jsonDecode(payload);
        final isBefore = decoded['type']?.toString() == 'before';
        final category = decoded['category']?.toString();
        if (!isBefore || !_isMedicineCategory(category)) continue;

        final mainTimeRaw = decoded['mainTime']?.toString();
        if (mainTimeRaw == null || mainTimeRaw.isEmpty) continue;
        final mainTime = DateTime.tryParse(mainTimeRaw);
        if (mainTime == null) continue;

        final matchesMainTime = candidateTimes.any(
          (t) => t.hour == mainTime.hour && t.minute == mainTime.minute,
        );

        if (matchesMainTime) {
          await Alarm.stop(alarm.id);
        }
      } catch (_) {}
    }

    medicineList.removeAt(index);
    await reminderController.saveReminderList(medicineList, "medicine_list");
  }

  List<TimeOfDay> _candidateReminderTimes(MedicineReminderModel model) {
    if (model.customReminder.type == Option.times) {
      return model.customReminder.timesPerDay?.list
              .map((raw) => _parseTimeOfDay(raw))
              .whereType<TimeOfDay>()
              .toList() ??
          const <TimeOfDay>[];
    }

    final interval = model.customReminder.everyXHours;
    if (interval == null) return const <TimeOfDay>[];
    final intervalHours = int.tryParse(interval.hours) ?? 0;
    if (intervalHours <= 0) return const <TimeOfDay>[];

    try {
      final start = stringToTimeOfDay(interval.startTime);
      final end = stringToTimeOfDay(interval.endTime);
      final generated = generateEveryXHours(
        start: start,
        end: end,
        intervalHours: intervalHours,
      );
      return generated
          .map((dt) => TimeOfDay(hour: dt.hour, minute: dt.minute))
          .toList();
    } catch (_) {
      return const <TimeOfDay>[];
    }
  }

  bool _isMedicineCategory(String? category) {
    if (category == null) return false;
    return category == 'medicine' ||
        category == ReminderCategory.medicine.toString();
  }

  TimeOfDay? _parseTimeOfDay(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    try {
      return stringToTimeOfDay(trimmed);
    } catch (_) {
      try {
        final parsed = DateTime.parse(trimmed);
        return TimeOfDay.fromDateTime(parsed);
      } catch (_) {
        return null;
      }
    }
  }

  List<DateTime> generateEveryXHours({
    required TimeOfDay start,
    required TimeOfDay end,
    required int intervalHours,
  }) {
    if (intervalHours <= 0) return [];

    final window = buildTimeWindow(start, end);
    final reminders = <DateTime>[];

    DateTime current = window.start.add(Duration(hours: intervalHours));
    while (!current.isAfter(window.end)) {
      reminders.add(current);
      current = current.add(Duration(hours: intervalHours));
    }

    return reminders;
  }

  // Future<List<MedicineReminderModel>> loadMedicineReminderList(
  //     String keyName,
  //     ) async {
  //   final box = Hive.box('reminders_box');
  //
  //   final List<dynamic>? storedList = box.get(keyName);
  //
  //   debugPrint('📦 loadMedicineReminderList($keyName)');
  //   debugPrint('➡ storedList runtimeType: ${storedList.runtimeType}');
  //   debugPrint('➡ storedList length: ${storedList?.length}');
  //
  //   if (storedList == null) return [];
  //
  //   // Inspect first element BEFORE casting
  //   if (storedList.isNotEmpty) {
  //     debugPrint(
  //       '🧪 first stored item type: ${storedList.first.runtimeType}',
  //     );
  //     debugPrint(
  //       '🧪 first stored item value: ${storedList.first}',
  //     );
  //   }
  //
  //   final List<String> stringList = storedList.cast<String>();
  //
  //   List<MedicineReminderModel> loadedList = [];
  //
  //   for (var item in stringList) {
  //     debugPrint('🔍 Parsing item: $item');
  //
  //     try {
  //       final Map<String, dynamic> decoded = jsonDecode(item);
  //
  //       debugPrint('➡ Decoded JSON keys: ${decoded.keys}');
  //       if (decoded.isEmpty) {
  //         debugPrint('⚠️ Empty reminder entry skipped');
  //         continue;
  //       }
  //
  //
  //       // Check if it's the new format (has 'medicines' key)
  //       if (decoded.containsKey('medicines')) {
  //         debugPrint('✅ New format detected (with medicines)');
  //         loadedList.add(MedicineReminderModel.fromJson(decoded));
  //       } else {
  //         debugPrint('⚠️ Old format detected (no medicines key)');
  //
  //         // Fallback for old format: {title: alarm_settings}
  //         final entry = decoded.entries.first;
  //
  //         loadedList.add(
  //           MedicineReminderModel(
  //             id: alarmsId().toString(),
  //             title: entry.key,
  //             note: '',
  //             medicines: [],
  //             alarm: AlarmSettings.fromJson(entry.value),
  //           ),
  //         );
  //       }
  //     } catch (e, s) {
  //       debugPrint('❌ Error parsing medicine reminder: $e');
  //       debugPrint('$s');
  //     }
  //   }
  //
  //   debugPrint('✅ Loaded ${loadedList.length} medicine reminders');
  //
  //   return loadedList;
  // }

  // Future<List<MedicineReminderModel>> loadMedicineReminderList(
  //   String key,
  // ) async {
  //   debugPrint('📦 Loading medicine reminders from Hive');
  //   final box = Boxes.getData();
  //
  //   debugPrint('📊 Hive raw values count: ${box.values.length}');
  //   debugPrint('📦 Raw Hive values: ${box.values}');
  //
  //   final List<MedicineReminderModel> loadedList = [];
  //
  //   int index = 0;
  //   for (final raw in box.values) {
  //     debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  //     debugPrint('🔍 Reading item #$index');
  //     debugPrint('➡ raw runtimeType: ${raw.runtimeType}');
  //     debugPrint('➡ raw value: $raw');
  //
  //     try {
  //       if (raw is! Map) {
  //         debugPrint('⚠️ Skipped: not a Map');
  //         continue;
  //       }
  //
  //       if (raw.isEmpty) {
  //         debugPrint('⚠️ Skipped: empty Map');
  //         continue;
  //       }
  //
  //       final normalized = deepNormalizeMap(raw);
  //
  //       debugPrint('🧪 Normalized Map: $normalized');
  //       debugPrint('⏰ remindBefore in map: ${normalized['remindBefore']}');
  //
  //       final model = MedicineReminderModel.fromJson(normalized);
  //
  //       debugPrint('✅ Parsed model');
  //       debugPrint('🆔 id: ${model.id}');
  //       debugPrint('💊 medicineName: ${model.medicineName}');
  //       debugPrint(
  //         '⏰ remindBefore: ${model.remindBefore != null ? model.remindBefore!.toJson() : "NULL"}',
  //       );
  //
  //       loadedList.add(model);
  //     } catch (e, s) {
  //       debugPrint('❌ Error parsing reminder: $e');
  //       debugPrint(s.toString());
  //     }
  //
  //     index++;
  //   }
  //
  //   debugPrint('🎉 Load completed. Loaded ${loadedList.length} reminders');
  //   return loadedList;
  // }
  // Future<List<MedicineReminderModel>> loadMedicineReminderList(
  //     String key, // This will be passed as "medicine_list"
  //     ) async {
  //   debugPrint('📦 Loading medicine reminders from Hive Key: $key');
  //
  //   // 1. Open the specific shared box
  //   final box = Hive.box('reminders_box');
  //
  //   // 2. Retrieve the specific list (List<String>)
  //   final List<dynamic>? storedList = box.get(key);
  //
  //   if (storedList == null) {
  //     debugPrint('⚠️ No medicine list found for key: $key');
  //     return [];
  //   }
  //
  //   final List<MedicineReminderModel> loadedList = [];
  //
  //   // 3. Iterate and decode
  //   for (var item in storedList) {
  //     try {
  //       if (item is String) {
  //         final Map<String, dynamic> decoded = jsonDecode(item);
  //         // Normalize if needed, or parse directly
  //         final model = MedicineReminderModel.fromJson(decoded);
  //         loadedList.add(model);
  //       }
  //     } catch (e) {
  //       debugPrint('❌ Error parsing medicine reminder: $e');
  //     }
  //   }
  //
  //   debugPrint('🎉 Loaded ${loadedList.length} medicine reminders');
  //   return loadedList;
  // }

  void resetForm() {
    // ---------- Text controllers ----------
    medicineController.clear();
    everyHourController.clear();
    timesPerDayController.clear();
    remindMeBeforeController.clear();
    medicineTimeBeforeController.clear();
    startMedicineTimeController.clear();
    endMedicineTimeController.clear();
    startMedicineDateController.clear();
    endMedicineDateController.clear();

    // ---------- Rx values ----------
    medicineReminderOption.value = Option.times;
    medicineRemindMeBefore.value = null;
    medicineRemindMeBeforeOption.value = null;
    medicineUnit.value = 'minutes';
    timeBeforeReminder.value = -1;

    selectedFrequency.value = 'Once';
    selectedType.value = 'Tablet';
    selectedWhenToTake.value = 'Before food';

    savedTimes.value = 0;
    timesListLength.value = 4;
    everyXhours.value = 1;

    startDate.value = null;
    endDate.value = null;
    startDateString.value = 'Start Date';
    endDateString.value = 'End Date';

    selectedMedicineIndex.value = -1;

    dosageMed.value = 0.0;

    // ---------- Time controllers ----------
    for (final controller in timeControllers) {
      controller.clear();
    }
    if (timeControllers.isEmpty) {
      updateTimeControllers(1);
    } else {
      timeControllers.removeRange(1, timeControllers.length);
    }

    scheduledTimes.clear();
  }

  @override
  void onClose() {
    medicineController.dispose();
    everyHourController.dispose();
    timesPerDayController.dispose();
    startMedicineTimeController.dispose();
    endMedicineTimeController.dispose();
    startMedicineDateController.dispose();
    endMedicineDateController.dispose();
    remindMeBeforeController.dispose();
    medicineTimeBeforeController.dispose();

    for (final controller in timeControllers) {
      controller.dispose();
    }
    timeControllers.clear();

    super.onClose();
  }
}
