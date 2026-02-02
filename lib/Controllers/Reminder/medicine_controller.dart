import 'dart:convert';

import 'package:alarm/alarm.dart';
import 'package:alarm/model/alarm_settings.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pinput/pinput.dart';
import 'package:snevva/Controllers/Reminder/reminder_controller.dart';
import 'package:snevva/Controllers/Reminder/water_controller.dart';

import '../../boxes/boxes/boxes.dart';
import '../../common/custom_snackbar.dart';
import '../../common/global_variables.dart';
import '../../consts/colors.dart';
import '../../consts/images.dart';
import '../../models/medicine_reminder_model.dart';

class MedicineController extends GetxController {
  ReminderController get reminderController =>
      Get.find<ReminderController>(tag: 'reminder');

  WaterController get waterController => Get.find<WaterController>();

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

  var selectedOption = 'Before food'.obs;

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

  // void addMedicine(BuildContext context) {
  //   final name = medicineController.text.trim();
  //
  //   medicines.add(MedicineItem(name: name, times: []));
  //   selectedMedicineIndex.value = medicines.length - 1;
  //   //medicines.add(medicineController.text);
  //   medicineController.clear();
  // }

  // void addTimeToMedicine(TimeOfDay time) {
  //   if (selectedMedicineIndex.value == -1) return;
  //
  //   medicines[selectedMedicineIndex.value].times.add(MedicineTime(time: time));
  //
  //   medicines.refresh();
  // }

  // void removeMedicine(int index) {
  //   medicines.removeAt(index);
  // }

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



  bool addMedicineIntervalAlarm({
    required BuildContext context,
    required DateTime startDateTime,
    required DateTime endDateTime,
    required int intervalHours,
    required num ? dosage
  }) {
    final medicineName = medicineController.text.trim();
    if (medicineReminderOption.value == Option.interval) {
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

      final start = stringToTimeOfDay(startMedicineTimeController.text);
      final end = stringToTimeOfDay(endMedicineTimeController.text);

      final reminders = waterController.generateEveryXHours(
        start: start,
        end: end,
        intervalHours: intervalHours,
      );

      if (reminders.isEmpty) {
        return false;
      }
      waterController.setIntervalReminders(
        intervalReminders: reminders,
        context: context,
        intervalHours: intervalHours,
        title: 'Medicine',
        body :  buildMedicineNotificationText(medicineName: medicineName, dosage: dosage ?? 0),
      );
      return true;
    }
    return true;
  }
  Future<bool> addMedicineAlarm({
    required BuildContext context,
    required num ? dosage
  }) async {
    final medicineName = medicineController.text.trim();
    if (medicineName.isEmpty) {
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Please enter a medicine name',
      );
      return false;
    }

    final List<AlarmSettings> alarms = [];
    // List<DateTime> scheduledTimes = scheduledTimesTimeOfDay.map(
    //   (e) => DateTime(
    //     DateTime.now().year,
    //     DateTime.now().month,
    //     DateTime.now().day,
    //     e.hour,
    //     e.minute,
    //   ),
    // ).toList();

    for (final scheduledTime in scheduledTimes) {
      final alarmId = alarmsId(); // Generate unique ID for each alarm

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
        notificationSettings: NotificationSettings(
          title:
              reminderController.titleController.text.isNotEmpty
                  ? reminderController.titleController.text
                  : 'MEDICINE REMINDER',
          body: buildMedicineNotificationText(medicineName: medicineName, dosage: dosage ?? 0),
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

    if (alarms.isEmpty) return false;
    final id = alarms.first.id.toString();
    final title = reminderController.titleController.text.trim();
    final notes = reminderController.notesController.text.trim();

    // 🔹 Single reminder entry, multiple alarms
    final reminder = MedicineReminderModel(
      id: id ,
      // or generate separate reminderId
      title: title,
      note: notes,
      medicineName: medicineName,
      alarms: alarms, // ⬅️ CHANGE MODEL to List<AlarmSettings>
    );

    medicineList.add(reminder);
    await saveMedicineReminderList("medicine_list", medicineList);

    //reminderController.buildReminderPayload(category: "Medicine", id: int.parse(id));

    await reminderController.addRemindertoAPI(
      reminderController.buildReminderPayload(category: "Medicine", id: int.parse(id)),
      context,
    );

    Get.back(result: true);
    return true;
  }

  Future<void> saveMedicineReminderList(
    String key,
    List<MedicineReminderModel> list,
  ) async {
    final box = Hive.box(reminderBox);
    await box.clear();

    for (final reminder in list) {
      debugPrint('🧪 Saving reminder: ${reminder.title}');
      box.put(medicineKey, reminder.toJson());
    }

    debugPrint('✅ Saved ${list.length} items to Hive → $key');
    //Get.back();
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

    await reminderController.updateReminder(
      reminderController.buildReminderPayload(
        category: reminderController.selectedCategory.value,
        id: reminderController.editingId.value,
      ),
      context,
    );

    // Create updated model
    final newModel = MedicineReminderModel(
      id: alarmId.toString(),
      title: reminderController.titleController.text.trim(),
      note: reminderController.notesController.text.trim(),
      medicineName: medicineController.text.trim(),
      alarms: [],
    );
    //medicineList.add(newModel);

    // // Find index and replace
    // final index = medicineList.indexWhere((e) => e.alarms.id == alarmId);
    // if (index != -1) {
    //   medicineList[index] = newModel;
    // } else {
    //   medicineList.add(newModel); // Fallback if not found
    // }

    // 3. Save and Refresh
    await reminderController.finalizeUpdate(
      context,
      "medicine_list",
      medicineList,
    );
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

  Future<List<MedicineReminderModel>> loadMedicineReminderList(
    String key,
  ) async {
    debugPrint('📦 loadMedicineReminderList($key)');

    //final box = Hive.box('reminders_box');
    final box = Boxes.getData();
    logLong("reminders box loadMedicineReminderList", box.values.toString());
    final List<MedicineReminderModel> loadedList = [];

    for (final raw in box.values) {
      try {
        if (raw is! Map) {
          debugPrint('⚠️ Skipping invalid Hive item: ${raw.runtimeType}');
          continue;
        }

        if (raw.isEmpty) {
          debugPrint('⚠️ Empty reminder entry skipped');
          continue;
        }

        final normalized = deepNormalizeMap(raw);

        loadedList.add(MedicineReminderModel.fromJson(normalized));
      } catch (e) {
        debugPrint('❌ Error parsing reminder: $e');
      }
    }

    debugPrint('✅ Loaded ${loadedList.length} medicine reminders');
    return loadedList;
  }

  @override
  void onClose() {
    medicineController.dispose();
    everyHourController.dispose();
    timesPerDayController.dispose();
    remindMeBeforeController.dispose();
    timeControllers.clear();
    for (final controller in timeControllers) {
      controller.dispose();
    }
    startMedicineDateController.dispose();
    startMedicineTimeController.dispose();
    endMedicineTimeController.dispose();
    endMedicineDateController.dispose();
    super.onClose();
  }
}
