import 'dart:async';
import 'dart:convert';

import 'package:alarm/alarm.dart';
import 'package:intl/intl.dart';
import 'package:snevva/Controllers/Reminder/reminder_controller.dart';
import 'package:snevva/common/global_variables.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/models/hive_models/reminder_payload_model.dart';
import 'package:snevva/models/reminder_schedule_metadata.dart';
import 'package:snevva/services/hive_service.dart';
import 'package:snevva/services/reminder/native_alarm_bridge.dart';
import 'package:snevva/services/reminder/reminder_alarm_transaction.dart';
import 'package:snevva/services/reminder/reminder_schedule_resolver.dart';

import '../../common/custom_snackbar.dart';
import '../../models/reminders/water_reminder_model.dart';

class WaterController extends GetxController {
  var waterReminderOption = Option.times.obs;
  final everyHourController = TextEditingController();
  final timesPerDayController = TextEditingController();
  final startWaterTimeController = TextEditingController();
  final endWaterTimeController = TextEditingController();
  var waterList = <WaterReminderModel>[].obs;
  var savedTimes = 0.obs;
  final everyXhours = 1.obs;

  final startWaterTime = Rx<TimeOfDay?>(null);
  final endWaterTime = Rx<TimeOfDay?>(null);

  ReminderController get reminderController =>
      Get.find<ReminderController>(tag: 'reminder');

  @override
  void onInit() {
    super.onInit();
    everyHourController.addListener(() {
      final value = int.tryParse(everyHourController.text) ?? 1;
      everyXhours.value = value;
    });
    timesPerDayController.addListener(() {
      final value = int.tryParse(timesPerDayController.text) ?? 1;
      savedTimes.value = value;
    });
  }

  void resetForm() {
    // ---------- Text controllers ----------
    everyHourController.clear();
    timesPerDayController.clear();
    startWaterTimeController.clear();
    endWaterTimeController.clear();

    // ---------- Rx values ----------
    waterReminderOption.value = Option.times;
    savedTimes.value = 0;
    everyXhours.value = 1;

    startWaterTime.value = null;
    endWaterTime.value = null;

    // ---------- Local state ----------
    waterList.clear(); // optional: remove if you want to keep loaded reminders
  }

  Future<void> initialiseWaterReminder() async {
    debugPrint("🔄 initialiseWaterReminder called");

    final list = await loadWaterReminderList("water_list");

    if (list.isEmpty) {
      debugPrint("🚫 No water reminders found → skip reschedule");
      return;
    }

    debugPrint("📦 Loaded ${list.length} water reminders");

    if (savedTimes.value <= 0) {
      debugPrint("⚠️ savedTimes is 0 → nothing to schedule");
      return;
    }

    final todayTimes = generateTimesBetween(
      startTime: startWaterTimeController.text,
      endTime: endWaterTimeController.text,
      times: savedTimes.value,
    );

    debugPrint("⏰ Generated ${todayTimes.length} times");

    DateTime? nextTime;
    for (final time in todayTimes) {
      if (time.isAfter(now)) {
        nextTime = time;
        break;
      }
    }

    nextTime ??= todayTimes.first.add(const Duration(days: 1));

    debugPrint("🔔 Next water alarm at $nextTime");

    final alarm = AlarmSettings(
      id: alarmsId(),
      dateTime: nextTime,
      assetAudioPath: waterSound,
      loopAudio: false,
      androidFullScreenIntent: false,
      volumeSettings: VolumeSettings.fade(
        volume: 0.8,
        fadeDuration: const Duration(seconds: 5),
        volumeEnforced: true,
      ),
      notificationSettings: NotificationSettings(
        title:
            reminderController.titleController.text.isNotEmpty
                ? reminderController.titleController.text
                : 'WATER REMINDER',
        body:
            reminderController.notesController.text.isNotEmpty
                ? reminderController.notesController.text
                : 'Time to drink water!',
        stopButton: 'Stop',
        icon: 'alarm',
        iconColor: AppColors.primaryColor,
      ),
    );

    // Native AlarmManager is the sole scheduler — skip Alarm.set().
    // 📲 Arm via native Kotlin layer
    await NativeAlarmBridge.armAlarm(
      alarmId: alarm.id,
      epochMs: alarm.dateTime.millisecondsSinceEpoch,
      groupId: alarm.id.toString(),
      category: 'water',
      title: alarm.notificationSettings.title,
      body: alarm.notificationSettings.body,
    );
    debugPrint("✅ Initial water alarm scheduled");
  }

