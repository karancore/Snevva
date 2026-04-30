import 'dart:async';
import 'dart:convert';

import 'package:alarm/alarm.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
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
import 'package:snevva/models/mappers/reminder_api_mapper.dart';
import 'package:snevva/models/mappers/reminder_payload_mapper.dart';
import 'package:snevva/models/reminder_schedule_metadata.dart';
import 'package:snevva/services/api_service.dart';
import 'package:snevva/services/reminder/native_alarm_bridge.dart';
import 'package:snevva/services/reminder/reminder_scheduler.dart';
import 'package:snevva/services/reminder/device_timezone_service.dart';
import 'package:snevva/services/reminder/reminder_alarm_transaction.dart';
import 'package:snevva/services/reminder/reminder_identity.dart';
import 'package:snevva/services/reminder/reminder_schedule_resolver.dart';
import 'package:timezone/timezone.dart' as tz;

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

@visibleForTesting
List<String> normalizeReminderTimesForPersistence(List<String>? rawTimes) {
  if (rawTimes == null || rawTimes.isEmpty) return const [];

  final normalized = <String>[];
  for (final raw in rawTimes) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) continue;

    try {
      normalized.add(canonicalLocalTime(trimmed));
    } catch (_) {
      // Ignore malformed values instead of crashing reminder hydration.
    }
  }

  return normalized;
}

@visibleForTesting
DateTime reminderDateTimeInTimezone(
  DateTime scheduledTime, {
  required String timezoneId,
}) {
  final normalizedTimezoneId = timezoneId.trim();
  if (normalizedTimezoneId.isEmpty ||
      normalizedTimezoneId.toLowerCase() == 'local') {
    return scheduledTime.toLocal();
  }

  try {
    final location = tz.getLocation(normalizedTimezoneId);
    return tz.TZDateTime.from(scheduledTime, location);
  } catch (_) {
    return scheduledTime.toLocal();
  }
}

String _audioPathForReminderCategory(String category) {
  final normalized = category.trim().toLowerCase();

  if (normalized.contains('water')) return waterSound;
  if (normalized.contains('meal')) return mealSound;
  if (normalized.contains('medicine')) return medicineSound;
  if (normalized.contains('event')) return eventSound;
  if (normalized.contains('sleep')) return sleepSound;

  return alarmSound;
}

