import 'dart:convert';
import 'package:alarm/alarm.dart';
import 'package:snevva/Controllers/Reminder/reminder_controller.dart';
import 'package:snevva/Controllers/Reminder/water_controller.dart';
import 'package:snevva/models/hive_models/reminder_payload_model.dart'
    as reminder_payload;
import 'package:snevva/models/reminders/water_reminder_model.dart';

import '../../common/global_variables.dart';
import '../../consts/consts.dart';
import '../../models/reminders/medicine_reminder_model.dart' as medicine_model;

class ReminderScheduler {
  static var waterList = <WaterReminderModel>[].obs;
  static var mealsList = <Map<String, AlarmSettings>>[].obs;
  static var eventList = <Map<String, AlarmSettings>>[].obs;
  static var medicineList = <medicine_model.MedicineReminderModel>[].obs;
  static ReminderController get _reminderController =>
      Get.find<ReminderController>(tag: 'reminder');

  static Future<void> scheduleAll(
    List<reminder_payload.ReminderPayloadModel> reminders,
  ) async {
    for (final reminder in reminders) {
      try {
        reminder.validate();
        await _scheduleByCategory(reminder);
      } catch (e) {
        debugPrint("Invalid reminder skipped : $e");
      }
    }
  }

  static Future<void> _scheduleByCategory(
    reminder_payload.ReminderPayloadModel reminder,
  ) async {
    switch (reminder.category) {
      case 'medicine':
        break;
      case 'water':
        await scheduleWaterReminder(reminder: reminder);
        break;
      case 'meal':
        await scheduleReminderFromModel(
          reminder: reminder,
          category: 'meal',
          keyName: "meals_list",
          reminderList: mealsList,
        );
        break;
      case 'event':
        final timesList = reminder.medicineTimesSafe;

        final date = reminder.startDate;
        if (reminder.remindBefore != null && timesList.isNotEmpty) {
          final timeString = timesList.first;
          final mainTime = buildDateTimeFromTimeString(time: timeString);
          schedulePreReminder(
            mainTime: mainTime,
            category: 'event',
            body: "Your scheduled event will start in ",
            reminder: reminder,
          );
        }
        scheduleReminderFromModel(
          reminder: reminder,
          category: 'event',
          date: date,
          reminderList: eventList,
          keyName: "event_list",
        );
        break;
    }
  }

  static int scheduledReminderId({
    required int reminderId,
    required DateTime time,
  }) {
    return reminderId * 100000 + time.hour * 100 + time.minute;
  }

  static Future<void> scheduleMedicineReminder({
    required reminder_payload.ReminderPayloadModel reminder,
  }) async {
    final customReminder = reminder.customReminder;
    final timesPerDay = customReminder.timesPerDay;
    final numberOfTimes = reminder.medicineTimesSafe.length;

    final timesList = reminder.medicineTimesSafe;

    final date = reminder.startDate;
    List<DateTime> scheduledTimes =
        timesList
            .map((e) => buildDateTimeFromTimeString(time: e, date: date))
            .toList();
    final List<AlarmSettings> alarms = [];
    if (timesPerDay != null) {
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
            "groupId": reminder.id.toString(),
            "category": ReminderCategory.medicine.toString(),
            "type": "times",
          }),
          notificationSettings: NotificationSettings(
            title: reminder.title,
            body: buildMedicineNotificationText(
              medicineName: reminder.medicineNameSafe,

              dosage: reminder.dosage?.value ?? 0,
              reminder: reminder,
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
      final id = reminder.id;
      final title = reminder.title;

      final notes = reminder.notes ?? '';
      final medicineName = reminder.medicineNameSafe;
      final medicineType = reminder.medicineTypeSafe;
      final whenToTake = reminder.whenToTakeSafe;

      final unit = reminder.dosage?.unit ?? 'DROP';
      final timesPerDay = reminder.customReminder.timesPerDay?.count;
      final everyXHours = reminder.customReminder.everyXHours?.hours;
      final reminderFrequencyType = reminder.medicineFrequencyPerDay ?? '';
      final medicineFrequencyPerDay = reminder.medicineFrequencyPerDay ?? '';
      final startTime = reminder.customReminder.everyXHours?.startTime;
      final dosageValue = reminder.dosage?.value ?? 0;
      final endTime = reminder.customReminder.everyXHours?.endTime;
      final list = reminder.customReminder.timesPerDay!.list;

      medicine_model.CustomReminder customReminder;
      if (reminder.customReminder.timesPerDay != null) {
        customReminder = medicine_model.CustomReminder(
          type: Option.times,
          timesPerDay: medicine_model.TimesPerDay(
            count: timesPerDay.toString(),
            list: list,
          ),
          everyXHours: null,
        );
      } else {
        customReminder = medicine_model.CustomReminder(
          type: Option.interval,
          timesPerDay: null,
          everyXHours: medicine_model.EveryXHours(
            hours: reminder.customReminder.everyXHours!.hours.toString(),
            startTime: startTime!,
            endTime: endTime!,
          ),
        );
      }
      medicine_model.RemindBefore? remindBefore;
      if (remindBefore != null) {
        final remindBeforeTime = remindBefore.time;
        final remindBeforeTimeUnit = remindBefore.unit;

        remindBefore = medicine_model.RemindBefore(
          time: remindBeforeTime,
          unit: remindBeforeTimeUnit,
        );
      }

      final medicine = medicine_model.MedicineReminderModel(
        id: id,
        alarmIds: alarms.map((e) => e.id).toList(),
        title: title,
        category: "MEDICINE",
        medicineName: reminder.medicineNameSafe,
        medicineType: reminder.medicineTypeSafe,
        whenToTake: reminder.whenToTakeSafe,

        dosage: medicine_model.Dosage(value: dosageValue, unit: unit),
        medicineFrequencyPerDay: medicineFrequencyPerDay,
        reminderFrequencyType: reminderFrequencyType,
        customReminder: customReminder,
        remindBefore: remindBefore,
        startDate: reminder.startDate ?? '',
        endDate: reminder.endDate ?? '',
        notes: notes,
      );

      medicineList.add(medicine);
      //await saveMedicineReminderList("medicine_list", medicineList);
      await _reminderController.saveReminderList(medicineList, "medicine_list");
      await _reminderController.loadAllReminderLists();
    }
  }