  // ---------------------------------------------------------------------------
  // Validation & Save
  // ---------------------------------------------------------------------------

  bool validateWaterInput(BuildContext context) {
    if (startWaterTimeController.text.isEmpty) {
      debugPrint("❌ Start time missing");
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Please enter start time',
      );
      return false;
    }

    if (endWaterTimeController.text.isEmpty) {
      debugPrint("❌ End time missing");
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Please enter end time',
      );
      return false;
    }

    if (waterReminderOption.value == Option.interval) {
      final intervalHours = int.tryParse(everyHourController.text) ?? 0;
      if (intervalHours <= 0) {
        debugPrint("❌ Invalid interval");
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Please enter a valid hours interval',
        );
        return false;
      }
    }

    if (waterReminderOption.value == Option.times) {
      final times = int.tryParse(timesPerDayController.text) ?? 0;
      if (times <= 0) {
        debugPrint("❌ Invalid times-per-day");
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Please enter a valid number of times per day',
        );
        return false;
      }
    }

    return true;
  }

  Future<bool> validateAndSaveWaterReminder(
    BuildContext context, {
    int? reminderIdOverride,
  }) async {
    debugPrint("📝 validateAndSaveWaterReminder called");
    debugPrint("🔧 Mode = ${waterReminderOption.value}");

    if (!validateWaterInput(context)) {
      return false;
    }

    if (waterReminderOption.value == Option.interval) {
      final intervalHours = int.tryParse(everyHourController.text) ?? 0;
      debugPrint("⏱ Interval mode → every $intervalHours hours");

      final reminders = generateEveryXHours(
        start: stringToTimeOfDay(startWaterTimeController.text),
        end: stringToTimeOfDay(endWaterTimeController.text),
        intervalHours: intervalHours,
      );

      debugPrint("⏰ Generated ${reminders.length} interval alarms");

      if (reminders.isEmpty) {
        debugPrint("❌ No reminders generated");
        return false;
      }

      await setIntervalReminders(
        intervalReminders: reminders,
        context: context,
        title: 'Water',
        intervalHours: intervalHours,
        audioPath: waterSound,
        body: reminderController.notesController.text.trim(),
        reminderIdOverride: reminderIdOverride,
      );
      return true;
    }

    if (waterReminderOption.value == Option.times) {
      final times = int.tryParse(timesPerDayController.text) ?? 0;
      debugPrint("🔁 Times-per-day mode → $times times");

      await setWaterAlarm(
        times: times,
        context: context,
        audioPath: waterSound,
        reminderIdOverride: reminderIdOverride,
      );
      return true;
    }

    debugPrint("❌ Unknown reminder option");
    return false;
  }

  // ---------------------------------------------------------------------------
  // Time Generators
  // ---------------------------------------------------------------------------

  Future<void> setWaterAlarm({
    required int? times,
    required BuildContext context,
    String audioPath = alarmSound,
    int? reminderIdOverride,
  }) async {
    if (times == null || times <= 0) {
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Please enter a valid number of times per day',
      );
      return;
    }
    final reminderGroupId = reminderIdOverride ?? alarmsId();
    final waterData = await _buildWaterPayload(
      reminderId: reminderGroupId,
      timesOverride: times,
    );

    ReminderAlarmTransactionResult? transaction;
    try {
      transaction = await reminderController.scheduleReminderLocally(waterData);
      final model = _buildWaterModel(transaction.reminder, transaction);

      waterList.value = await loadWaterReminderList("water_list");
      waterList.add(model);
      savedTimes.value = times;

      await reminderController.saveReminderList(waterList, "water_list");
      await reminderController.loadAllReminderLists();
      unawaited(
        reminderController
            .addRemindertoAPI(transaction.reminder, context)
            .catchError((e) {
              debugPrint('⚠️ Background water add API failed: $e');
            }),
      );

      CustomSnackbar().showReminderBar(context);
      Get.back(result: true);
    } catch (e) {
      if (transaction != null) {
        await reminderController.rollbackReminderSchedule(transaction.reminder);
      }
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Failed to save water reminder',
      );
      debugPrint('❌ Failed to create water reminder: $e');
    }
  }

  List<DateTime> generateTimesBetween({
    required String startTime,
    required String endTime,
    required int times,
  }) {
    debugPrint(
      "🧮 generateTimesBetween → start=$startTime end=$endTime times=$times",
    );

    if (times <= 0) return [];

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

    if (endDT.isBefore(startDT)) {
      debugPrint("🌙 Overnight window detected");
      endDT = endDT.add(const Duration(days: 1));
    }

    final totalMinutes = endDT.difference(startDT).inMinutes;
    final gap = (totalMinutes / times).floor();

    debugPrint("⏱ totalMinutes=$totalMinutes gap=$gap");

    return List.generate(times, (i) {
      final t = startDT.add(Duration(minutes: gap * i));
      debugPrint("⏰ Generated time[$i] → $t");
      return t;
    });
  }

  List<DateTime> generateEveryXHours({
    required TimeOfDay start,
    required TimeOfDay end,
    required int intervalHours,
  }) {
    debugPrint("⏱ generateEveryXHours → every $intervalHours hours");

    if (intervalHours <= 0) return [];

    final window = buildTimeWindow(start, end);
    final reminders = <DateTime>[];

    DateTime current = window.start.add(Duration(hours: intervalHours));
    int counter = 0;

    while (!current.isAfter(window.end)) {
      reminders.add(current);
      debugPrint("⏰ Interval reminder → $current");

      current = current.add(Duration(hours: intervalHours));
      counter++;

      if (counter > 100) {
        debugPrint("⚠️ Safety break triggered");
        break;
      }
    }

    return reminders;
  }

  Future<void> onWaterAlarmRang(int rangAlarmId) async {
    // Check Hive (not Alarm.getAlarms()) because alarms are armed natively and
    // won't appear in the Flutter alarm package's list.
    final currentList = await loadWaterReminderList("water_list");
    final stillExists = currentList.isNotEmpty;
    if (!stillExists) {
      debugPrint("Water reminder deleted, skip reschedule");
      return;
    }

    /// Load from your existing function
    List<Map<String, AlarmSettings>> list = await reminderController
        .loadReminderList("water_list");

    for (int i = 0; i < list.length; i++) {
      final map = list[i];

      for (final entry in map.entries) {
        final String title = entry.key;
        final AlarmSettings alarm = entry.value;

        /// FOUND the alarm that rang
        if (alarm.id == rangAlarmId) {
          debugPrint("🚰 Found rang water alarm: $rangAlarmId ($title)");

          /// IMPORTANT: stop previous instance
          await Alarm.stop(rangAlarmId);

          /// Calculate next day same time
          DateTime nextTime = DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
            alarm.dateTime.hour,
            alarm.dateTime.minute,
          ).add(const Duration(days: 1));

          if (nextTime.isBefore(DateTime.now())) {
            nextTime = nextTime.add(const Duration(days: 1));
          }

          /// Create new alarm
          final newAlarm = AlarmSettings(
            id: rangAlarmId,
            // reuse SAME id
            dateTime: nextTime,
            assetAudioPath: alarm.assetAudioPath,
            loopAudio: true,
            vibrate: true,
            volumeSettings: alarm.volumeSettings,
            notificationSettings: alarm.notificationSettings,
          );

          /// Replace inside map
          list[i][title] = newAlarm;

          /// Convert back to JSON string list (VERY IMPORTANT)
          final List<String> encoded =
              list.map((mapItem) {
                final encodedMap = mapItem.map(
                  (k, v) => MapEntry(k, v.toJson()),
                );
                return jsonEncode(encodedMap);
              }).toList();

          /// Save back to Hive
          final box = await HiveService().remindersBox();
          await box.put("water_list", encoded);

          // ✅ Bug fix: arm the next-day alarm via native AlarmManager.
          // Previously the Hive update was written but NativeAlarmBridge was
          // never called, so the alarm was not actually scheduled natively.
          await NativeAlarmBridge.armAlarm(
            alarmId: rangAlarmId,
            epochMs: nextTime.millisecondsSinceEpoch,
            groupId: rangAlarmId.toString(),
            category: 'water',
            title: newAlarm.notificationSettings.title,
            body: newAlarm.notificationSettings.body,
          );

          debugPrint("🔁 Water alarm rescheduled for $nextTime");

          return;
        }
      }
    }

    debugPrint("⚠️ Rang alarm not found in water_list: $rangAlarmId");
  }

  Future<void> setIntervalReminders({
    required List<DateTime> intervalReminders,
    required int intervalHours,
    BuildContext? context,
    required String title,
    required String body,
    String audioPath = alarmSound,
    int? reminderIdOverride,
  }) async {
    final reminderGroupId = reminderIdOverride ?? alarmsId();
    final waterData = await _buildWaterPayload(
      reminderId: reminderGroupId,
      intervalOverride: intervalHours,
    );

    ReminderAlarmTransactionResult? transaction;
    try {
      transaction = await reminderController.scheduleReminderLocally(waterData);
      final model = _buildWaterModel(transaction.reminder, transaction);

      waterList.value = await loadWaterReminderList("water_list");
      waterList.add(model);
      await reminderController.saveReminderList(waterList, "water_list");
      await reminderController.loadAllReminderLists();
      if (context != null) {
        unawaited(
          reminderController
              .addRemindertoAPI(transaction.reminder, context)
              .catchError((e) {
                debugPrint('⚠️ Background water interval add API failed: $e');
              }),
        );
        CustomSnackbar().showReminderBar(context);
      }
      Get.back(result: true);
    } catch (e) {
      if (transaction != null) {
        await reminderController.rollbackReminderSchedule(transaction.reminder);
      }
      if (context != null) {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Failed to save water reminder',
        );
      }
      debugPrint('❌ Failed to create interval water reminder: $e');
    }
  }

  Future<void> updateWaterReminderFromLocal(
    BuildContext context,
    String id,
    int? times,
  ) async {
    try {
      final parsedId = int.tryParse(id);
      if (parsedId == null) return;
      waterList.value = await loadWaterReminderList("water_list");

      final index = waterList.indexWhere((e) => e.id == parsedId);
      if (index == -1) return;

      final oldModel = waterList[index];
      final waterData = await _buildWaterPayload(
        reminderId: parsedId,
        existingMetadata: oldModel.scheduleMetadata,
        timesOverride: times,
      );

      ReminderAlarmTransactionResult? transaction;
      try {
        transaction = await reminderController.scheduleReminderLocally(
          waterData,
        );
        final updatedModel = _buildWaterModel(
          transaction.reminder,
          transaction,
        );

        waterList[index] = updatedModel;
        savedTimes.value =
            int.tryParse(updatedModel.timesPerDay) ?? savedTimes.value;

        await reminderController.saveReminderList(waterList, "water_list");

        final obsoleteIds = <int>{
          ...oldModel.scheduleMetadata.alarmIds,
          ...oldModel.scheduleMetadata.preAlarmIds,
        }..removeAll({
          ...transaction.reminder.scheduleMetadata.alarmIds,
          ...transaction.reminder.scheduleMetadata.preAlarmIds,
        });
        await reminderController.stopReminderAlarmIds(obsoleteIds);

        await reminderController.loadAllReminderLists();
        CustomSnackbar().showReminderBar(context);
        Get.back(result: true);
        unawaited(
          reminderController
              .updateReminder(transaction.reminder, context)
              .catchError((e) {
                debugPrint('⚠️ Background water update API failed: $e');
              }),
        );
      } catch (e) {
        if (transaction != null) {
          await reminderController.rollbackReminderSchedule(
            transaction.reminder,
          );
        }
        rethrow;
      }
    } catch (e) {
      throw Exception("Error updating WATER reminder: $e");
    }
  }

  Future<ReminderPayloadModel> _buildWaterPayload({
    required int reminderId,
    ReminderScheduleMetadata? existingMetadata,
    int? timesOverride,
    int? intervalOverride,
  }) async {
    final title = reminderController.titleController.text.trim();
    final notes = reminderController.notesController.text.trim();
    final startTime = canonicalLocalTime(startWaterTimeController.text.trim());
    final endTime = canonicalLocalTime(endWaterTimeController.text.trim());
    final isIntervalMode = waterReminderOption.value == Option.interval;

    final customReminder =
        isIntervalMode
            ? CustomReminder(
              type: Option.interval,
              everyXHours: EveryXHours(
                hours:
                    intervalOverride ??
                    (int.tryParse(everyHourController.text.trim()) ?? 0),
                startTime: startTime,
                endTime: endTime,
              ),
            )
            : CustomReminder(
              type: Option.times,
              timesPerDay: TimesPerDay(
                count:
                    (timesOverride ??
                            int.tryParse(timesPerDayController.text.trim()) ??
                            0)
                        .toString(),
                list:
                    generateTimesBetween(
                          startTime: startWaterTimeController.text.trim(),
                          endTime: endWaterTimeController.text.trim(),
                          times:
                              timesOverride ??
                              (int.tryParse(
                                    timesPerDayController.text.trim(),
                                  ) ??
                                  0),
                        )
                        .map((dateTime) => DateFormat('HH:mm').format(dateTime))
                        .toList(),
              ),
            );

    return ReminderPayloadModel(
      id: reminderId,
      category: 'water',
      title: title,
      notes: notes,
      reminderFrequencyType: customReminder.type?.name,
      customReminder: customReminder,
      startWaterTime: startTime,
      endWaterTime: endTime,
      scheduleMetadata: await reminderController.buildScheduleMetadata(
        category: 'water',
        semantics: ScheduleSemantics.wallClock,
        existing: existingMetadata,
      ),
    );
  }

  WaterReminderModel _buildWaterModel(
    ReminderPayloadModel reminder,
    ReminderAlarmTransactionResult transaction,
  ) {
    final type = reminder.customReminder.type ?? Option.times;
    return WaterReminderModel(
      id: reminder.id,
      title:
          reminder.title.trim().isNotEmpty ? reminder.title : 'WATER REMINDER',
      category: ReminderCategory.water.toString(),
      type: type,
      alarms: transaction.mainAlarms,
      timesPerDay: reminder.customReminder.timesPerDay?.count ?? '',
      waterReminderStartTime: reminder.startWaterTime?.trim() ?? '',
      waterReminderEndTime: reminder.endWaterTime?.trim() ?? '',
      interval:
          type == Option.interval
              ? reminder.customReminder.everyXHours?.hours.toString()
              : null,
      notes: reminder.notes?.trim(),
      updatedAt: reminder.updatedAt,
      scheduleMetadata: reminder.scheduleMetadata,
    );
  }

  Future<List<WaterReminderModel>> loadWaterReminderList(String keyName) async {
    final box = await HiveService().remindersBox();
    final List<dynamic>? storedList = box.get(keyName);

    if (storedList == null) {
      return [];
    }

    final List<String> stringList = storedList.cast<String>();
    List<WaterReminderModel> loadedList = [];

    for (var i = 0; i < stringList.length; i++) {
      final item = stringList[i];

      try {
        final Map<String, dynamic> decoded = jsonDecode(item);

        if (_looksLikeStructuredWaterReminder(decoded)) {
          final model = WaterReminderModel.fromJson(decoded);
          loadedList.add(model);
        } else {
          final entry = decoded.entries.first;
          final fallbackModel = WaterReminderModel(
            title: entry.key,
            id: alarmsId(),
            alarms: [],
            notes: reminderController.notesController.text.trim(),
            type: waterReminderOption.value,
            timesPerDay: timesPerDayController.text,
            category: ReminderCategory.water.toString(),
            waterReminderStartTime: startWaterTimeController.text.trim(),
            waterReminderEndTime: endWaterTimeController.text.trim(),
          );

          loadedList.add(fallbackModel);
        }
      } catch (e, stack) {
        debugPrint(' Error parsing water reminder: $e');
        debugPrint(stack.toString());
      }
    }
    return loadedList;
  }

  bool _looksLikeStructuredWaterReminder(Map<String, dynamic> json) {
    return json.containsKey('id') ||
        json.containsKey('Id') ||
        json.containsKey('type') ||
        json.containsKey('Type') ||
        json.containsKey('timesPerDay') ||
        json.containsKey('TimesPerDay') ||
        json.containsKey('interval') ||
        json.containsKey('Interval') ||
        json.containsKey('waterReminderStartTime') ||
        json.containsKey('WaterReminderStartTime') ||
        json.containsKey('StartWaterTime') ||
        json.containsKey('waterReminderEndTime') ||
        json.containsKey('WaterReminderEndTime') ||
        json.containsKey('EndWaterTime') ||
        json.containsKey('alarms') ||
        json.containsKey('Alarms');
  }

  // Future<void> deleteWaterReminder(int id) async {
  //   debugPrint('🗑️ deleteWaterReminder called with id=$id');
  //
  //   int index = -1;
  //
  //   for (int i = 0; i < waterList.length; i++) {
  //     debugPrint(
  //       '🔍 Checking waterList[$i] → storedId=${waterList[i].id} '
  //       '(type=${waterList[i].id.runtimeType})',
  //     );
  //
  //     if (waterList[i].id == id) {
  //       index = i;
  //       break;
  //     }
  //   }
  //
  //   if (index != -1) {
  //     debugPrint('✅ Water reminder found at index=$index');
  //
  //     for (var alarm in waterList[index].alarms) {
  //       debugPrint('⏹️ Stopping alarm id=${alarm.id}');
  //       await Alarm.stop(alarm.id);
  //     }
  //
  //     waterList.removeAt(index);
  //     debugPrint('🗑️ Removed water reminder. Remaining=${waterList.length}');
  //
  //     await reminderController.saveReminderList(waterList, "water_list");
  //     debugPrint('💾 Water list saved to Hive');
  //   } else {
  //     debugPrint('❌ No water reminder found with id=$id');
  //   }
  // }

  Future<void> deleteWaterReminder(int reminderId) async {
    debugPrint("🗑️ deleteWaterReminder called → id=$reminderId");
    waterList.value = await loadWaterReminderList("water_list");

    // Collect every native alarm ID that belongs to this reminder so we can
    // cancel them from AlarmManager AND remove them from SharedPrefs.
    final nativeIdsToCancel = <int>{};

    final alarms = await Alarm.getAlarms();

    for (final alarm in alarms) {
      if (alarm.payload == null) continue;
      try {
        final decoded = jsonDecode(alarm.payload!);
        final category = decoded['category']?.toString();
        final groupId = decoded['groupId']?.toString();
        if (_isWaterCategory(category) && groupId == reminderId.toString()) {
          debugPrint("⏹️ Stopping alarm ${alarm.id}");
          await Alarm.stop(alarm.id);
          nativeIdsToCancel.add(alarm.id);
        }
      } catch (e) {
        debugPrint("❌ Payload parse error: $e");
      }
    }

    final index = waterList.indexWhere((e) => e.id == reminderId);
    if (index != -1) {
      final model = waterList[index];

      // Also collect IDs stored inside the model (covers the native-only path
      // where Alarm.getAlarms() may return nothing because flutter_alarm is
      // bypassed but the AlarmManager entry is still live).
      for (final a in model.alarms) {
        nativeIdsToCancel.add(a.id);
      }
      nativeIdsToCancel.addAll(model.scheduleMetadata.alarmIds);
      nativeIdsToCancel.addAll(model.scheduleMetadata.preAlarmIds);

      waterList.removeAt(index);
      debugPrint("✅ Water reminder removed from list");
    }

    // ✅ Bug fix: also collect IDs from the legacy Map<String, AlarmSettings>
    // format (written by the old onWaterAlarmRang reschedule path).
    // Those IDs were never stored in scheduleMetadata so they would escape
    // the loops above, leaving ghost alarms alive after deletion.
    try {
      final legacyList = await reminderController.loadReminderList(
          "water_list");
      for (final map in legacyList) {
        for (final alarm in map.values) {
          if (nativeIdsToCancel.add(alarm.id)) {
            debugPrint(
                "⏹️ Collecting legacy alarm id=${alarm.id} for cancellation");
          }
        }
      }
    } catch (e) {
      debugPrint("⚠️ Could not load legacy water_list for cleanup: $e");
    }

    // ✅ KEY FIX: cancel native AlarmManager entries AND remove from SharedPrefs
    // so BootReceiver cannot re-arm them after a reboot.
    if (nativeIdsToCancel.isNotEmpty) {
      debugPrint(
        "🗑️ Cancelling ${nativeIdsToCancel.length} native alarms: $nativeIdsToCancel",
      );
      await NativeAlarmBridge.cancelAlarms(
        nativeIdsToCancel.toList(growable: false),
      );
    }

    await reminderController.saveReminderList(waterList, "water_list");
    debugPrint("💾 Water list saved after delete");
  }

  bool _isWaterCategory(String? category) {
    if (category == null) return false;
    return category == 'water' || category == ReminderCategory.water.toString();
  }

  void resetControllers() {
    timesPerDayController.clear();

    startWaterTimeController.clear();
    endWaterTimeController.clear();
    savedTimes.value = 0;
    startWaterTime.value = null;
    endWaterTime.value = null;
    everyXhours.value = 1;
    waterReminderOption.value = Option.times;
  }

  @override
  void onClose() {
    everyHourController.dispose();
    timesPerDayController.dispose();
    startWaterTimeController.dispose();
    endWaterTimeController.dispose();
    super.onClose();
  }
}
