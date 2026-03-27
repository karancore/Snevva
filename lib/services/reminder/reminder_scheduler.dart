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

  static String _audioPathForCategory(String category) {
    final normalized = category.trim().toLowerCase();

    if (normalized.contains('water')) return waterSound;
    if (normalized.contains('meal')) return mealSound;
    if (normalized.contains('medicine')) return medicineSound;
    if (normalized.contains('event')) return eventSound;
    if (normalized.contains('sleep')) return sleepSound;

    return alarmSound;
  }

  /// ==============================
  /// SCHEDULE ALL REMINDERS
  /// ==============================
  Future<void> scheduleAll(
    List<reminder_payload.ReminderPayloadModel> reminders, {
    Set<int> deletedGroupIds = const {},
    Set<int> deletedAlarmIds = const {},
  }) async {
    debugPrint("📌 scheduleAll() called with ${reminders.length} reminders");

    for (final reminder in reminders) {
      try {
        debugPrint(
          "➡️ Processing reminder ID:${reminder.id} | Category:${reminder.category}",
        );

        reminder.validate();

        await _scheduleByCategory(
          reminder,
          deletedGroupIds: deletedGroupIds,
          deletedAlarmIds: deletedAlarmIds,
        );

        debugPrint("✅ Reminder scheduled successfully ID:${reminder.id}");
      } catch (e, s) {
        debugPrint("❌ Invalid reminder skipped: $e");
        debugPrint("📍 StackTrace: $s");
      }
    }
  }

  /// ==============================
  /// CATEGORY ROUTER
  /// ==============================
  static Future<void> _scheduleByCategory(
    reminder_payload.ReminderPayloadModel reminder, {
    required Set<int> deletedGroupIds,
    required Set<int> deletedAlarmIds,
  }) async {
    debugPrint("📂 Routing reminder category → ${reminder.category}");

    final category = (reminder.category ?? '').trim().toLowerCase();

    switch (category) {
      case 'medicine':
        if (deletedGroupIds.contains(reminder.id)) return;
        debugPrint("💊 Scheduling Medicine Reminder");
        await scheduleMedicineReminder(reminder: reminder);
        break;

      case 'water':
        if (deletedGroupIds.contains(reminder.id)) return;
        debugPrint("💧 Scheduling Water Reminder");
        await scheduleWaterReminder(reminder: reminder);
        break;

      case 'meal':
        debugPrint("🍽 Scheduling Meal Reminder");
        await scheduleReminderFromModel(
          reminder: reminder,
          category: 'meal',
          keyName: "meals_list",
          reminderList: mealsList,
          deletedAlarmIds: deletedAlarmIds,
        );
        break;

      case 'event':
        debugPrint("📅 Scheduling Event Reminder");

        final timesList = reminder.timesSafe;
        final date = reminder.startDate;

        debugPrint("Event times list: $timesList");

        // Schedule main event alarm(s)
        await scheduleReminderFromModel(
          reminder: reminder,
          category: 'event',
          keyName: "event_list",
          reminderList: eventList,
          date: date,
          deletedAlarmIds: deletedAlarmIds,
        );

        if (reminder.remindBefore != null && timesList.isNotEmpty) {
          final timeString = timesList.first;

          final mainTime = buildDateTimeFromTimeString(
            time: timeString,
            date: date,
          );

          if (mainTime.isBefore(DateTime.now())) {
            debugPrint("⛔ Skipping pre-reminder, event already passed");
          } else {
            debugPrint("⏳ Scheduling pre reminder before event");

            await schedulePreReminder(
              mainTime: mainTime,
              category: 'event',
              body: "Your scheduled event will start in ",
              reminder: reminder,
            );
          }
        }
        break;

      default:
        debugPrint("⚠️ Unknown category ${reminder.category}");
    }
  }

  /// ==============================
  /// GENERATE ALARM ID
  /// ==============================
  static int scheduledReminderId({
    required int reminderId,
    required DateTime time,
  }) {
    final id = buildAlarmId(groupId: reminderId, time: time);
    debugPrint("🔢 Generated alarm id: $id");
    return id;
  }

  /// ==============================
  /// MEDICINE REMINDER
  /// ==============================
  static Future<void> scheduleMedicineReminder({
    required reminder_payload.ReminderPayloadModel reminder,
  }) async {
    debugPrint("💊 scheduleMedicineReminder() called");

    final timesList = reminder.medicineTimesSafe;

    debugPrint("Medicine times: $timesList");

    final date = reminder.startDate;

    List<DateTime> scheduledTimes =
        timesList
            .map((e) => buildDateTimeFromTimeString(time: e, date: date))
            .toList();

    debugPrint("Generated scheduledTimes: $scheduledTimes");

    final List<AlarmSettings> alarms = [];

    for (final scheduledTime in scheduledTimes) {
      debugPrint("⏰ Scheduling medicine alarm at $scheduledTime");

      if (scheduledTime.isBefore(DateTime.now())) {
        debugPrint("⛔ Skipping past medicine reminder at $scheduledTime");
        continue;
      }

      final alarmId = alarmsId();

      final alarmSettings = AlarmSettings(
        id: alarmId,
        dateTime: scheduledTime,
        assetAudioPath: medicineSound,
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

      debugPrint("Alarm set result: $success");

      if (success) {
        alarms.add(alarmSettings);
      }
    }

    debugPrint("Total medicine alarms scheduled: ${alarms.length}");
  }

  /// ==============================
  /// MEDICINE TEXT
  /// ==============================
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

  /// ==============================
  /// WATER REMINDER
  /// ==============================
  static Future<void> scheduleWaterReminder({
    required reminder_payload.ReminderPayloadModel reminder,
  }) async {
    debugPrint("💧 scheduleWaterReminder called");

    final customReminder = reminder.customReminder;
    final waterController = Get.find<WaterController>();

    if (customReminder.everyXHours != null) {
      final interval = customReminder.everyXHours!;
      final start = reminder.waterStartSafe;
      final end = reminder.waterEndSafe;

      debugPrint(
        "Water interval: every ${interval.hours} hour(s) between $start and $end",
      );

      final startTod = parseTimeNew(start);
      final endTod = parseTimeNew(end);

      final intervalTimes = waterController.generateEveryXHours(
        start: startTod,
        end: endTod,
        intervalHours: interval.hours,
      );

      debugPrint("Generated water interval times: $intervalTimes");

      for (final time in intervalTimes) {
        final scheduledTime =
            time.isBefore(DateTime.now())
                ? time.add(const Duration(days: 1))
                : time;

        debugPrint("⏰ Scheduling water interval alarm at $scheduledTime");

        final alarmSettings = AlarmSettings(
          id: scheduledReminderId(reminderId: reminder.id, time: scheduledTime),
          dateTime: scheduledTime,
          assetAudioPath: waterSound,
          volumeSettings: VolumeSettings.fade(
            volume: 0.8,
            fadeDuration: Duration(seconds: 5),
            volumeEnforced: true,
          ),
          payload: jsonEncode({
            "groupId": reminder.id.toString(),
            "category": ReminderCategory.water.name,
            "type": "interval",
          }),
          notificationSettings: NotificationSettings(
            title: reminder.title,
            body: reminder.notes ?? '',
            stopButton: 'Stop',
            icon: 'alarm',
            iconColor: AppColors.primaryColor,
          ),
        );

        final success = await Alarm.set(alarmSettings: alarmSettings);
        debugPrint("Water interval alarm set result: $success");
      }
      return;
    }

    if (customReminder.timesPerDay != null) {
      final times = reminder.waterTimesCountSafe;
      debugPrint("Water times per day: $times");
      final alarmTimes = waterController.generateTimesBetween(
        startTime: reminder.waterStartSafe,
        endTime: reminder.waterEndSafe,
        times: times,
      );

      debugPrint("Generated water alarm times: $alarmTimes");

      for (var time in alarmTimes) {
        final scheduledTime =
            time.isBefore(DateTime.now()) ? time.add(Duration(days: 1)) : time;

        debugPrint("⏰ Scheduling water alarm at $scheduledTime");

        final alarmSettings = AlarmSettings(
          id: scheduledReminderId(reminderId: reminder.id, time: scheduledTime),
          dateTime: scheduledTime,
          assetAudioPath: waterSound,
          volumeSettings: VolumeSettings.fade(
            volume: 0.8,
            fadeDuration: Duration(seconds: 5),
            volumeEnforced: true,
          ),
          payload: jsonEncode({
            "groupId": reminder.id.toString(),
            "category": ReminderCategory.water.name,
            "type": "times",
          }),
          notificationSettings: NotificationSettings(
            title: reminder.title,
            body: reminder.notes ?? '',
            stopButton: 'Stop',
            icon: 'alarm',
            iconColor: AppColors.primaryColor,
          ),
        );

        final success = await Alarm.set(alarmSettings: alarmSettings);

        debugPrint("Water alarm set result: $success");
      }
      return;
    }

    debugPrint(
      "⚠️ Water reminder has no schedule data, skipping (id=${reminder.id})",
    );
  }

  /// ==============================
  /// PRE REMINDER
  /// ==============================
  static Future<void> schedulePreReminder({
    required DateTime mainTime,
    required String category,
    required String body,
    required reminder_payload.ReminderPayloadModel reminder,
  }) async {
    debugPrint("⏳ schedulePreReminder called");

    final before = reminder.remindBefore!;
    final amount = before.time;
    final unit = before.unit;

    final offset =
        unit == 'minutes' ? Duration(minutes: amount) : Duration(hours: amount);

    DateTime beforeTime = mainTime.subtract(offset);

    if (beforeTime.isBefore(DateTime.now())) {
      debugPrint("⛔ Skipping past pre-reminder at $beforeTime");
      return;
    }

    debugPrint("MainTime: $mainTime");
    debugPrint("PreReminderTime: $beforeTime");

    final alarmSettings = AlarmSettings(
      id: scheduledReminderId(reminderId: reminder.id, time: beforeTime),
      dateTime: beforeTime,
      assetAudioPath: remindBeforeSound,
      volumeSettings: VolumeSettings.fade(
        volume: 0.8,
        fadeDuration: Duration(seconds: 5),
        volumeEnforced: true,
      ),
      payload: jsonEncode({
        "groupId": reminder.id.toString(),
        "category": category,
        "type": "before",
        "mainTime": mainTime.toIso8601String(),
      }),
      notificationSettings: NotificationSettings(
        title: "Upcoming ${category.capitalizeFirst} Reminder",
        body: "$body $amount $unit",
        stopButton: 'Stop',
        icon: 'alarm',
        iconColor: AppColors.primaryColor,
      ),
    );

    final success = await Alarm.set(alarmSettings: alarmSettings);

    debugPrint("PreReminder scheduled: $success");
  }

  /// ==============================
  /// GENERIC REMINDER
  /// ==============================
  static Future<void> scheduleReminderFromModel({
    required reminder_payload.ReminderPayloadModel reminder,
    required String category,
    required RxList<Map<String, AlarmSettings>> reminderList,
    required String keyName,
    String? date,
    Set<int> deletedAlarmIds = const {},
  }) async {
    debugPrint("📌 scheduleReminderFromModel called for $category");

    final times = reminder.timesSafe;

    debugPrint("Reminder times: $times");

    if (times.isEmpty) {
      debugPrint("⚠️ No times found. Skipping.");
      return;
    }

    for (final time in times) {
      final dateTime = buildDateTimeFromTimeString(time: time, date: date);

      if (dateTime.isBefore(DateTime.now())) {
        debugPrint("⛔ Skipping past $category reminder at $dateTime");
        continue;
      }

      final alarmId = scheduledReminderId(
        reminderId: reminder.id,
        time: dateTime,
      );
      if (deletedAlarmIds.contains(alarmId)) {
        debugPrint("🧹 Skip deleted $category occurrence (alarmId=$alarmId)");
        continue;
      }

      debugPrint("⏰ Scheduling $category alarm at $dateTime");

      final alarmSettings = AlarmSettings(
        id: alarmId,
        dateTime: dateTime,
        assetAudioPath: _audioPathForCategory(category),
        volumeSettings: VolumeSettings.fade(
          volume: 0.8,
          fadeDuration: Duration(seconds: 5),
          volumeEnforced: true,
        ),
        payload: jsonEncode({
          "groupId": reminder.id.toString(),
          "category": category,
          "type": "times",
        }),
        notificationSettings: NotificationSettings(
          title: reminder.title,
          body: reminder.notes ?? '',
          stopButton: 'Stop',
          icon: 'alarm',
          iconColor: AppColors.primaryColor,
        ),
      );

      final success = await Alarm.set(alarmSettings: alarmSettings);

      debugPrint("Alarm set result: $success");
    }
  }
}