  static String buildMedicineNotificationText({
    required String medicineName,
    required num dosage,
    required reminder_payload.ReminderPayloadModel reminder,
  }) {
    final type = reminder.medicineType;
    final unit = reminder.dosage?.unit ?? '';
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

  static Future<void> scheduleWaterReminder({
    required reminder_payload.ReminderPayloadModel reminder,
  }) async {
    final customReminder = reminder.customReminder;
    final timesPerDay = customReminder.timesPerDay;
    final times = reminder.waterTimesCountSafe;

    if (timesPerDay != null) {
      final alarmTimes = Get.find<WaterController>().generateTimesBetween(
        startTime: reminder.waterStartSafe,
        endTime: reminder.waterEndSafe,

        times: times,
      );
      List<AlarmSettings> createdAlarms = [];

      for (var i = 0; i < alarmTimes.length; i++) {
        final time = alarmTimes[i];
        final scheduledTime =
            time.isBefore(DateTime.now()) ? time.add(Duration(days: 1)) : time;
        final alarmId = generateWaterAlarmId(reminder.id, i);

        final alarmSettings = AlarmSettings(
          id: scheduledReminderId(reminderId: reminder.id, time: scheduledTime),
          dateTime: scheduledTime,
          assetAudioPath: alarmSound,
          volumeSettings: VolumeSettings.fade(
            volume: 0.8,
            fadeDuration: Duration(seconds: 5),
            volumeEnforced: true,
          ),
          notificationSettings: NotificationSettings(
            title: reminder.title,
            body: reminder.notes ?? '',
            stopButton: 'Stop',
            icon: 'alarm',
            iconColor: AppColors.primaryColor,
          ),
        );
        await Alarm.set(alarmSettings: alarmSettings);
        createdAlarms.add(alarmSettings);
      }

      final waterReminderId = DateTime.now().millisecondsSinceEpoch;
      final timesPerDayCount = reminder.customReminder.timesPerDay?.count;
      final model = WaterReminderModel(
        id: waterReminderId,
        title: reminder.title,
        category: reminder.category,
        type: Option.times,
        alarms: createdAlarms,
        timesPerDay: reminder.customReminder.timesPerDay!.count,
        waterReminderStartTime: reminder.waterStartSafe,
        waterReminderEndTime: reminder.waterEndSafe,
      );
      waterList.value = await Get.find<WaterController>().loadWaterReminderList(
        "water_list",
      );
      waterList.add(model);
      await _reminderController.saveReminderList(waterList, "water_list");
      await _reminderController.loadAllReminderLists();

      // List<String> list =
      //     createdAlarms.map((e) => e.toJson().toString()).toList();
      //
    }
    final intervalHours = customReminder.everyXHours;
    if (intervalHours != null) {
      final startWaterString = customReminder.everyXHours?.startTime ?? '';
      final endWaterString = customReminder.everyXHours?.endTime ?? '';
      final startTime = stringToTimeOfDay(startWaterString);
      final endTime = stringToTimeOfDay(endWaterString);
      final intervalHours = customReminder.everyXHours?.hours ?? 0;
      final reminders = Get.find<WaterController>().generateEveryXHours(
        start: startTime,
        end: endTime,
        intervalHours: intervalHours,
      );
      await Get.find<WaterController>().setIntervalReminders(
        intervalReminders: reminders,
        intervalHours: intervalHours,
        title: reminder.title,
        body: reminder.notes ?? '',
      );
      for (var reminderTime in reminders) {
        final alarmSettings = AlarmSettings(
          id: alarmsId(),
          dateTime: reminderTime,
          notificationSettings: NotificationSettings(
            title: reminder.title,
            body: reminder.notes ?? '',
            stopButton: 'Stop',
            icon: 'alarm',
            iconColor: AppColors.primaryColor,
          ),
          androidFullScreenIntent: true,
          payload: jsonEncode({
            "type": "water",
            "interval": intervalHours,
            "start": startTime,
            "end": endTime,
          }),
          assetAudioPath: alarmSound,
          volumeSettings: VolumeSettings.fade(
            volume: 0.8,
            fadeDuration: Duration(seconds: 5),
            volumeEnforced: true,
          ),
        );

        await Alarm.set(alarmSettings: alarmSettings);
      }
      final waterReminderId = DateTime.now().millisecondsSinceEpoch;

      if (customReminder.everyXHours != null) {
        final model = WaterReminderModel(
          id: waterReminderId,
          title: reminder.title,
          alarms: [],
          timesPerDay: '',
          notes: reminder.notes ?? '',
          waterReminderStartTime: customReminder.everyXHours?.startTime ?? '',
          waterReminderEndTime: customReminder.everyXHours?.endTime ?? '',
          type: Option.interval,
          interval: '$intervalHours',
          category: "Water",
        );
        waterList.value = await Get.find<WaterController>()
            .loadWaterReminderList("water_list");
        waterList.add(model);

        await _reminderController.saveReminderList(waterList, "water_list");
        await _reminderController.loadAllReminderLists();

        final waterData = reminder_payload.ReminderPayloadModel(
          id: waterReminderId,
          category: "WATER",
          title: model.title,
          notes: model.notes,
          reminderFrequencyType: Option.interval.toString(),
          customReminder: reminder_payload.CustomReminder(
            everyXHours: reminder_payload.EveryXHours(
              hours: intervalHours,
              startTime: model.waterReminderStartTime,
              endTime: model.waterReminderEndTime,
            ),
          ),
          startWaterTime: '',
          endWaterTime: '',
        );
        debugPrint("Water Data setIntervalReminders scheduled : $waterData");
      }
    }
  }

  static Future<void> schedulePreReminder({
    required DateTime mainTime,
    required String category,
    required String body,
    required reminder_payload.ReminderPayloadModel reminder,
  }) async {
    final before = reminder.remindBefore!;
    final amount = before.time;
    final unit = before.unit;

    final offset =
        unit == 'minutes' ? Duration(minutes: amount) : Duration(hours: amount);

    DateTime beforeTime = mainTime.subtract(offset);
    if (beforeTime.isBefore(DateTime.now())) {
      beforeTime = beforeTime.add(const Duration(days: 1));
    }
    final alarmSettings = AlarmSettings(
      id: scheduledReminderId(reminderId: reminder.id, time: mainTime),
      dateTime: mainTime,
      assetAudioPath: alarmSound,
      volumeSettings: VolumeSettings.fade(
        volume: 0.8,
        fadeDuration: Duration(seconds: 5),
        volumeEnforced: true,
      ),
      notificationSettings: NotificationSettings(
        title: "Upcoming ${category.capitalizeFirst} Reminder",
        body: "$body $amount $unit",
        stopButton: 'Stop',
        icon: 'alarm',
        iconColor: AppColors.primaryColor,
      ),
      payload: jsonEncode({
        "type": "before",
        "category": category,
        "mainTime": mainTime.toIso8601String(),
      }),
    );
    await Alarm.set(alarmSettings: alarmSettings);
  }

  static Future<void> scheduleReminderFromModel({
    required reminder_payload.ReminderPayloadModel reminder,
    required String category,
    required RxList<Map<String, AlarmSettings>> reminderList,
    required String keyName,
    String? date,
  }) async {
    if (reminder.category != category) return;
    final times = reminder.timesSafe;

    if (times.isEmpty) return;
    for (final time in times) {
      final dateTime = buildDateTimeFromTimeString(time: time, date: date);
      final alarmSettings = AlarmSettings(
        id: scheduledReminderId(reminderId: reminder.id, time: dateTime),
        dateTime: dateTime,
        assetAudioPath: alarmSound,
        volumeSettings: VolumeSettings.fade(
          volume: 0.8,
          fadeDuration: Duration(seconds: 5),
          volumeEnforced: true,
        ),
        notificationSettings: NotificationSettings(
          title: reminder.title,
          body: reminder.notes ?? '',
          stopButton: 'Stop',
          icon: 'alarm',
          iconColor: AppColors.primaryColor,
        ),
      );
      final success = await Alarm.set(alarmSettings: alarmSettings);
      if (success) {
        reminderList.value = await _reminderController.loadReminderList(
          keyName,
        );

        final displayTitle =
            reminder.title.isNotEmpty
                ? reminder.title
                : '${category.toUpperCase()} REMINDER';
        reminderList.add({displayTitle: alarmSettings});
        await _reminderController.saveReminderList(reminderList, keyName);
        await _reminderController.loadAllReminderLists();
      }
    }
  }
}