enum ReminderMergePreference { keepLocal, preferIncoming }

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
  final _isSaving = false;
  final titleController = TextEditingController();
  final timeController = TextEditingController();
  final notesController = TextEditingController();
  Rx<TimeOfDay?> waterStartTime = Rx<TimeOfDay?>(TimeOfDay(hour: 8, minute: 0));
  Rx<TimeOfDay?> waterEndTime = Rx<TimeOfDay?>(TimeOfDay(hour: 22, minute: 0));
  Rxn<dynamic> editingId = Rxn<dynamic>();
  final xTimeUnitController = TextEditingController();
  var reminders = <reminder_payload.ReminderPayloadModel>[].obs;
  var alarms = <AlarmSettings>[].obs;
  Map<String, List<TimeOfDay>> pickedTimes = {};
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
  final ReminderAlarmTransaction _alarmTransaction = ReminderAlarmTransaction();
  final List<String> categories = ['medicine', 'water', 'meal', 'event'];
  final Set<int> _recentlyUpdatedIds = {};

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
    // ✅ NOTE: Permission requests have been moved to PermissionGateScreen
    // which is shown after login. Permissions are no longer requested here.
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
      debugPrint('Requesting notification permission...');
      final res = await Permission.notification.request();
      debugPrint(
        'Notification permission ${res.isGranted ? '' : 'not '}granted',
      );
    }
    if (status.isGranted) {
      debugPrint(
        "Enabled notifications permission ${enableNotifications.value}",
      );
      enableNotifications.value = true;
    }
  }

  Future<void> checkAndroidScheduleExactAlarmPermission() async {
    final status = await Permission.scheduleExactAlarm.status;
    if (kDebugMode) {
      debugPrint('Schedule exact alarm permission: $status.');
    }
    if (status.isDenied) {
      if (kDebugMode) {
        debugPrint('Requesting schedule exact alarm permission...');
      }
      final res = await Permission.scheduleExactAlarm.request();
      if (kDebugMode) {
        debugPrint(
          'Schedule exact alarm permission ${res.isGranted ? '' : 'not'} granted.',
        );
      }
    }
  }

  // ==================== Alarm Listener ====================

  reminder_payload.ReminderPayloadModel? findReminderByAlarmId(int alarmId) {
    for (final reminder in reminders) {
      if (reminder.scheduleMetadata.alarmIds.contains(alarmId) ||
          reminder.scheduleMetadata.preAlarmIds.contains(alarmId)) {
        return reminder;
      }
    }
    return null;
  }

  void initAlarmListener() {
    if (subscription != null) return;
    subscription = Alarm.ringStream.stream.listen((
      AlarmSettings alarmSettings,
    ) async {
      // PHASE A: Hook into Alarm Trigger
      final reminder = findReminderByAlarmId(alarmSettings.id);

      if (reminder != null) {
        final updated = reminder.copyWithScheduleMetadata(
          reminder.scheduleMetadata.copyWith(
            lastFiredAt: DateTime.now().toLocal().toIso8601String(),
          ),
        );
        await updateReminderLocalOnly(updated);

        // PHASE B: Self-Sustaining Reschedule Chain
        // After recording the fire, reschedule this reminder for its next
        // occurrence. This ensures recurring reminders (medicine daily,
        // water intervals, etc.) automatically schedule the next day's
        // alarms without needing the user to reopen the app.
        try {
          await scheduleReminderLocally(updated);
          debugPrint(
            '[ReminderTxn] ✅ Auto-rescheduled reminder ${updated.id} '
            'after alarm fire',
          );
        } catch (e) {
          debugPrint(
            '[ReminderTxn] ⚠️ Auto-reschedule failed for ${updated.id}: $e',
          );
        }
      }

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
      assetAudioPath: remindBeforeSound,
      loopAudio: false,
      allowAlarmOverlap: true,
      vibrate: soundVibrationToggle.value,
      warningNotificationOnKill: false,
      androidFullScreenIntent: false,
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
    // Native AlarmManager is the sole scheduler — skip Alarm.set().
    const success = true;

    if (success) {
      debugPrint('✅ [setBeforeReminderAlarm] Alarm armed via native layer');
      // 📲 Arm via native Kotlin layer
      await NativeAlarmBridge.armAlarm(
        alarmId: alarmSettings.id,
        epochMs: alarmSettings.dateTime.millisecondsSinceEpoch,
        groupId: alarmSettings.id.toString(),
        category: category,
        title: alarmSettings.notificationSettings.title,
        body: alarmSettings.notificationSettings.body,
      );
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
    int? reminderIdOverride,
  }) async {
    var scheduledTime = DateTime(
      startDate.value?.year ?? now.year,
      startDate.value?.month ?? now.month,
      startDate.value?.day ?? now.day,
      timeOfDay.hour,
      timeOfDay.minute,
    );
    debugPrint("   ↳ initial scheduledTime: $scheduledTime");

    if (scheduledTime.isBefore(now) || scheduledTime.isAtSameMomentAs(now)) {
      debugPrint("⚠️ [addAlarm] Time is in past or same as now");
      scheduledTime = scheduledTime.add(Duration(days: 1));
      debugPrint("   ↳ moved to next day: $scheduledTime");
    }

    debugPrint("Add Alarm category $category");

    switch (category) {
      // case "Medicine":
      //   await medicineGetxController.addMedicineAlarm(scheduledTime, context);
      //   break;
      case "meal":
        debugPrint("🍽️ [addAlarm] Meal flow → calling addMealAlarm()");

        await mealController.addMealAlarm(
          scheduledTime,
          context,
          reminderIdOverride: reminderIdOverride,
        );
        debugPrint("   ↳ Meal alarm created");
        break;
      case "event":
        await eventGetxController.addEventAlarm(
          scheduledTime,
          context,
          reminderIdOverride: reminderIdOverride,
        );
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
    num? dosage,
  }) async {
    debugPrint("🚀 updateReminderFromLocal called");
    debugPrint("➡️ id: $id (${id.runtimeType})");
    debugPrint("➡️ category: $category");
    debugPrint("➡️ timeOfDay: $timeOfDay");
    debugPrint("➡️ times: $times (${times.runtimeType})");

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

    debugPrint("🕒 initial scheduledTime → $scheduledTime");

    if (scheduledTime.isBefore(now) || scheduledTime.isAtSameMomentAs(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
      debugPrint("⏭️ time was past → moved to $scheduledTime");
    }

    if (normalizedCategory == 'water') {
      await waterController.updateWaterReminderFromLocal(context, id, times);
    } else {
      debugPrint("🔁 Updating single alarm → $category with id=$id");

      switch (normalizedCategory) {
        case 'medicine':
          await _updateMedicineReminderLocally(
            context: context,
            dosage: dosage,
            reminderId: int.parse(id),
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
          debugPrint("⚠️ Unknown category: $category");
      }
    }

    debugPrint("✅ updateReminderFromLocal completed");
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

  Future<ReminderScheduleMetadata> buildScheduleMetadata({
    required String category,
    ScheduleSemantics? semantics,
    ReminderScheduleMetadata? existing,
    bool migratedFromLegacy = false,
  }) async {
    final timezoneId = await DeviceTimezoneService.instance.getTimeZoneId();
    final fallbackSemantics =
        semantics ??
        existing?.scheduleSemantics ??
        reminder_payload.ReminderPayloadModel.defaultSemanticsForCategory(
          category,
        );
    final effectiveTimezoneId =
        fallbackSemantics == ScheduleSemantics.absolute
            ? ((existing?.timezoneId.trim().isNotEmpty ?? false)
                ? existing!.timezoneId
                : timezoneId)
            : timezoneId;
    return (existing ??
            ReminderScheduleMetadata.fallback(
              timezoneId: effectiveTimezoneId,
              semantics: fallbackSemantics,
            ))
        .copyWith(
          scheduleVersion: kCurrentReminderScheduleVersion,
          timezoneId: effectiveTimezoneId,
          scheduleSemantics: fallbackSemantics,
          clearNextFireAt: true,
          clearLastResolvedAt: true,
          alarmIds: const [],
          preAlarmIds: const [],
          lastResolutionStatus:
              migratedFromLegacy
                  ? ReminderResolutionStatus.migrated
                  : ReminderResolutionStatus.pending,
          migratedFromLegacy:
              migratedFromLegacy || (existing?.migratedFromLegacy ?? false),
        );
  }

  Future<void> syncReminderTransactionWithNative(
    ReminderAlarmTransactionResult transaction,
  ) async {
    final alarms = <AlarmSettings>[
      ...transaction.mainAlarms,
      ...transaction.preAlarms,
    ];
    if (alarms.isEmpty) return;

    await NativeAlarmBridge.saveAndArm(alarms);
  }

  Future<void> stopReminderAlarmIds(Iterable<int> alarmIds) async {
    final ids = alarmIds.where((id) => id > 0).toSet().toList(growable: false);
    if (ids.isEmpty) return;

    for (final id in ids) {
      try {
        await Alarm.stop(id);
      } catch (e) {
        debugPrint('⚠️ Failed to stop Flutter alarm id=$id: $e');
      }
    }

    await NativeAlarmBridge.cancelAlarms(ids);
  }

  Future<ReminderAlarmTransactionResult> scheduleReminderLocally(
    reminder_payload.ReminderPayloadModel reminder,
  ) async {
    _recentlyUpdatedIds.add(reminder.id);
    final updated = reminder.copyWith(updatedAt: DateTime.now());
    final transaction = await _alarmTransaction.schedule(updated);
    await syncReminderTransactionWithNative(transaction);
    return transaction;
  }

  Future<void> rollbackReminderSchedule(
    reminder_payload.ReminderPayloadModel reminder,
  ) async {
    final alarmIds = <int>{
      ...reminder.scheduleMetadata.alarmIds,
      ...reminder.scheduleMetadata.preAlarmIds,
      ...reminder.scheduleMetadata.pendingAlarmIds,
    };
    await _alarmTransaction.rollbackReminder(reminder);
    await NativeAlarmBridge.cancelAlarms(alarmIds.toList(growable: false));
  }

  Future<void> scheduleAlarmEveryXHours(int intervalHours) async {
    final nextTime = DateTime.now().add(Duration(hours: intervalHours));

    final newAlarm = AlarmSettings(
      id: alarmsId(),
      dateTime: nextTime,
      assetAudioPath: _audioPathForReminderCategory('water'),
      warningNotificationOnKill: false,
      androidFullScreenIntent: false,
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

    // Native AlarmManager is the sole scheduler — skip Alarm.set().
  }

  Future<void> stopAlarm(
    int index,
    AlarmSettings alarm,
    dynamic reminderList,
  ) async {
    await stopReminderAlarmIds([alarm.id]);
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
        await _deleteSingleAlarmReminder(
          reminder: reminder,
          keyName: "meals_list",
          targetList: mealController.mealsList,
        );
        break;

      case 'event':
        debugPrint('➡️ Deleting Event');
        await _deleteSingleAlarmReminder(
          reminder: reminder,
          keyName: "event_list",
          targetList: eventGetxController.eventList,
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
      case 'meal':
      case 'event':
      case 'water':
        groupIdsToAdd.add(reminder.id);
        alarmIdsToAdd.addAll(reminder.scheduleMetadata.alarmIds);
        alarmIdsToAdd.addAll(reminder.scheduleMetadata.preAlarmIds);
        break;
      default:
        // Unknown category: do nothing.
        return;
    }

    if (groupIdsToAdd.isEmpty && alarmIdsToAdd.isEmpty) return;

    final box = await HiveService().remindersBox();
    final existingGroupIds = await _readIntSet(
      box,
      _deletedReminderGroupIdsKey,
    );
    final existingAlarmIds = await _readIntSet(
      box,
      _deletedReminderAlarmIdsKey,
    );

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

  Future<void> _writeIntSet(Box box, String key, Set<int> values) async {
    if (values.isEmpty) {
      await box.delete(key);
      return;
    }
    await box.put(key, values.toList(growable: false));
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
    debugPrint('📦 loadReminderList() → key: $keyName');

    // final box = Hive.box('reminders_box');
    final box = await HiveService().remindersBox();
    final List<dynamic>? storedList = box.get(keyName);

    if (storedList == null) {
      debugPrint('⚠️ No data found for $keyName');
      return [];
    }

    debugPrint('📄 Raw list length [$keyName]: ${storedList.length}');

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

    debugPrint('✅ Loaded ${result.length} alarms for $keyName');
    return result;
  }

  Future<void> saveReminderList(RxList<dynamic> list, String keyName) async {
    debugPrint('💾 Saving reminders → key: $keyName');
    debugPrint('📦 Total items to save: ${list.length}');

    // final box = Hive.box('reminders_box');
    final box = await HiveService().remindersBox();

    List<String> stringList =
        list.map((item) {
          if (item is Map<String, AlarmSettings>) {
            debugPrint('🗂 Saving Map<String, AlarmSettings>');
            final jsonMap = item.map((key, value) {
              debugPrint('   ➜ Alarm: $key | id=${value.id}');
              return MapEntry(key, value.toJson());
            });
            return jsonEncode(jsonMap);
          } else if (item is medicine_payload.MedicineReminderModel) {
            debugPrint('💊 Saving MedicineReminderModel → ${item.title}');
            return jsonEncode(item.toJson());
          } else if (item is WaterReminderModel) {
            debugPrint(
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

          debugPrint('⚠️ Unknown item type: ${item.runtimeType}');
          return jsonEncode({});
        }).toList();

    await box.put(keyName, stringList);
    debugPrint('✅ Saved ${stringList.length} items to Hive → $keyName');
  }

  Future<void> loadAllReminderLists() async {
    try {
      debugPrint('🔄 loadAllReminderLists() START');
      isLoading(true);

      medicineGetxController.medicineList.value = await medicineGetxController
          .loadMedicineReminderList("medicine_list");
      debugPrint(
        '💊 Medicine loaded: ${medicineGetxController.medicineList.length}',
      );

      mealController.mealsList.value = await loadReminderList("meals_list");
      debugPrint('🍽 Meals loaded: ${mealController.mealsList.length}');

      eventGetxController.eventList.value = await loadReminderList(
        "event_list",
      );
      debugPrint('📅 Events loaded: ${eventGetxController.eventList.length}');

      waterController.waterList.value = await waterController
          .loadWaterReminderList("water_list");
      final dedupedWater = _dedupeWaterReminders(waterController.waterList);
      if (dedupedWater.length != waterController.waterList.length) {
        waterController.waterList.value = dedupedWater;
        await saveReminderList(waterController.waterList, "water_list");
      }
      debugPrint('💧 Water loaded: ${waterController.waterList.length}');

      final combined = _buildCombinedReminderPayloads(
        medicineItems: medicineGetxController.medicineList,
        mealItems: mealController.mealsList,
        eventItems: eventGetxController.eventList,
        waterItems: waterController.waterList,
      );
      final canonicalReminderMap = ReminderPayloadMapper.mergeByReminderId([
        for (var i = 0; i < combined.length; i++)
          ReminderPayloadMergeEntry(
            reminder: combined[i],
            updatedAt: combined[i].updatedAt,
            sourceOrder: i,
            sourcePriority: 2,
            sourceLabel: 'local',
          ),
      ], log: _logConversion);

      final sorted =
          canonicalReminderMap.values.toList()
            ..sort((a, b) => a.id.compareTo(b.id));
      reminders.assignAll(sorted);
      debugPrint('Combined reminders count: ${reminders.length}');
    } catch (e, stack) {
      debugPrint('❌ Error loading reminder lists: $e');
      debugPrint(stack.toString());
    } finally {
      isLoading(false);
      debugPrint('loadAllReminderLists() END');
    }
  }

  // ==================== API Methods ====================

  Future<void> getReminders(BuildContext context) async {
    try {
      isLoading(true);
      await getReminderFromAPI(context);
    } catch (e) {
      debugPrint("Error fetching reminders");
    } finally {
      isLoading(false);
    }
  }

  Future<List<reminder_payload.ReminderPayloadModel>> getReminderFromAPI(
    BuildContext context, {
    ReminderMergePreference mergePreference = ReminderMergePreference.keepLocal,
    bool rescheduleAfterSync = false,
  }) async {
    try {
      debugPrint('🚀 Starting getReminderFromAPI');

      final response = await ApiService.post(
        getreminderApi,
        null,
        withAuth: true,
        encryptionRequired: false,
      );

      debugPrint('📡 API response received: ${response.runtimeType}');

      if (response is http.Response && response.statusCode >= 400) {
        debugPrint('❌ API error status: ${response.statusCode}');
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Failed to fetch reminders: ${response.statusCode}',
        );
        return [];
      }

      final enc = jsonEncode(response);
      debugPrint('🔐 Encoded response length: ${enc.length}');

      final decodedBody = jsonDecode(enc);
      debugPrint('📦 Decoded response keys: ${decodedBody.keys}');

      final rawReminders = decodedBody['data']?['Reminders'];
      debugPrint('📋 Raw reminders type: ${rawReminders.runtimeType}');

      if (rawReminders == null) {
        debugPrint('⚠️ Reminders is null, loading local data');
        await loadAllReminderLists();
        return List<reminder_payload.ReminderPayloadModel>.from(reminders);
      }

      if (rawReminders is! List) {
        debugPrint(
          '⚠️ Unexpected Reminders format: ${rawReminders.runtimeType}',
        );
        await loadAllReminderLists();
        return List<reminder_payload.ReminderPayloadModel>.from(reminders);
      }

      final List remindersList = rawReminders;
      debugPrint('📊 Total reminders received: ${remindersList.length}');

      final timezoneId = await DeviceTimezoneService.instance.getTimeZoneId();
      debugPrint('🌍 Timezone ID: $timezoneId');

      final remoteEntries = <ReminderPayloadMergeEntry>[];

      for (var i = 0; i < remindersList.length; i++) {
        final raw = remindersList[i];

        if (raw is! Map<String, dynamic>) {
          debugPrint(
            '⚠️ Skipping invalid reminder at index $i: ${raw.runtimeType}',
          );
          _logConversion(
            'Skip remote reminder at index=$i: expected Map but got ${raw.runtimeType}.',
          );
          continue;
        }

        debugPrint('🔄 Processing reminder index: $i');

        final payload = ReminderApiMapper.fromApiJson(
          raw,
          timezoneIdFallback: timezoneId,
        );

        remoteEntries.add(
          ReminderPayloadMergeEntry(
            reminder: payload,
            updatedAt: ReminderPayloadMapper.tryParseUpdatedAt(raw),
            sourceOrder: i,
            sourcePriority: 1,
            sourceLabel: 'remote',
          ),
        );
      }

      debugPrint('✅ Total valid remote entries: ${remoteEntries.length}');

      final remoteReminderMap = ReminderPayloadMapper.mergeByReminderId(
        remoteEntries,
        log: _logConversion,
      );

      final remoteReminders = remoteReminderMap.values.toList(growable: false);
      debugPrint('🧩 After merge, unique reminders: ${remoteReminders.length}');

      final box = await HiveService().remindersBox();
      debugPrint('📦 Hive box opened');

      var deletedGroupIds = await _readIntSet(box, _deletedReminderGroupIdsKey);
      var deletedAlarmIds = await _readIntSet(box, _deletedReminderAlarmIdsKey);

      debugPrint('🗑️ Deleted group IDs: $deletedGroupIds');
      debugPrint('🗑️ Deleted alarm IDs: $deletedAlarmIds');

      final reconciledTombstones = await _reconcileDeletedReminderTombstones(
        box,
        remoteReminders,
        deletedGroupIds: deletedGroupIds,
        deletedAlarmIds: deletedAlarmIds,
      );

      deletedGroupIds = reconciledTombstones.groupIds;
      deletedAlarmIds = reconciledTombstones.alarmIds;

      debugPrint('🔄 Reconciled tombstones');
      debugPrint('🗑️ Updated group IDs: $deletedGroupIds');
      debugPrint('🗑️ Updated alarm IDs: $deletedAlarmIds');

      await _saveToCategoryWiseLists(
        remoteReminders,
        mergePreference: mergePreference,
        deletedGroupIds: deletedGroupIds,
        deletedAlarmIds: deletedAlarmIds,
      );

      debugPrint('💾 Saved reminders to local storage');

      await loadAllReminderLists();
      debugPrint('🔁 Reloaded reminder lists');

      logLong("getRemindersFromAPI", remoteReminders.toString());

      var hydratedReminders = _dedupeSchedulerInputById(
        List<reminder_payload.ReminderPayloadModel>.from(reminders),
      );

      debugPrint('🧼 Hydrated reminders count: ${hydratedReminders.length}');

      if (rescheduleAfterSync) {
        debugPrint('⏰ Rescheduling alarms');

        await Alarm.stopAll();
        debugPrint('🛑 Stopped all alarms');

        await ReminderScheduler().scheduleAll(
          hydratedReminders,
          deletedGroupIds: deletedGroupIds,
          deletedAlarmIds: deletedAlarmIds,
        );

        debugPrint('✅ Scheduled all reminders');

        await loadAlarms();
        await loadAllReminderLists();

        hydratedReminders = _dedupeSchedulerInputById(
          List<reminder_payload.ReminderPayloadModel>.from(reminders),
        );

        debugPrint(
          '🔁 Post-reschedule reminder count: ${hydratedReminders.length}',
        );
      }

      debugPrint('🎉 getReminderFromAPI completed successfully');

      return hydratedReminders;
    } catch (e, stack) {
      debugPrint('❌ getReminderFromAPI failed: $e');
      debugPrint('📍 Stack trace: $stack');

      await loadAllReminderLists();
      return List<reminder_payload.ReminderPayloadModel>.from(reminders);
    }
  }

  Future<List<reminder_payload.ReminderPayloadModel>> syncRemindersFromServer(
    BuildContext context,
  ) {
    return getReminderFromAPI(
      context,
      mergePreference: ReminderMergePreference.preferIncoming,
      rescheduleAfterSync: true,
    );
  }

  Future<void> clearAllReminderBoxes() async {
    final box = await HiveService().remindersBox();
    await box.delete("meals_list");
    await box.delete("event_list");
    await box.delete("medicine_list");
    await box.delete("water_list");

    debugPrint('All reminder boxes cleared');
  }

  Future<void> updateReminderLocalOnly(
    reminder_payload.ReminderPayloadModel reminder,
  ) async {
    final index = reminders.indexWhere(
      (e) => e.id.toString() == reminder.id.toString(),
    );
    if (index >= 0) {
      reminders[index] = reminder;
    } else {
      reminders.add(reminder);
    }
    await _saveToCategoryWiseLists(reminders);
  }

  Future<List<reminder_payload.ReminderPayloadModel>> _saveToCategoryWiseLists(
    List<reminder_payload.ReminderPayloadModel> reminders, {
    ReminderMergePreference mergePreference = ReminderMergePreference.keepLocal,
    Set<int> deletedGroupIds = const {},
    Set<int> deletedAlarmIds = const {},
  }) async {
    final existingMeals = await loadReminderList("meals_list");
    final existingEvents = await loadReminderList("event_list");
    final existingMedicine = await medicineGetxController
        .loadMedicineReminderList("medicine_list");
    final existingWater = await waterController.loadWaterReminderList(
      "water_list",
    );
    final localReminders = _buildCombinedReminderPayloads(
      medicineItems: existingMedicine,
      mealItems: existingMeals,
      eventItems: existingEvents,
      waterItems: existingWater,
    );
    final existingPriority =
        mergePreference == ReminderMergePreference.preferIncoming ? 1 : 3;
    final incomingPriority =
        mergePreference == ReminderMergePreference.preferIncoming ? 3 : 1;

    final mergedReminderMap = ReminderPayloadMapper.mergeByReminderId([
      for (var i = 0; i < localReminders.length; i++)
        ReminderPayloadMergeEntry(
          reminder: localReminders[i],
          updatedAt: localReminders[i].updatedAt,
          sourceOrder: i,
          sourcePriority:
              _recentlyUpdatedIds.contains(localReminders[i].id)
                  ? existingPriority + 1
                  : existingPriority,
          sourceLabel: 'local',
        ),
      for (var i = 0; i < reminders.length; i++)
        ReminderPayloadMergeEntry(
          reminder: reminders[i],
          sourceOrder: i,
          sourcePriority: incomingPriority,
          sourceLabel:
              mergePreference == ReminderMergePreference.preferIncoming
                  ? 'incoming'
                  : 'remote',
        ),
    ], log: _logConversion);

    final mergedReminders =
        mergedReminderMap.values.toList()..sort((a, b) => a.id.compareTo(b.id));

    final meals = <Map<String, AlarmSettings>>[];
    final events = <Map<String, AlarmSettings>>[];
    final medicine = <medicine_payload.MedicineReminderModel>[];
    final water = <WaterReminderModel>[];

    for (final reminder in mergedReminders) {
      final category = _normalizeCategory(reminder.category);
      try {
        switch (category) {
          case 'meal':
            if (deletedGroupIds.contains(reminder.id)) {
              _logConversion(
                'Skip deleted meal reminder (groupId=${reminder.id}).',
              );
              break;
            }
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
              final entry = _convertToMealMap(
                reminder,
                scheduledTime: times[i],
              );
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
            if (deletedGroupIds.contains(reminder.id)) {
              _logConversion(
                'Skip deleted event reminder (groupId=${reminder.id}).',
              );
              break;
            }
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
              final entry = _convertToEventMap(
                reminder,
                scheduledTime: times[i],
              );
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
    await saveReminderList(_dedupeWaterReminders(water).obs, "water_list");
    return mergedReminders;
  }

  Future<({Set<int> groupIds, Set<int> alarmIds})>
  _reconcileDeletedReminderTombstones(
    Box box,
    List<reminder_payload.ReminderPayloadModel> remoteReminders, {
    required Set<int> deletedGroupIds,
    required Set<int> deletedAlarmIds,
  }) async {
    final nextGroupIds = Set<int>.from(deletedGroupIds);
    final nextAlarmIds = Set<int>.from(deletedAlarmIds);
    var changed = false;

    for (final reminder in remoteReminders) {
      final category = _normalizeCategory(reminder.category);
      switch (category) {
        case 'medicine':
        case 'water':
          if (nextGroupIds.remove(reminder.id)) {
            changed = true;
            _logConversion(
              'Cleared stale deleted $category reminder tombstone '
              '(groupId=${reminder.id}).',
            );
          }
          break;

        case 'meal':
        case 'event':
          if (nextGroupIds.remove(reminder.id)) {
            changed = true;
            _logConversion(
              'Cleared stale deleted $category reminder tombstone '
              '(groupId=${reminder.id}).',
            );
          }
          if (nextAlarmIds.remove(reminder.id)) {
            changed = true;
            _logConversion(
              'Cleared stale deleted $category reminder tombstone '
              '(id=${reminder.id}).',
            );
          }

          final times = _parseScheduledTimes(
            reminder.customReminder.timesPerDay?.list,
            dateHint: reminder.startDate,
          );

          for (final scheduledTime in times) {
            final scheduledAlarmId = _alarmIdForReminder(
              reminderId: reminder.id,
              scheduleVersion: reminder.scheduleMetadata.scheduleVersion,
              fireTime: scheduledTime,
            );
            if (nextAlarmIds.remove(scheduledAlarmId)) {
              changed = true;
              _logConversion(
                'Cleared stale deleted $category occurrence tombstone '
                '(alarmId=$scheduledAlarmId, groupId=${reminder.id}).',
              );
            }
          }
          break;
      }
    }

    if (!changed) {
      return (groupIds: deletedGroupIds, alarmIds: deletedAlarmIds);
    }

    await _writeIntSet(box, _deletedReminderGroupIdsKey, nextGroupIds);
    await _writeIntSet(box, _deletedReminderAlarmIdsKey, nextAlarmIds);
    return (groupIds: nextGroupIds, alarmIds: nextAlarmIds);
  }

  String _alarmEntrySignature(
    String category,
    Map<String, AlarmSettings> entry,
  ) {
    final title = entry.keys.first.trim().toLowerCase();
    final alarm = entry.values.first;
    final body = alarm.notificationSettings.body.trim().toLowerCase();
    final when = alarm.dateTime.toLocal().toIso8601String();
    return '$category|$title|$body|$when';
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
      scheduleVersion: reminder.scheduleMetadata.scheduleVersion,
      scheduledTime: resolvedTime,
      notificationTitle: title,
      notificationBody: (reminder.notes ?? '').trim(),
      assetAudioPath: mealSound,
      payload: jsonEncode({
        'groupId': reminder.id.toString(),
        'category': 'meal',
        'type': 'times',
        'scheduleMetadata': reminder.scheduleMetadata.toJson(),
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
      'scheduleMetadata': reminder.scheduleMetadata.toJson(),
    });

    final alarm = _buildAlarmSettings(
      reminderGroupId: reminder.id,
      scheduleVersion: reminder.scheduleMetadata.scheduleVersion,
      scheduledTime: resolvedTime,
      notificationTitle: title,
      notificationBody: (reminder.notes ?? '').trim(),
      assetAudioPath: eventSound,
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
      alarmIds: reminder.scheduleMetadata.alarmIds,
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
      scheduleMetadata: reminder.scheduleMetadata,
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
        scheduleVersion: reminder.scheduleMetadata.scheduleVersion,
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
        waterReminderStartTime:
            intervalStart.isNotEmpty ? intervalStart : start,
        waterReminderEndTime: intervalEnd.isNotEmpty ? intervalEnd : end,
        interval: hours.toString(),
        notes: notes,
        scheduleMetadata: reminder.scheduleMetadata,
      );
    }

    final countRaw = payloadCustom.timesPerDay?.count?.toString() ?? '0';
    final timesPerDay = (int.tryParse(countRaw) ?? 0).clamp(0, 200);

    final alarms = _buildWaterAlarmsForTimes(
      reminderGroupId: reminder.id,
      scheduleVersion: reminder.scheduleMetadata.scheduleVersion,
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
      scheduleMetadata: reminder.scheduleMetadata,
    );
  }

  // ---------------------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------------------

  void _logConversion(String message, {StackTrace? stackTrace}) {
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

  List<WaterReminderModel> _dedupeWaterReminders(
    List<WaterReminderModel> items,
  ) {
    final deduped = <WaterReminderModel>[];
    for (final item in items) {
      final index = deduped.indexWhere(
        (existing) => _isEquivalentWaterReminder(existing, item),
      );
      if (index == -1) {
        deduped.add(item);
      } else {
        deduped[index] = _mergeWaterReminderForSync(deduped[index], item);
      }
    }
    return deduped;
  }

  WaterReminderModel _mergeWaterReminderForSync(
    WaterReminderModel existing,
    WaterReminderModel incoming,
  ) {
    final useIncomingInterval =
        (int.tryParse(incoming.interval ?? '') ?? 0) >
        (int.tryParse(existing.interval ?? '') ?? 0);
    final useIncomingTimes =
        (int.tryParse(incoming.timesPerDay) ?? 0) >
        (int.tryParse(existing.timesPerDay) ?? 0);

    return WaterReminderModel(
      id: incoming.id != 0 ? incoming.id : existing.id,
      title: incoming.title.trim().isNotEmpty ? incoming.title : existing.title,
      category:
          incoming.category.trim().isNotEmpty
              ? incoming.category
              : existing.category,
      type: incoming.type,
      alarms: incoming.alarms.isNotEmpty ? incoming.alarms : existing.alarms,
      timesPerDay:
          useIncomingTimes ? incoming.timesPerDay : existing.timesPerDay,
      waterReminderStartTime:
          incoming.waterReminderStartTime.trim().isNotEmpty
              ? incoming.waterReminderStartTime
              : existing.waterReminderStartTime,
      waterReminderEndTime:
          incoming.waterReminderEndTime.trim().isNotEmpty
              ? incoming.waterReminderEndTime
              : existing.waterReminderEndTime,
      interval:
          incoming.type == Option.interval
              ? (useIncomingInterval ? incoming.interval : existing.interval)
              : null,
      notes:
          (incoming.notes ?? '').trim().isNotEmpty
              ? incoming.notes
              : existing.notes,
      scheduleMetadata:
          incoming.scheduleMetadata.scheduleVersion >=
                  existing.scheduleMetadata.scheduleVersion
              ? incoming.scheduleMetadata
              : existing.scheduleMetadata,
    );
  }

  Map<String, dynamic> _decodeAlarmPayload(String? payload) {
    return ReminderIdentity.decodePayload(payload);
  }

  ReminderScheduleMetadata _scheduleMetadataFromPayload(
    Map<String, dynamic> payload, {
    required String category,
  }) {
    final rawMetadata = payload['scheduleMetadata'];
    return ReminderScheduleMetadata.fromJson(
      rawMetadata is Map ? Map<String, dynamic>.from(rawMetadata as Map) : null,
      timezoneIdFallback: 'Local',
      semanticsFallback: reminder_payload
          .ReminderPayloadModel.defaultSemanticsForCategory(
        category,
        isSingleInstance: true,
      ),
    );
  }

  bool _isEquivalentWaterReminder(
    WaterReminderModel first,
    WaterReminderModel second,
  ) {
    if (first.id == second.id) return true;
    if (first.type != second.type) return false;
    if (_normalizeWaterText(first.title) != _normalizeWaterText(second.title)) {
      return false;
    }
    if (!_waterFieldsCompatible(
      first.waterReminderStartTime,
      second.waterReminderStartTime,
    )) {
      return false;
    }
    if (!_waterFieldsCompatible(
      first.waterReminderEndTime,
      second.waterReminderEndTime,
    )) {
      return false;
    }
    if (!_waterFieldsCompatible(first.notes, second.notes)) {
      return false;
    }

    if (first.type == Option.interval) {
      final firstHours = int.tryParse(first.interval ?? '') ?? 0;
      final secondHours = int.tryParse(second.interval ?? '') ?? 0;
      return firstHours == 0 || secondHours == 0 || firstHours == secondHours;
    }

    final firstTimes = int.tryParse(first.timesPerDay) ?? 0;
    final secondTimes = int.tryParse(second.timesPerDay) ?? 0;
    return firstTimes == 0 || secondTimes == 0 || firstTimes == secondTimes;
  }

  bool _waterFieldsCompatible(String? first, String? second) {
    final left = _normalizeWaterText(first);
    final right = _normalizeWaterText(second);
    return left.isEmpty || right.isEmpty || left == right;
  }

  String _normalizeWaterText(String? value) =>
      (value ?? '').trim().toLowerCase();

  String _alarmWallClockTime(DateTime dateTime, {String? timezoneId}) {
    final zonedDateTime =
        timezoneId == null
            ? dateTime.toLocal()
            : reminderDateTimeInTimezone(dateTime, timezoneId: timezoneId);
    final hour = zonedDateTime.hour.toString().padLeft(2, '0');
    final minute = zonedDateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _alarmWallClockDate(DateTime dateTime, {String? timezoneId}) {
    final zonedDateTime =
        timezoneId == null
            ? dateTime.toLocal()
            : reminderDateTimeInTimezone(dateTime, timezoneId: timezoneId);
    final year = zonedDateTime.year.toString().padLeft(4, '0');
    final month = zonedDateTime.month.toString().padLeft(2, '0');
    final day = zonedDateTime.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  int _alarmIdForReminder({
    required int reminderId,
    required int scheduleVersion,
    required DateTime fireTime,
    bool isPreAlarm = false,
  }) {
    return computeAlarmId(
      reminderId: reminderId,
      scheduleVersion: scheduleVersion,
      fireTime: fireTime,
      isPreAlarm: isPreAlarm,
    );
  }

  AlarmSettings _buildAlarmSettings({
    required int reminderGroupId,
    required int scheduleVersion,
    required DateTime scheduledTime,
    required String notificationTitle,
    required String notificationBody,
    required String? payload,
    String assetAudioPath = alarmSound,
  }) {
    return AlarmSettings(
      id: _alarmIdForReminder(
        reminderId: reminderGroupId,
        scheduleVersion: scheduleVersion,
        fireTime: scheduledTime,
      ),
      dateTime: scheduledTime,
      assetAudioPath: assetAudioPath,
      warningNotificationOnKill: false,
      androidFullScreenIntent: false,
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
        final local = parsed.toLocal();
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
    final local = parsed.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  List<String> _normalizeIsoDateTimes(List<String>? rawTimes) {
    return normalizeReminderTimesForPersistence(rawTimes);
  }

  List<AlarmSettings> _buildWaterAlarmsForTimes({
    required int reminderGroupId,
    required int scheduleVersion,
    required String title,
    required String body,
    required int timesPerDay,
    required String startTime,
    required String endTime,
    required List<String>? explicitTimes,
  }) {
    final times =
        explicitTimes != null && explicitTimes.isNotEmpty
            ? _parseScheduledTimes(
              explicitTimes,
            ).map(_nextDailyOccurrence).toList()
            : _generateTimesBetween(
              startTime: startTime,
              endTime: endTime,
              times: timesPerDay,
            ).map(_nextDailyOccurrence).toList();

    return times
        .map(
          (t) => AlarmSettings(
            id: _alarmIdForReminder(
              reminderId: reminderGroupId,
              scheduleVersion: scheduleVersion,
              fireTime: t,
            ),
            dateTime: t,
            assetAudioPath: waterSound,
            loopAudio: false,
            warningNotificationOnKill: false,
            androidFullScreenIntent: false,
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
    required int scheduleVersion,
    required String title,
    required String body,
    required int intervalHours,
    required String startTime,
    required String endTime,
  }) {
    final start = _tryParseTimeOfDay(startTime);
    final end = _tryParseTimeOfDay(endTime);
    if (start == null || end == null || intervalHours <= 0) return const [];

    final times =
        _generateEveryXHours(
          start: start,
          end: end,
          intervalHours: intervalHours,
        ).map(_nextDailyOccurrence).toList();

    return times
        .map(
          (t) => AlarmSettings(
            id: _alarmIdForReminder(
              reminderId: reminderGroupId,
              scheduleVersion: scheduleVersion,
              fireTime: t,
            ),
            dateTime: t,
            assetAudioPath: waterSound,
            loopAudio: false,
            warningNotificationOnKill: false,
            androidFullScreenIntent: false,
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
    return List.generate(times, (i) => startDT.add(Duration(minutes: gap * i)));
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
    mealController.mealsList.value = await loadReminderList("meals_list");

    eventGetxController.eventList.value = await loadReminderList("event_list");

    medicineGetxController.medicineList.value = await medicineGetxController
        .loadMedicineReminderList("medicine_list");

    waterController.waterList.value = await waterController
        .loadWaterReminderList("water_list");
  }

  Future<void> addRemindertoAPI(
    reminder_payload.ReminderPayloadModel reminderData,
    BuildContext context,
  ) async {
    try {
      debugPrint("🚀 addRemindertoAPI called");

      Map<String, dynamic> payload = ReminderApiMapper.toApiJson(reminderData);
      if (payload['CustomReminder'] != null &&
          payload['CustomReminder'] is Map &&
          payload['CustomReminder']['TimesPerDay'] != null &&
          payload['CustomReminder']['TimesPerDay'] is Map) {
        var timesPerDay = payload['CustomReminder']['TimesPerDay'];

        if (timesPerDay['Count'] != null) {
          // Convert Count to String safely
          timesPerDay['Count'] = timesPerDay['Count'].toString();
        }
      }

      payload.removeWhere((key, value) => value == null);

      // Fix date format
      //       if (payload['CustomReminder']?['TimesPerDay']?['List'] != null) {
      //         List list = payload['CustomReminder']['TimesPerDay']['List'];
      //         payload['CustomReminder']['TimesPerDay']['List'] =
      //             list.map((e) => DateTime.parse(e).toIso8601String()).toList();
      //       }asdadasd

      debugPrint("📦 Modified Payload: $payload");
      debugPrint("🌐 Hitting API: $addreminderApi");

      final response = await ApiService.post(
        addreminderApi,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      if (kDebugMode) {
        debugPrint("📡 Raw Response: $response");
      }

      if (response is http.Response && response.statusCode >= 400) {
        throw ApiException(
          statusCode: response.statusCode,
          endpoint: addreminderApi,
          rawBody: response.body,
        );
      }

      if (!context.mounted) return;

      if (kDebugMode) {
        debugPrint("✅ Reminder saved successfully");
      }
    } on ApiException catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint("🔥 API Exception while saving Reminder record: $e");
        debugPrint("📍 StackTrace: $stackTrace");
      }
      _showApiError(context, e);
      rethrow;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint("🔥 Exception while saving Reminder record: $e");
        debugPrint("📍 StackTrace: $stackTrace");
      }
      final wrapped = ApiException(
        statusCode: 0,
        endpoint: addreminderApi,
        rawBody: e.toString(),
      );
      _showApiError(context, wrapped);
      throw wrapped;
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
      debugPrint("➡️ updateReminder called");
      debugPrint("📦 Payload: ${reminderData.toApiJson()}");

      Map<String, dynamic> payload = ReminderApiMapper.toApiJson(reminderData);
      if (payload['CustomReminder'] != null &&
          payload['CustomReminder'] is Map &&
          payload['CustomReminder']['TimesPerDay'] != null &&
          payload['CustomReminder']['TimesPerDay'] is Map) {
        var timesPerDay = payload['CustomReminder']['TimesPerDay'];

        if (timesPerDay['Count'] != null) {
          // Convert Count to String safely
          timesPerDay['Count'] = timesPerDay['Count'].toString();
        }
      }

      final response = await ApiService.post(
        editreminderApi,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      debugPrint("📡 API Response received");

      if (response is Map<String, dynamic>) {
        if (response['status'] == true) {
          debugPrint("✅ Reminder updated successfully");
          return;
        } else {
          throw ApiException(
            statusCode: 0,
            endpoint: editreminderApi,
            rawBody: response.toString(),
          );
        }
      } else if (response is http.Response) {
        if (response.statusCode >= 400) {
          throw ApiException(
            statusCode: response.statusCode,
            endpoint: editreminderApi,
            rawBody: response.body,
          );
        } else {
          debugPrint("✅ Reminder updated successfully");
          return;
        }
      }
    } catch (e, stackTrace) {
      debugPrint("💥 Exception while updating Reminder record: $e");
      debugPrint("🧵 StackTrace: $stackTrace");
      if (e is ApiException) rethrow;
      final wrapped = ApiException(
        statusCode: 0,
        endpoint: editreminderApi,
        rawBody: e.toString(),
      );
      _showApiError(context, wrapped);
      throw wrapped;
    }
  }

  Future<void> deleteReminderFromAPI(
    int reminderId,
    BuildContext context,
  ) async {
    try {
      debugPrint("🟡 [DELETE API] Called");
      debugPrint("🆔 Reminder ID: $reminderId");

      final payload = {"Id": reminderId};
      debugPrint("📦 Payload: $payload");

      final response = await ApiService.post(
        deletereminderApi,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      debugPrint("📡 API Response received");
      debugPrint("🔍 Response Type: ${response.runtimeType}");

      if (response is http.Response) {
        debugPrint("📊 Status Code: ${response.statusCode}");
        debugPrint("📄 Response Body: ${response.body}");
      }

      if (response is http.Response && response.statusCode >= 400) {
        debugPrint("❌ Delete failed with status: ${response.statusCode}");

        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Failed to delete Reminder record: ${response.statusCode}',
        );
      } else {
        debugPrint("✅ Delete successful");
      }
    } catch (e, stackTrace) {
      debugPrint("🔥 Exception while deleting Reminder record: $e");
      debugPrint("📍 StackTrace: $stackTrace");
    }
  }

  Future<bool> validateAndSave({
    required BuildContext context,
    num? dosage,
  }) async {
    final category = selectedCategory.value.trim().toLowerCase();
    if (selectedCategory.value != category) {
      selectedCategory.value = category;
    }

    debugPrint("🟢 validateAndSave() called");
    debugPrint("📂 Selected category: $category");
    debugPrint("✏️ Title: '${titleController.text}'");
    debugPrint("🧪 Dosage: $dosage");

    final isSelected =
        medicineGetxController.medicineRemindMeBeforeOption.value == 0;
    debugPrint("⏳ Medicine remind-before selected: $isSelected");
    if (isSelected) {
      final beforeValue = int.tryParse(
        medicineGetxController.medicineTimeBeforeController.text.trim(),
      );
      if (beforeValue == null || beforeValue <= 0) {
        Get.snackbar(
          "Almost there",
          "Reminder time should be greater than zero",
          snackPosition: SnackPosition.TOP,
          colorText: white,
          backgroundColor: AppColors.primaryColor,
          duration: const Duration(seconds: 2),
        );
        return false;
      }
    }

    final isSelectedEvent = eventGetxController.eventRemindMeBefore.value == 0;
    debugPrint("⏳ Event remind-before selected: $isSelectedEvent");
    if (isSelectedEvent) {
      final beforeValue = int.tryParse(
        eventGetxController.eventTimeBeforeController.text.trim(),
      );
      if (beforeValue == null || beforeValue <= 0) {
        Get.snackbar(
          "Almost there",
          "Reminder time should be greater than zero",
          snackPosition: SnackPosition.TOP,
          colorText: white,
          backgroundColor: AppColors.primaryColor,
          duration: const Duration(seconds: 2),
        );
        return false;
      }
    }
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

      if (category == 'event') {
        final selectedStartDate = startDateString.value.trim();
        if (selectedStartDate.isEmpty || selectedStartDate == 'Start Date') {
          Get.snackbar(
            "Almost there",
            "Pick a date for your event reminder",
            snackPosition: SnackPosition.TOP,
            colorText: white,
            backgroundColor: AppColors.primaryColor,
            duration: const Duration(seconds: 2),
          );
          return false;
        }
      }

      final resolvedTime =
          pickedTime.value ?? _resolveTimeForCategory(category);
      if ((category == 'meal' || category == 'event') && resolvedTime == null) {
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
        dosage: dosage,
      );
      return true;
    }

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
        if (category == 'event') {
          final selectedStartDate = startDateString.value.trim();
          if (selectedStartDate.isEmpty || selectedStartDate == 'Start Date') {
            Get.snackbar(
              "Almost there",
              "Pick a date for your event reminder",
              snackPosition: SnackPosition.TOP,
              colorText: white,
              backgroundColor: AppColors.primaryColor,
              duration: const Duration(seconds: 2),
            );
            return false;
          }
        }

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
    debugPrint("🧠 validateAndUpdate called");
    debugPrint("➡️ Raw category: ${selectedCategory.value}");

    final category = selectedCategory.value.trim().toLowerCase();

    if (selectedCategory.value != category) {
      debugPrint("🔄 Normalizing category → $category");
      selectedCategory.value = category;
    }

    debugPrint("➡️ Final category: $category");
    debugPrint("➡️ Title: '${titleController.text}'");

    if (titleController.text.trim().isEmpty) {
      debugPrint("❌ Title is empty");
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
      debugPrint("❌ Title too long: ${titleController.text.length}");
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

    debugPrint("➡️ Entering category switch");

    switch (category) {
      case "medicine":
        debugPrint("💊 Handling MEDICINE");

        debugPrint("➡️ Dosage: $dosage");

        if (dosage == null || dosage <= 0) {
          debugPrint("❌ Invalid dosage");
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

        debugPrint("➡️ isInterval: $isInterval");

        if (!isInterval) {
          final expectedTimes =
              medicineGetxController.getEffectiveTimesPerDay();
          final filledTimes =
              medicineGetxController.timeControllers
                  .where((ctrl) => ctrl.text.trim().isNotEmpty)
                  .length;

          debugPrint("➡️ Expected times: $expectedTimes");
          debugPrint("➡️ Filled times: $filledTimes");

          if (filledTimes < expectedTimes) {
            final missing = expectedTimes - filledTimes;

            debugPrint("❌ Missing times: $missing");

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
          final startText =
              medicineGetxController.startMedicineTimeController.text.trim();
          final endText =
              medicineGetxController.endMedicineTimeController.text.trim();

          debugPrint("➡️ Interval start: $startText");
          debugPrint("➡️ Interval end: $endText");

          if (startText.isEmpty || endText.isEmpty) {
            debugPrint("❌ Missing interval start/end time");
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

        debugPrint("✅ Medicine validation passed");
        return handleReminderUpdate(
          reminder: reminder,
          newCategory: category,
          dosage: dosage,
          context: context,
        );

      case "water":
        debugPrint("💧 Handling WATER");

        final isValid = waterController.validateWaterInput(context);
        debugPrint("➡️ Water input valid: $isValid");

        if (!isValid) {
          debugPrint("❌ Water validation failed");
          return false;
        }

        final timesPerDay = int.tryParse(
          waterController.timesPerDayController.text,
        );

        debugPrint("➡️ Times per day: $timesPerDay");

        debugPrint("➡️ Water times per day: $timesPerDay");
        return handleReminderUpdate(
          reminder: reminder,
          newCategory: category,
          dosage: dosage,
          context: context,
          resolvedTime: TimeOfDay(
            hour: 0,
            minute: 0,
          ), // Water usually handled differently
        );

      case "meal":
      case "event":
        debugPrint("🍽️/📅 Handling $category");

        if (category == 'event') {
          final selectedStartDate = startDateString.value.trim();
          if (selectedStartDate.isEmpty || selectedStartDate == 'Start Date') {
            debugPrint("❌ Event date not selected");
            Get.snackbar(
              "Almost there",
              "Pick a date for your event reminder",
              snackPosition: SnackPosition.TOP,
              colorText: white,
              backgroundColor: AppColors.primaryColor,
              duration: const Duration(seconds: 2),
            );
            return false;
          }
        }

        final resolvedTime =
            pickedTime.value ?? _resolveTimeForCategory(category);

        debugPrint("➡️ Picked time: ${pickedTime.value}");
        debugPrint("➡️ Resolved time: $resolvedTime");

        if (resolvedTime == null) {
          debugPrint("❌ No time selected");
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

        debugPrint("✅ $category validation passed");
        return handleReminderUpdate(
          reminder: reminder,
          newCategory: category,
          dosage: dosage,
          context: context,
          resolvedTime: resolvedTime,
        );

      default:
        debugPrint("❌ Unsupported category: $category");
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

  bool detectCategoryChange(String oldCategory, String newCategory) {
    final previous = _normalizeCategory(oldCategory);
    final next = _normalizeCategory(newCategory);

    debugPrint(
      "🔄 [ReminderUpdate] category transition: '$previous' -> '$next'",
    );

    return previous != next;
  }

  Future<bool> handleReminderUpdate({
    required reminder_payload.ReminderPayloadModel reminder,
    required String newCategory,
    num? dosage,
    required BuildContext context,
    TimeOfDay? resolvedTime,
  }) async {
    debugPrint("══════════════════════════════════════════");
    debugPrint("🧭 [ReminderUpdate] START");

    final previousCategory = _normalizeCategory(reminder.category);
    final nextCategory = _normalizeCategory(newCategory);
    final hasValidId = reminder.id > 0;

    debugPrint("📌 Reminder ID: ${reminder.id}");
    debugPrint("📂 Previous Category: $previousCategory");
    debugPrint("📂 New Category: $nextCategory");
    debugPrint("💊 Dosage: $dosage");
    debugPrint("⏰ Resolved Time: $resolvedTime");
    debugPrint("🆔 Has Valid ID: $hasValidId");

    // 🛑 Invalid ID fallback
    if (!hasValidId) {
      debugPrint("⚠️ Invalid reminder ID → Switching to CREATE flow");

      final created = await createNewReminder(
        newCategory: nextCategory,
        dosage: dosage,
        context: context,
        preferredReminderId: reminder.id,
        resolvedTime: resolvedTime,
      );

      debugPrint("🆕 Create fallback result: $created");
      debugPrint("══════════════════════════════════════════");

      return created;
    }

    // 🔄 Category Change Flow
    final isCategoryChanged = detectCategoryChange(
      previousCategory,
      nextCategory,
    );
    debugPrint("🔍 Category Changed: $isCategoryChanged");

    if (isCategoryChanged) {
      debugPrint("🛤️ Entering DELETE + CREATE flow");

      final backendDeleted = await _deleteReminderFromApiSilently(reminder.id);
      debugPrint("🌐 Backend delete result: $backendDeleted");

      final removed = await deleteOldReminder(reminder);
      debugPrint("🧹 Local delete result: $removed");

      final created = await createNewReminder(
        newCategory: nextCategory,
        dosage: dosage,
        context: context,
        preferredReminderId: reminder.id,
        resolvedTime: resolvedTime,
      );

      debugPrint("🆕 New reminder created: $created");

      if (!created) {
        debugPrint("❌ ERROR: Failed to create new reminder after deletion");

        Get.snackbar(
          "Update failed",
          "We couldn't move your reminder to the new category. Please try again.",
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }

      debugPrint("══════════════════════════════════════════");
      return created;
    }

    // ✏️ Same Category Update Flow
    debugPrint("✏️ Entering SAME CATEGORY UPDATE flow");

    final updated = await updateSameCategoryReminder(
      reminder: reminder,
      category: nextCategory,
      dosage: dosage,
      context: context,
    );

    debugPrint("🔄 Update result: $updated");

    if (!updated) {
      debugPrint("❌ ERROR: Failed to update reminder in same category");

      Get.snackbar(
        "Update failed",
        "The changes couldn't be saved. Please check your connection.",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }

    debugPrint("🏁 [ReminderUpdate] END");
    debugPrint("══════════════════════════════════════════");

    return updated;
  }

  Future<bool> deleteOldReminder(
    reminder_payload.ReminderPayloadModel reminder,
  ) async {
    final reminderId = reminder.id;
    final category = _normalizeCategory(reminder.category);

    debugPrint("🗑️ [ReminderUpdate] deleteOldReminder called");
    debugPrint("   ↳ reminderId: $reminderId");
    debugPrint("   ↳ list source used: ${_listKeyForCategory(category)}");

    if (reminderId <= 0) {
      debugPrint("⚠️ [ReminderUpdate] invalid id, skipping delete");
      return false;
    }

    final exists = await _reminderExistsInCategory(
      reminderId: reminderId,
      category: category,
    );
    if (!exists) {
      debugPrint(
        "⚠️ [ReminderUpdate] reminder not found in old list, nothing to delete",
      );
      await _cleanupBeforeReminderAlarms(
        category: category,
        reminder: reminder,
      );
      return false;
    }

    switch (category) {
      case 'medicine':
        debugPrint("🧹 [ReminderUpdate] alarm cleanup -> medicine");
        await medicineGetxController.deleteMedicineReminder(reminderId);
        break;
      case 'water':
        debugPrint("🧹 [ReminderUpdate] alarm cleanup -> water");
        await waterController.deleteWaterReminder(reminderId);
        break;
      case 'meal':
        debugPrint("🧹 [ReminderUpdate] alarm cleanup -> meals_list");
        await _deleteSingleAlarmReminder(
          reminder: reminder,
          keyName: "meals_list",
          targetList: mealController.mealsList,
        );
        break;
      case 'event':
        debugPrint("🧹 [ReminderUpdate] alarm cleanup -> event_list");
        await _deleteSingleAlarmReminder(
          reminder: reminder,
          keyName: "event_list",
          targetList: eventGetxController.eventList,
        );
        break;
      default:
        debugPrint("⚠️ [ReminderUpdate] unsupported old category: $category");
        return false;
    }

    await loadAllReminderLists();
    return true;
  }

  Future<bool> updateSameCategoryReminder({
    required reminder_payload.ReminderPayloadModel reminder,
    required String category,
    num? dosage,
    required BuildContext context,
  }) async {
    debugPrint("══════════════════════════════════════════");
    debugPrint("📝 [SameCategoryUpdate] START");

    final normalizedCategory = _normalizeCategory(category);
    final reminderId = reminder.id;

    debugPrint("📌 Reminder ID: $reminderId");
    debugPrint("📂 Raw Category: $category");
    debugPrint("📂 Normalized Category: $normalizedCategory");
    debugPrint("💊 Dosage: $dosage");
    debugPrint("📋 List Source: ${_listKeyForCategory(normalizedCategory)}");

    // 🔍 Existence Check
    debugPrint("🔍 Checking if reminder exists in current category list...");
    final exists = await _reminderExistsInCategory(
      reminderId: reminderId,
      category: normalizedCategory,
    );

    debugPrint("🔍 Exists in list: $exists");

    if (!exists) {
      debugPrint("⚠️ Reminder NOT FOUND → Switching to CREATE fallback");

      final created = await createNewReminder(
        newCategory: normalizedCategory,
        dosage: dosage,
        context: context,
        preferredReminderId: reminderId > 0 ? reminderId : null,
        resolvedTime: null,
      );

      debugPrint("🆕 Fallback Create Result: $created");
      debugPrint("══════════════════════════════════════════");
      return created;
    }

    // 🔀 Category Switch
    debugPrint("🔀 Routing to category handler → $normalizedCategory");

    switch (normalizedCategory) {
      // 💊 MEDICINE
      case 'medicine':
        debugPrint("💊 Handling MEDICINE update...");

        final updated = await _updateMedicineReminderLocally(
          context: context,
          dosage: dosage,
          reminderId: reminderId,
        );

        debugPrint("💊 Medicine update result: $updated");

        if (!updated) {
          debugPrint("⚠️ Medicine update FAILED → fallback CREATE");

          final created = await createNewReminder(
            newCategory: normalizedCategory,
            dosage: dosage,
            context: context,
            preferredReminderId: reminderId,
            resolvedTime: null,
          );

          debugPrint("🆕 Fallback Create Result: $created");
          debugPrint("══════════════════════════════════════════");
          return created;
        }

        debugPrint("✅ Medicine update SUCCESS");
        debugPrint("══════════════════════════════════════════");
        return true;

      // 💧 WATER
      case 'water':
        debugPrint("💧 Handling WATER update...");

        final rawInput = waterController.timesPerDayController.text.trim();
        debugPrint("💧 Raw timesPerDay input: '$rawInput'");

        final timesPerDay = int.tryParse(rawInput);
        debugPrint("💧 Parsed timesPerDay: $timesPerDay");

        if (timesPerDay == null) {
          debugPrint(
            "⚠️ Invalid timesPerDay input → may cause incorrect update",
          );
        }

        await waterController.updateWaterReminderFromLocal(
          context,
          reminderId.toString(),
          timesPerDay,
        );

        debugPrint("✅ Water update COMPLETED");
        debugPrint("══════════════════════════════════════════");
        return true;

      // 🍽️ MEAL / 📅 EVENT
      case 'meal':
      case 'event':
        debugPrint("🍽️/📅 Handling $normalizedCategory update...");

        final picked = pickedTime.value;
        final fallbackTime = _resolveTimeForCategory(normalizedCategory);

        debugPrint("⏰ Picked Time: $picked");
        debugPrint("⏰ Fallback Time: $fallbackTime");

        final resolvedTime = picked ?? fallbackTime;

        debugPrint("⏰ Final Resolved Time: $resolvedTime");

        if (resolvedTime == null) {
          debugPrint("❌ ERROR: No valid time available → aborting update");
          debugPrint("══════════════════════════════════════════");
          return false;
        }

        await updateReminderFromLocal(
          context,
          id: reminderId.toString(),
          category: normalizedCategory,
          timeOfDay: resolvedTime,
        );

        debugPrint("✅ $normalizedCategory update COMPLETED");
        debugPrint("══════════════════════════════════════════");
        return true;

      // ❌ DEFAULT
      default:
        debugPrint("❌ Unsupported category: $normalizedCategory");
        debugPrint("══════════════════════════════════════════");
        return false;
    }
  }

  Future<bool> createNewReminder({
    required String newCategory,
    num? dosage,
    required BuildContext context,
    int? preferredReminderId,
    TimeOfDay? resolvedTime,
  }) async {
    final category = _normalizeCategory(newCategory);
    final finalTime =
        resolvedTime ?? pickedTime.value ?? _resolveTimeForCategory(category);

    debugPrint("🆕 [ReminderUpdate] createNewReminder called");
    debugPrint("   ↳ rawCategory: $newCategory");
    debugPrint("   ↳ normalizedCategory: $category");
    debugPrint("   ↳ preferredReminderId: $preferredReminderId");
    debugPrint("   ↳ resolvedTime param: $resolvedTime");
    debugPrint("   ↳ pickedTime.value: ${pickedTime.value}");
    debugPrint("   ↳ finalTime used: $finalTime");
    debugPrint("   ↳ dosage: $dosage");

    switch (category) {
      case 'medicine':
        final isInterval =
            medicineGetxController.medicineReminderOption.value ==
            Option.interval;

        debugPrint("💊 [ReminderUpdate] Medicine flow");
        debugPrint("   ↳ isInterval: $isInterval");

        bool result;

        if (isInterval) {
          debugPrint("   ↳ Calling addMedicineIntervalAlarm()");
          result = await medicineGetxController.addMedicineIntervalAlarm(
            context: context,
            dosage: dosage,
            reminderIdOverride: preferredReminderId,
          );
        } else {
          debugPrint("   ↳ Calling addMedicineAlarm()");
          result = await medicineGetxController.addMedicineAlarm(
            context: context,
            dosage: dosage,
            reminderIdOverride: preferredReminderId,
          );
        }

        debugPrint("   ↳ Medicine result: $result");
        return result;

      case 'water':
        debugPrint("💧 [ReminderUpdate] Water flow");
        final result = await waterController.validateAndSaveWaterReminder(
          context,
          reminderIdOverride: preferredReminderId,
        );
        debugPrint("   ↳ Water result: $result");
        return result;

      case 'meal':
      case 'event':
        debugPrint("🍽️📅 [ReminderUpdate] $category flow");

        if (finalTime == null) {
          debugPrint("⚠️ [ReminderUpdate] Missing time for $category create");
          return false;
        }

        debugPrint("   ↳ Calling addAlarm()");
        debugPrint("   ↳ timeOfDay: $finalTime");

        await addAlarm(
          context,
          timeOfDay: finalTime,
          category: category,
          reminderIdOverride: preferredReminderId,
        );

        debugPrint("   ↳ $category alarm created successfully");
        return true;

      default:
        debugPrint(
          "⚠️ [ReminderUpdate] Unsupported create category: $category",
        );
        return false;
    }
  }

  Future<bool> _reminderExistsInCategory({
    required int reminderId,
    required String category,
  }) async {
    final normalizedCategory = _normalizeCategory(category);
    debugPrint(
      "🔎 [ReminderUpdate] checking list source: ${_listKeyForCategory(normalizedCategory)}",
    );

    switch (normalizedCategory) {
      case 'medicine':
        medicineGetxController.medicineList.value = await medicineGetxController
            .loadMedicineReminderList("medicine_list");
        return medicineGetxController.medicineList.any(
          (item) => item.id == reminderId,
        );
      case 'water':
        waterController.waterList.value = await waterController
            .loadWaterReminderList("water_list");
        return waterController.waterList.any((item) => item.id == reminderId);
      case 'meal':
        mealController.mealsList.value = await loadReminderList("meals_list");
        return mealController.mealsList.any((item) {
          return ReminderIdentity.matchesReminderId(
            item.values.first,
            reminderId,
          );
        });
      case 'event':
        eventGetxController.eventList.value = await loadReminderList(
          "event_list",
        );
        return eventGetxController.eventList.any((item) {
          return ReminderIdentity.matchesReminderId(
            item.values.first,
            reminderId,
          );
        });
      default:
        return false;
    }
  }

  Future<void> _deleteSingleAlarmReminder({
    required reminder_payload.ReminderPayloadModel reminder,
    required String keyName,
    required RxList<Map<String, AlarmSettings>> targetList,
  }) async {
    final loadedList = await loadReminderList(keyName);
    targetList.assignAll(loadedList);
    final candidateTimes = _candidateDateTimesForReminder(reminder);

    final indexesToDelete = <int>[];
    final alarmIdsToStop = <int>{
      ...reminder.scheduleMetadata.alarmIds,
      ...reminder.scheduleMetadata.preAlarmIds,
    };

    for (var index = 0; index < loadedList.length; index++) {
      final alarm = loadedList[index].values.first;
      if (_matchesSingleAlarmReminderEntry(
        alarm: alarm,
        reminder: reminder,
        candidateTimes: candidateTimes,
      )) {
        indexesToDelete.add(index);
        alarmIdsToStop.add(alarm.id);
      }
    }

    debugPrint(
      "🗂️ [ReminderUpdate] loaded $keyName count=${loadedList.length}",
    );

    if (indexesToDelete.isEmpty) {
      debugPrint(
        "⚠️ [ReminderUpdate] reminder ${reminder.id} not found in $keyName",
      );
      await _cleanupBeforeReminderAlarms(
        category: _normalizeCategory(reminder.category),
        reminder: reminder,
      );
      return;
    }

    for (final alarmId in alarmIdsToStop) {
      debugPrint("⏹️ [ReminderUpdate] stopping primary alarmId: $alarmId");
      await Alarm.stop(alarmId);
    }

    // ✅ KEY FIX: cancel native AlarmManager entries AND purge from SharedPrefs.
    // Alarm.stop() only touches the flutter_alarm package; without this the
    // Kotlin-side AlarmManager entry remains armed and the alarm still fires.
    if (alarmIdsToStop.isNotEmpty) {
      debugPrint(
        "🗑️ [ReminderUpdate] cancelling ${alarmIdsToStop.length} native alarms: $alarmIdsToStop",
      );
      await NativeAlarmBridge.cancelAlarms(
        alarmIdsToStop.toList(growable: false),
      );
    }

    await _cleanupBeforeReminderAlarms(
      category: _normalizeCategory(reminder.category),
      reminder: reminder,
    );

    final remaining = <Map<String, AlarmSettings>>[];
    for (var index = 0; index < loadedList.length; index++) {
      if (indexesToDelete.contains(index)) continue;
      remaining.add(loadedList[index]);
    }

    targetList.assignAll(remaining);
    await saveReminderList(targetList, keyName);
  }

  bool _matchesSingleAlarmReminderEntry({
    required AlarmSettings alarm,
    required reminder_payload.ReminderPayloadModel reminder,
    required List<DateTime> candidateTimes,
  }) {
    if (ReminderIdentity.matchesReminderId(alarm, reminder.id)) {
      return true;
    }

    if (reminder.scheduleMetadata.alarmIds.contains(alarm.id)) {
      return true;
    }

    final payload = ReminderIdentity.decodePayload(alarm.payload);
    if (payload['groupId']?.toString() == reminder.id.toString()) {
      return true;
    }

    if (candidateTimes.isEmpty) {
      return false;
    }

    final matchesTime = candidateTimes.any(
      (candidate) =>
          candidate.hour == alarm.dateTime.hour &&
          candidate.minute == alarm.dateTime.minute,
    );
    if (!matchesTime) {
      return false;
    }

    final reminderTitle = reminder.title.trim();
    final alarmTitle = alarm.notificationSettings.title.trim();
    if (reminderTitle.isNotEmpty && reminderTitle == alarmTitle) {
      return true;
    }

    final reminderNotes = (reminder.notes ?? '').trim();
    final alarmBody = alarm.notificationSettings.body.trim();
    if (reminderNotes.isNotEmpty && reminderNotes == alarmBody) {
      return true;
    }

    return reminderTitle.isEmpty && reminderNotes.isEmpty;
  }

  Future<void> _cleanupBeforeReminderAlarms({
    required String category,
    required reminder_payload.ReminderPayloadModel reminder,
  }) async {
    final candidateTimes = _candidateDateTimesForReminder(reminder);
    if (candidateTimes.isEmpty) {
      debugPrint(
        "ℹ️ [ReminderUpdate] no candidate times for before-alarm cleanup",
      );
      return;
    }

    final activeAlarms = await Alarm.getAlarms();
    for (final alarm in activeAlarms) {
      final payload = alarm.payload;
      if (payload == null || payload.isEmpty) continue;

      try {
        final decoded = jsonDecode(payload);
        if (decoded is! Map<String, dynamic>) continue;
        if (decoded['type']?.toString() != 'before') continue;
        if (_normalizeCategory(decoded['category']?.toString() ?? '') !=
            _normalizeCategory(category)) {
          continue;
        }

        final mainTime = DateTime.tryParse(
          decoded['mainTime']?.toString() ?? '',
        );
        if (mainTime == null) continue;

        final matchesMainTime = candidateTimes.any(
          (candidate) =>
              candidate.hour == mainTime.hour &&
              candidate.minute == mainTime.minute,
        );

        if (matchesMainTime) {
          debugPrint(
            "⏹️ [ReminderUpdate] stopping linked before-alarm: ${alarm.id}",
          );
          await Alarm.stop(alarm.id);
        }
      } catch (_) {}
    }
  }

  List<DateTime> _candidateDateTimesForReminder(
    reminder_payload.ReminderPayloadModel reminder,
  ) {
    final custom = reminder.customReminder;
    final results = <DateTime>[];

    final times = custom.timesPerDay?.list ?? const <String>[];
    for (final raw in times) {
      final parsed = DateTime.tryParse(raw.trim());
      if (parsed != null) {
        results.add(parsed.toLocal());
      }
    }

    final interval = custom.everyXHours;
    if (results.isEmpty && interval != null) {
      final start = interval.startTime.trim();
      final end = interval.endTime.trim();
      final hours = interval.hours;

      if (start.isNotEmpty && end.isNotEmpty && hours > 0) {
        try {
          final generated = _generateEveryXHours(
            start: stringToTimeOfDay(start),
            end: stringToTimeOfDay(end),
            intervalHours: hours,
          );
          results.addAll(generated);
        } catch (_) {}
      }
    }

    return results;
  }

  String _listKeyForCategory(String category) {
    switch (_normalizeCategory(category)) {
      case 'medicine':
        return 'medicine_list';
      case 'water':
        return 'water_list';
      case 'meal':
        return 'meals_list';
      case 'event':
        return 'event_list';
      default:
        return 'unknown_list';
    }
  }

  Future<bool> _deleteReminderFromApiSilently(int reminderId) async {
    if (reminderId <= 0) {
      debugPrint(
        "⚠️ [ReminderUpdate] skip backend delete for invalid id=$reminderId",
      );
      return false;
    }

    try {
      debugPrint(
        "🧼 [ReminderUpdate] attempting backend cleanup for stale reminder id=$reminderId",
      );
      final response = await ApiService.post(
        deletereminderApi,
        {"Id": reminderId},
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response && response.statusCode >= 400) {
        debugPrint(
          "⚠️ [ReminderUpdate] backend delete failed for id=$reminderId status=${response.statusCode}; stale category will be ignored client-side.",
        );
        return false;
      }

      debugPrint(
        "✅ [ReminderUpdate] backend delete succeeded for stale reminder id=$reminderId",
      );
      return true;
    } catch (e, stackTrace) {
      debugPrint(
        "⚠️ [ReminderUpdate] backend delete exception for id=$reminderId: $e",
      );
      debugPrint(stackTrace.toString());
      debugPrint(
        "⚠️ [ReminderUpdate] continuing with client-side stale reminder protection.",
      );
      return false;
    }
  }

  List<reminder_payload.ReminderPayloadModel> _dedupeSchedulerInputById(
    List<reminder_payload.ReminderPayloadModel> items,
  ) {
    final seenIds = <int>{};
    final deduped = <reminder_payload.ReminderPayloadModel>[];

    for (final item in items) {
      if (seenIds.add(item.id)) {
        deduped.add(item);
        continue;
      }

      debugPrint(
        "⏭️ [ReminderScheduler] skip duplicate reminder id=${item.id} category=${item.category}",
      );
    }

    return deduped;
  }

  List<reminder_payload.ReminderPayloadModel> _buildCombinedReminderPayloads({
    required List<medicine_payload.MedicineReminderModel> medicineItems,
    required List<Map<String, AlarmSettings>> mealItems,
    required List<Map<String, AlarmSettings>> eventItems,
    required List<WaterReminderModel> waterItems,
  }) {
    final combined = <reminder_payload.ReminderPayloadModel>[];

    for (final item in medicineItems) {
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
          scheduleMetadata: item.scheduleMetadata,
        ),
      );
    }

    for (final item in mealItems) {
      item.forEach((title, alarm) {
        final payloadData = _decodeAlarmPayload(alarm.payload);
        final scheduleMetadata = _scheduleMetadataFromPayload(
          payloadData,
          category: 'meal',
        ).copyWith(
          alarmIds: [alarm.id],
          lastResolutionStatus: ReminderResolutionStatus.scheduled,
        );
        final reminderId = ReminderIdentity.reminderIdFromPayload(
          payloadData,
          fallbackId: alarm.id,
        );
        final alarmTime = _alarmWallClockTime(
          alarm.dateTime,
          timezoneId: scheduleMetadata.timezoneId,
        );
        final alarmDate = _alarmWallClockDate(
          alarm.dateTime,
          timezoneId: scheduleMetadata.timezoneId,
        );
        combined.add(
          reminder_payload.ReminderPayloadModel(
            id: reminderId,
            category: "meal",
            title: title,
            notes: alarm.notificationSettings.body,
            customReminder: reminder_payload.CustomReminder(
              timesPerDay: reminder_payload.TimesPerDay(
                count: '1',
                list: [alarmTime],
              ),
            ),
            startDate: alarmDate,
            scheduleMetadata: scheduleMetadata,
          ),
        );
      });
    }

    for (final item in eventItems) {
      item.forEach((title, alarm) {
        reminder_payload.RemindBefore? remindBefore;
        String? startDate;
        final payloadData = _decodeAlarmPayload(alarm.payload);
        final scheduleMetadata = _scheduleMetadataFromPayload(
          payloadData,
          category: 'event',
        ).copyWith(
          alarmIds: [alarm.id],
          lastResolutionStatus: ReminderResolutionStatus.scheduled,
        );
        final reminderId = ReminderIdentity.reminderIdFromPayload(
          payloadData,
          fallbackId: alarm.id,
        );
        final alarmTime = _alarmWallClockTime(
          alarm.dateTime,
          timezoneId: scheduleMetadata.timezoneId,
        );

        if (alarm.payload != null) {
          try {
            final data = jsonDecode(alarm.payload!);
            if (data is Map<String, dynamic>) {
              final rawStartDate = data['startDate']?.toString().trim();
              if (rawStartDate != null && rawStartDate.isNotEmpty) {
                startDate = rawStartDate;
              }
              final remindData = data['remindBefore'];
              if (remindData is Map<String, dynamic>) {
                final rawTime = remindData['Time'] ?? remindData['time'];
                final rawUnit = remindData['Unit'] ?? remindData['unit'];
                final time =
                    rawTime is int
                        ? rawTime
                        : int.tryParse(rawTime.toString()) ?? 0;
                final unit = (rawUnit ?? 'minutes').toString();
                remindBefore = reminder_payload.RemindBefore(
                  time: time,
                  unit: unit,
                );
              }
            }
          } catch (_) {}
        }

        combined.add(
          reminder_payload.ReminderPayloadModel(
            id: reminderId,
            category: "event",
            title: title,
            customReminder: reminder_payload.CustomReminder(
              timesPerDay: reminder_payload.TimesPerDay(
                count: '1',
                list: [alarmTime],
              ),
            ),
            remindBefore: remindBefore,
            startDate:
                startDate ??
                _alarmWallClockDate(
                  alarm.dateTime,
                  timezoneId: scheduleMetadata.timezoneId,
                ),
            notes: alarm.notificationSettings.body,
            scheduleMetadata: scheduleMetadata,
          ),
        );
      });
    }

    for (final item in waterItems) {
      final isTimesBased = item.type == Option.times;
      final isIntervalBased = item.type == Option.interval;

      combined.add(
        reminder_payload.ReminderPayloadModel(
          id: item.id,
          category: "water",
          title: item.title,
          notes: item.notes,
          customReminder: reminder_payload.CustomReminder(
            type: item.type,
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
                      hours: int.tryParse(item.interval ?? '') ?? 0,
                      startTime: item.waterReminderStartTime,
                      endTime: item.waterReminderEndTime,
                    )
                    : null,
          ),
          startWaterTime: item.waterReminderStartTime,
          endWaterTime: item.waterReminderEndTime,
          scheduleMetadata: item.scheduleMetadata,
        ),
      );
    }

    return combined;
  }

  Future<bool> _updateMedicineReminderLocally({
    required BuildContext context,
    required num? dosage,
    required int reminderId,
  }) async {
    if (reminderId == 0) {
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
      (e) => e.id.toString() == reminderId.toString(),
    );
    if (index == -1) {
      return false;
    }

    final oldModel = medicineGetxController.medicineList[index];
    final title = titleController.text.trim();
    final notes = notesController.text.trim();
    final medicineType = medicineGetxController.selectedType.value;
    final unit = medicineGetxController.typeToDosage[medicineType] ?? 'DROP';
    final normalizedStartDate = canonicalLocalDate(
      medicineGetxController.startDateString.value == 'Start Date'
          ? (oldModel.startDate.isNotEmpty
              ? oldModel.startDate
              : DateTime.now().toIso8601String())
          : medicineGetxController.startDateString.value,
    );
    final normalizedEndDate =
        medicineGetxController.endDateString.value == 'End Date'
            ? oldModel.endDate
            : (canonicalLocalDate(medicineGetxController.endDateString.value) ??
                '');

    medicine_payload.CustomReminder customReminder;
    ScheduleSemantics semantics;

    if (isInterval) {
      final intervalHours = int.tryParse(
        medicineGetxController.everyHourController.text.trim(),
      );
      if (intervalHours == null || intervalHours <= 0) {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Please enter a valid hours interval',
        );
        return false;
      }

      customReminder = medicine_payload.CustomReminder(
        type: Option.interval,
        timesPerDay: null,
        everyXHours: medicine_payload.EveryXHours(
          hours: intervalHours.toString(),
          startTime: canonicalLocalTime(
            medicineGetxController.startMedicineTimeController.text.trim(),
          ),
          endTime: canonicalLocalTime(
            medicineGetxController.endMedicineTimeController.text.trim(),
          ),
        ),
      );
      semantics = oldModel.scheduleMetadata.scheduleSemantics;
    } else {
      final timeList =
          medicineGetxController.timeControllers
              .map((controller) => controller.text.trim())
              .where((value) => value.isNotEmpty)
              .map(canonicalLocalTime)
              .toList();
      if (timeList.isEmpty) {
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

      final count = medicineGetxController.getEffectiveTimesPerDay();
      customReminder = medicine_payload.CustomReminder(
        type: Option.times,
        timesPerDay: medicine_payload.TimesPerDay(
          count: count.toString(),
          list: timeList,
        ),
        everyXHours: null,
      );
      semantics =
          count <= 1 ? ScheduleSemantics.absolute : ScheduleSemantics.wallClock;
    }

    final updatedPayload = reminder_payload.ReminderPayloadModel(
      id: reminderId,
      title: title,
      category: 'medicine',
      medicineName: medicineName,
      medicineType: medicineType,
      dosage: reminder_payload.Dosage(value: dosage ?? 0, unit: unit),
      medicineFrequencyPerDay:
          medicineGetxController
              .frequencyNum[medicineGetxController.selectedFrequency.value]
              .toString(),
      reminderFrequencyType: medicineGetxController.selectedFrequency.value,
      customReminder: reminder_payload.CustomReminder(
        type: customReminder.type,
        timesPerDay:
            customReminder.timesPerDay == null
                ? null
                : reminder_payload.TimesPerDay(
                  count: customReminder.timesPerDay!.count,
                  list: customReminder.timesPerDay!.list,
                ),
        everyXHours:
            customReminder.everyXHours == null
                ? null
                : reminder_payload.EveryXHours(
                  hours: int.tryParse(customReminder.everyXHours!.hours) ?? 0,
                  startTime: customReminder.everyXHours!.startTime,
                  endTime: customReminder.everyXHours!.endTime,
                ),
      ),
      remindBefore:
          medicineGetxController.buildRemindBefore() == null
              ? null
              : reminder_payload.RemindBefore(
                time: medicineGetxController.buildRemindBefore()!.time,
                unit: medicineGetxController.buildRemindBefore()!.unit,
              ),
      startDate: normalizedStartDate ?? '',
      endDate: normalizedEndDate,
      notes: notes,
      whenToTake: medicineGetxController.selectedWhenToTake.value,
      scheduleMetadata: await buildScheduleMetadata(
        category: 'medicine',
        semantics: semantics,
        existing: oldModel.scheduleMetadata,
      ),
    );

    try {
      final transaction = await scheduleReminderLocally(updatedPayload);
      final updatedModel = medicine_payload.MedicineReminderModel(
        id: reminderId,
        alarmIds: transaction.reminder.scheduleMetadata.alarmIds,
        title: title,
        category: ReminderCategory.medicine.toString(),
        medicineName: medicineName,
        medicineType: medicineType,
        whenToTake: medicineGetxController.selectedWhenToTake.value,
        dosage: medicine_payload.Dosage(value: dosage ?? 0, unit: unit),
        medicineFrequencyPerDay:
            medicineGetxController
                .frequencyNum[medicineGetxController.selectedFrequency.value]
                .toString(),
        reminderFrequencyType: medicineGetxController.selectedFrequency.value,
        customReminder: customReminder,
        remindBefore: medicineGetxController.buildRemindBefore(),
        startDate: normalizedStartDate ?? '',
        endDate: normalizedEndDate,
        notes: notes,
        scheduleMetadata: transaction.reminder.scheduleMetadata,
      );

      medicineGetxController.medicineList[index] = updatedModel;
      await saveReminderList(
        medicineGetxController.medicineList,
        "medicine_list",
      );

      await loadAllReminderLists();
      CustomSnackbar().showReminderBar(context);
      Get.back(result: true);

      final obsoleteIds = <int>{
        ...oldModel.scheduleMetadata.alarmIds,
        ...oldModel.scheduleMetadata.preAlarmIds,
      }..removeAll({
        ...transaction.reminder.scheduleMetadata.alarmIds,
        ...transaction.reminder.scheduleMetadata.preAlarmIds,
      });
      await stopReminderAlarmIds(obsoleteIds);
      unawaited(
        updateReminder(transaction.reminder, context).catchError((e) {
          debugPrint('⚠️ Background medicine update API failed: $e');
        }),
      );

      return true;
    } catch (e) {
      debugPrint('❌ Failed to update medicine reminder: $e');
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Failed to update medicine reminder',
      );
      return false;
    }
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
    startDateString.value = "Start Date";
    endDate.value = null;
    endDateString.value = "End Date";
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
    if (_normalizeCategory(reminder.category) == 'medicine') {
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
