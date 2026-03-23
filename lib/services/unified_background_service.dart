import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/models/hive_models/sleep_log_g.dart';
import 'package:snevva/services/hive_service.dart';
import '../consts/consts.dart';
import '../models/hive_models/sleep_log.dart';
import '../models/hive_models/steps_model.dart';
import '../common/agent_debug_logger.dart';
import '../services/sleep/sleep_noticing_service.dart';

// Global references
// const MethodChannel _bgEventChannel = MethodChannel(
//   'com.coretegra.snevva/bg_events',
// );

const String _lastAutoStartedSleepWindowKey = 'last_auto_started_sleep_window';
const String _manualStoppedWindowKey = 'manually_stopped_window_key';

// Add this: Instance of the new Dart service
final SleepNoticingService _sleepNoticingService = SleepNoticingService();

@pragma("vm:entry-point")
Future<bool> unifiedBackgroundEntry(ServiceInstance service) async {
  try {
    DartPluginRegistrant.ensureInitialized();

    debugPrint('🧵 BG isolate started at ${DateTime.now()}');

    AgentDebugLogger.log(
      runId: 'auth-bg',
      hypothesisId: 'B',
      location: 'unified_background_service.dart:unifiedBackgroundEntry:start',
      message: 'Unified background entry started',
      data: const {},
    );

    // await setupHive();
    await HiveService().initBackground();

    // Initialize Hive
    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(SleepLogAdapter().typeId)) {
      Hive.registerAdapter(SleepLogAdapter());
    }
    if (!Hive.isAdapterRegistered(StepEntryAdapter().typeId)) {
      Hive.registerAdapter(StepEntryAdapter());
    }

    debugPrint('📦 Hive ready in BG isolate at ${DateTime.now()}');

    // Foreground service (Android)
    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();
      service.setForegroundNotificationInfo(
        title: "Health Tracking",
        content: "Monitoring steps & sleep...",
      );
    }

    print("🚀 Unified background service started at ${DateTime.now()}");

    final sleepBox = await HiveService().sleepLogBox();
    final stepBox = await HiveService().stepHistoryBox();

    // final stepBox = await Hive.openBox<StepEntry>('step_history');
    // final sleepBox = await Hive.openBox<SleepLog>('sleep_log');
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    await _ensureCurrentDayStepState(
      service: service,
      prefs: prefs,
      stepBox: stepBox,
      forceNotify: true,
    );

    await _restoreOrAutoStartSleepTracking(
      service: service,
      prefs: prefs,
      sleepBox: sleepBox,
    );

    // ═══════════════════════════════════════════════════════════════
    // 🌙 SLEEP TRACKING SETUP
    // ═══════════════════════════════════════════════════════════════

    service.on("start_sleep").listen((event) async {
      if (prefs.getBool("is_sleeping") ?? false) {
        print("⚠️ start_sleep ignored (already active)");
        return;
      }

      final now = DateTime.now();
      final goalMinutes =
          event?['goal_minutes'] as int? ??
          prefs.getInt("sleep_goal_minutes") ??
          480;

      final bedtimeMinutes = _coerceMinutesOfDay(
        event?['bedtime_minutes'] as int?,
        fallback: _coerceMinutesOfDay(
          prefs.getInt("user_bedtime_ms"),
          fallback: 23 * 60,
        ),
      );
      final waketimeMinutes = _coerceMinutesOfDay(
        event?['waketime_minutes'] as int?,
        fallback: _coerceMinutesOfDay(
          prefs.getInt("user_waketime_ms"),
          fallback: 7 * 60,
        ),
      );

      await prefs.setBool("is_sleeping", true);
      await prefs.setString("sleep_start_time", now.toIso8601String());
      await prefs.setInt("sleep_goal_minutes", goalMinutes);
      await prefs.setInt("user_bedtime_ms", bedtimeMinutes);
      await prefs.setInt("user_waketime_ms", waketimeMinutes);

      // Calculate sleep window
      final sleepWindow = _computeActiveSleepWindow(
        bedtimeMinutes,
        waketimeMinutes,
        now,
      );

      if (sleepWindow != null) {
        await prefs.setString(
          "current_sleep_window_start",
          sleepWindow.start.toIso8601String(),
        );
        await prefs.setString(
          "current_sleep_window_end",
          sleepWindow.end.toIso8601String(),
        );
        await prefs.setString("current_sleep_window_key", sleepWindow.dateKey);
      }

      await _sleepNoticingService.initializeForSleepWindow();

      // Updated: Start the Dart SleepNoticingService instead of MethodChannel
      _sleepNoticingService.startMonitoring();
      print("✅ SleepNoticingService (Dart) started at ${DateTime.now()}");

      // Send initial update
      service.invoke("sleep_update", {
        "elapsed_minutes": 0,
        "goal_minutes": goalMinutes,
        "is_sleeping": true,
      });

      print("🌙 Sleep tracking started at ${DateTime.now()}");
      print("   Goal: $goalMinutes mins");
      print("   Window: ${sleepWindow?.start} → ${sleepWindow?.end}");

      // Update notification
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "Sleep Tracking Active 😴",
          content:
              "0 min / ${_formatDuration(goalMinutes)} - Auto-tracking screen off time",
        );
      }

      // Start interval aggregation timer
    });

    service.on("stop_sleep").listen((event) async {
      // Updated: Stop the Dart SleepNoticingService
      _sleepNoticingService.stopMonitoring();
      print("✅ SleepNoticingService (Dart) stopped at ${DateTime.now()}");

      await _stopSleepAndSave(service, prefs, sleepBox);
    });

    // ═══════════════════════════════════════════════════════════════
    // ⏱️ SLEEP PROGRESS TIMER (updates every minute)
    // ═══════════════════════════════════════════════════════════════
    // ═══════════════════════════════════════════════════════════════
    // 👣 STEP COUNTING SETUP
    // ═══════════════════════════════════════════════════════════════
    print("👣 Initializing step counter at ${DateTime.now()}...");

    service.on('onStepDetected').listen((event) async {
      if (event == null) return;
      
      final int newTotalSteps = event['steps'] as int;

      await prefs.reload();
      final savedSteps = prefs.getInt("today_steps") ?? 0;

      if (newTotalSteps > savedSteps) {
        // Write to the key Dart controller polls every second
        await prefs.setInt("today_steps", newTotalSteps);

        // Persist to Hive
        final now = DateTime.now();
        final todayKey = "${now.year}-${now.month}-${now.day}";
        final currentHive = stepBox.get(todayKey)?.steps ?? 0;
        if (newTotalSteps > currentHive) {
          await stepBox.put(todayKey, StepEntry(date: DateTime(now.year, now.month, now.day), steps: newTotalSteps));
        }

        // Fire event so StepCounterController._listenToBackgroundSteps() reacts immediately
        service.invoke("steps_updated", {"steps": newTotalSteps});

        // Update notification only when not sleeping
        if (service is AndroidServiceInstance) {
          final isSleeping = prefs.getBool("is_sleeping") ?? false;
          if (!isSleeping) {
            service.setForegroundNotificationInfo(
              title: "Snevva Active",
              content: "Steps today: $newTotalSteps",
            );
          }
        }
      }
    });

    service.on('onAlarmWakeup').listen((_) async {
      // Run watchdog / sleep progress logic passively here on occasional wakeups
      await _ensureCurrentDayStepState(
        service: service,
        prefs: prefs,
        stepBox: stepBox,
      );

      await _restoreOrAutoStartSleepTracking(
        service: service,
        prefs: prefs,
        sleepBox: sleepBox,
      );

      final isSleeping = prefs.getBool("is_sleeping") ?? false;
      if (isSleeping) {
        final goalMinutes = prefs.getInt("sleep_goal_minutes") ?? 480;
        final totalSleepMinutes =
            await _sleepNoticingService.getTotalSleepMinutes();
        final windowKey = prefs.getString("current_sleep_window_key");
        final startTime = prefs.getString("sleep_start_time");

        service.invoke("sleep_update", {
          "elapsed_minutes": totalSleepMinutes,
          "goal_minutes": goalMinutes,
          "is_sleeping": true,
          "current_sleep_window_key": windowKey,
          "start_time": startTime,
        });

        if (service is AndroidServiceInstance) {
          final progress =
              ((totalSleepMinutes / goalMinutes) * 100).clamp(0, 100).toInt();
          service.setForegroundNotificationInfo(
            title: "Sleep Tracking 😴 ($progress%)",
            content:
                "${_formatDuration(totalSleepMinutes)} / ${_formatDuration(goalMinutes)} - Auto-tracking",
          );
        }

        final windowEndStr = prefs.getString("current_sleep_window_end");
        if (windowEndStr != null) {
          final windowEnd = DateTime.parse(windowEndStr);
          if (DateTime.now().isAfter(windowEnd)) {
            await _stopSleepAndSave(service, prefs, sleepBox);
          }
        }
      }
    });

    // ═══════════════════════════════════════════════════════════════
    // 🛑 SERVICE STOP LISTENER
    // ═══════════════════════════════════════════════════════════════
    service.on('stopService').listen((_) {
      print("🛑 Stopping unified background service at ${DateTime.now()}...");

      // Updated: Stop the Dart service
      _sleepNoticingService.stopMonitoring();

      AgentDebugLogger.log(
        runId: 'auth-bg',
        hypothesisId: 'C',
        location: 'unified_background_service.dart:stopService:listener',
        message: 'Received stopService in background isolate',
        data: const {},
      );

      service.stopSelf();
    });

    print(
      "✅ Unified background service fully initialized at ${DateTime.now()}",
    );

    return true;
  } catch (e) {
    print("❌ Unified background service failed: $e at ${DateTime.now()}");
    return false;
  }
}

Future<void> _restoreOrAutoStartSleepTracking({
  required ServiceInstance service,
  required SharedPreferences prefs,
  required Box<SleepLog> sleepBox,
}) async {
  await prefs.reload();

  final bedtimeMinutes = prefs.getInt("user_bedtime_ms");
  final waketimeMinutes = prefs.getInt("user_waketime_ms");
  final nowTime = DateTime.now();
  final sleepWindow = _resolveSleepWindow(
    prefs: prefs,
    bedtimeMinutes: bedtimeMinutes,
    waketimeMinutes: waketimeMinutes,
    nowTime: nowTime,
  );

  final isSleeping = prefs.getBool("is_sleeping") ?? false;

  if (isSleeping) {
    if (sleepWindow != null && nowTime.isAfter(sleepWindow.end)) {
      print("⏰ Service recovery detected window end. Auto-saving sleep...");
      await _stopSleepAndSave(service, prefs, sleepBox);
      return;
    }

    await _sleepNoticingService.initializeForSleepWindow();
    _sleepNoticingService.startMonitoring();

    final goalMinutes = prefs.getInt("sleep_goal_minutes") ?? 480;
    final totalSleepMinutes =
        await _sleepNoticingService.getTotalSleepMinutes();

    service.invoke("sleep_update", {
      "elapsed_minutes": totalSleepMinutes,
      "goal_minutes": goalMinutes,
      "is_sleeping": true,
      "current_sleep_window_key":
          sleepWindow?.dateKey ?? prefs.getString("current_sleep_window_key"),
      "start_time": prefs.getString("sleep_start_time"),
    });

    if (service is AndroidServiceInstance) {
      final progress =
          ((totalSleepMinutes / goalMinutes) * 100).clamp(0, 100).toInt();
      service.setForegroundNotificationInfo(
        title: "Sleep Tracking 😴 ($progress%)",
        content:
            "${_formatDuration(totalSleepMinutes)} / ${_formatDuration(goalMinutes)} - Auto-tracking",
      );
    }
    return;
  }

  if (sleepWindow == null) {
    return;
  }

  final blockedByManualStop = await _isManualStopBlockingThisWindow(
    prefs: prefs,
    currentWindow: sleepWindow,
  );

  if (blockedByManualStop) return;

  if (!_isWithinWindow(nowTime, sleepWindow.start, sleepWindow.end)) {
    return;
  }

  final lastAutoStarted = prefs.getString(_lastAutoStartedSleepWindowKey);
  if (lastAutoStarted == sleepWindow.dateKey) {
    return;
  }

  final normalizedBedtime = _coerceMinutesOfDay(
    bedtimeMinutes,
    fallback: sleepWindow.start.hour * 60 + sleepWindow.start.minute,
  );
  final normalizedWaketime = _coerceMinutesOfDay(
    waketimeMinutes,
    fallback: sleepWindow.end.hour * 60 + sleepWindow.end.minute,
  );

  final goalMinutes = _calculateSleepGoalMinutes(
    bedtimeMinutes: normalizedBedtime,
    waketimeMinutes: normalizedWaketime,
  );

  await _startSleepTrackingSession(
    service: service,
    prefs: prefs,
    goalMinutes: goalMinutes,
    bedtimeMinutes: normalizedBedtime,
    waketimeMinutes: normalizedWaketime,
    markAsAutoStarted: true,
  );
}

Future<bool> _isManualStopBlockingThisWindow({
  required SharedPreferences prefs,
  required _SleepWindow currentWindow,
}) async {
  final manuallyStopped = prefs.getBool('manually_stopped') ?? false;
  if (!manuallyStopped) {
    return false;
  }

  final manuallyStoppedForWindow = prefs.getString(_manualStoppedWindowKey);

  // Legacy installs used a global bool; scope it to only the active window.
  if (manuallyStoppedForWindow == null) {
    await prefs.setString(_manualStoppedWindowKey, currentWindow.dateKey);
    return true;
  }

  if (manuallyStoppedForWindow == currentWindow.dateKey) {
    return true;
  }

  await prefs.setBool('manually_stopped', false);
  await prefs.remove(_manualStoppedWindowKey);
  return false;
}

Future<void> _startSleepTrackingSession({
  required ServiceInstance service,
  required SharedPreferences prefs,
  required int goalMinutes,
  required int bedtimeMinutes,
  required int waketimeMinutes,
  required bool markAsAutoStarted,
}) async {
  final nowTime = DateTime.now();
  final sleepWindow = _computeActiveSleepWindow(
    bedtimeMinutes,
    waketimeMinutes,
    nowTime,
  );

  await prefs.setBool("is_sleeping", true);
  await prefs.setString("sleep_start_time", nowTime.toIso8601String());
  await prefs.setInt("sleep_goal_minutes", goalMinutes);
  await prefs.setInt("user_bedtime_ms", bedtimeMinutes);
  await prefs.setInt("user_waketime_ms", waketimeMinutes);

  if (sleepWindow != null) {
    await prefs.setString(
      "current_sleep_window_start",
      sleepWindow.start.toIso8601String(),
    );
    await prefs.setString(
      "current_sleep_window_end",
      sleepWindow.end.toIso8601String(),
    );
    await prefs.setString("current_sleep_window_key", sleepWindow.dateKey);
  }

  if (markAsAutoStarted && sleepWindow != null) {
    await prefs.setString(_lastAutoStartedSleepWindowKey, sleepWindow.dateKey);
  }

  await _sleepNoticingService.initializeForSleepWindow();
  _sleepNoticingService.startMonitoring();

  final totalSleepMinutes = await _sleepNoticingService.getTotalSleepMinutes();
  final startTime =
      prefs.getString("sleep_start_time") ?? nowTime.toIso8601String();

  service.invoke("sleep_update", {
    "elapsed_minutes": totalSleepMinutes,
    "goal_minutes": goalMinutes,
    "is_sleeping": true,
    "current_sleep_window_key": sleepWindow?.dateKey,
    "start_time": startTime,
  });

  print("🌙 Sleep tracking started at ${DateTime.now()}");
  print("   Goal: $goalMinutes mins");
  print("   Window: ${sleepWindow?.start} → ${sleepWindow?.end}");

  if (service is AndroidServiceInstance) {
    final progress =
        ((totalSleepMinutes / goalMinutes) * 100).clamp(0, 100).toInt();
    service.setForegroundNotificationInfo(
      title: "Sleep Tracking 😴 ($progress%)",
      content:
          "${_formatDuration(totalSleepMinutes)} / ${_formatDuration(goalMinutes)} - Auto-tracking",
    );
  }

}

_SleepWindow? _resolveSleepWindow({
  required SharedPreferences prefs,
  required int? bedtimeMinutes,
  required int? waketimeMinutes,
  required DateTime nowTime,
}) {
  final existingStart = prefs.getString("current_sleep_window_start");
  final existingEnd = prefs.getString("current_sleep_window_end");
  final existingKey = prefs.getString("current_sleep_window_key");

  if (existingStart != null && existingEnd != null && existingKey != null) {
    try {
      final start = DateTime.parse(existingStart);
      final end = DateTime.parse(existingEnd);
      final isFreshEnough = end.add(const Duration(hours: 6)).isAfter(nowTime);
      if (isFreshEnough) {
        return _SleepWindow(start: start, end: end, dateKey: existingKey);
      }
    } catch (_) {}
  }

  if (!_isValidMinutesOfDay(bedtimeMinutes) ||
      !_isValidMinutesOfDay(waketimeMinutes)) {
    return null;
  }

  return _computeActiveSleepWindow(bedtimeMinutes!, waketimeMinutes!, nowTime);
}

int _calculateSleepGoalMinutes({
  required int bedtimeMinutes,
  required int waketimeMinutes,
}) {
  if (!_isValidMinutesOfDay(bedtimeMinutes) ||
      !_isValidMinutesOfDay(waketimeMinutes)) {
    return 480;
  }

  var wake = waketimeMinutes;
  if (wake <= bedtimeMinutes) {
    wake += 24 * 60;
  }
  final diff = wake - bedtimeMinutes;
  return diff <= 0 ? 480 : diff;
}

bool _isWithinWindow(DateTime nowTime, DateTime start, DateTime end) {
  return (!nowTime.isBefore(start)) && nowTime.isBefore(end);
}

Future<void> _ensureCurrentDayStepState({
  required ServiceInstance service,
  required SharedPreferences prefs,
  required Box<StepEntry> stepBox,
  bool forceNotify = false,
}) async {
  final nowTime = DateTime.now();
  final todayKey = "${nowTime.year}-${nowTime.month}-${nowTime.day}";
  final lastDate = prefs.getString("last_step_date");

  if (lastDate == todayKey && !forceNotify) return;

  await prefs.setString("last_step_date", todayKey);
  // 🔥 FIX: DO NOT remove 'lastRawSteps'. We must keep the hardware tally so the pedometer stream
  // diff correctly evaluates the steps carried over precisely at midnight!
  // await prefs.remove('lastRawSteps');

  final existingToday = stepBox.get(todayKey);
  if (existingToday == null) {
    await stepBox.put(todayKey, StepEntry(date: nowTime, steps: 0));
  }

  final todaySteps = stepBox.get(todayKey)?.steps ?? 0;
  await prefs.setInt('today_steps', todaySteps);
  service.invoke("steps_updated", {"steps": todaySteps});

  if (service is AndroidServiceInstance &&
      !(prefs.getBool("is_sleeping") ?? false)) {
    service.setForegroundNotificationInfo(
      title: "Health Tracking",
      content: "$todaySteps steps tracked",
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 📊 SLEEP INTERVAL AGGREGATION
// ═══════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════
// 💾 STOP SLEEP AND SAVE
// ═══════════════════════════════════════════════════════════════

Future<void> _stopSleepAndSave(
  ServiceInstance service,
  SharedPreferences prefs,
  Box<SleepLog> sleepBox,
) async {
  final now = DateTime.now();
  final startString = prefs.getString("sleep_start_time");

  if (startString == null) {
    print("⚠️ No sleep start time found");
    await prefs.setBool("is_sleeping", false);
    await prefs.remove("current_sleep_window_start");
    await prefs.remove("current_sleep_window_end");
    await prefs.remove("current_sleep_window_key");
    return;
  }

  final start = DateTime.parse(startString);
  final goalMinutes = prefs.getInt("sleep_goal_minutes") ?? 480;
  final windowKey = prefs.getString("current_sleep_window_key");
  final windowStartString = prefs.getString("current_sleep_window_start");
  final windowEndString = prefs.getString("current_sleep_window_end");

  DateTime effectiveStart = start;
  DateTime effectiveEnd = now;

  if (windowStartString != null) {
    try {
      final windowStart = DateTime.parse(windowStartString);
      if (effectiveStart.isBefore(windowStart)) {
        effectiveStart = windowStart;
      }
    } catch (_) {}
  }

  if (windowEndString != null) {
    try {
      final windowEnd = DateTime.parse(windowEndString);
      if (effectiveEnd.isAfter(windowEnd)) {
        effectiveEnd = windowEnd;
      }
    } catch (_) {}
  }

  if (!effectiveEnd.isAfter(effectiveStart)) {
    effectiveEnd = effectiveStart;
  }

  // Get total sleep time from aggregated intervals
  // Get total sleep time from aggregated intervals (use service implementation)
  final totalSleepMinutes = await _sleepNoticingService.getTotalSleepMinutes();

  print("💾 Saving sleep data:");
  print("   Start: $effectiveStart");
  print("   End: $effectiveEnd");
  print("   Total sleep: $totalSleepMinutes mins");
  print("   Goal: $goalMinutes mins");

  // Save to Hive
  if (windowKey != null) {
    final logDate = DateTime.tryParse(windowKey) ?? effectiveStart;
    await sleepBox.put(
      windowKey,
      SleepLog(
        date: DateTime(logDate.year, logDate.month, logDate.day),
        // Use the sleep window date
        durationMinutes: totalSleepMinutes,
        startTime: effectiveStart,
        endTime: effectiveEnd,
        goalMinutes: goalMinutes,
      ),
    );
  }

  // Clear sleep state
  await prefs.setBool("is_sleeping", false);
  await prefs.remove("sleep_start_time");
  await prefs.remove("sleep_goal_minutes");
  await prefs.remove("current_sleep_window_start");
  await prefs.remove("current_sleep_window_end");
  await prefs.remove("current_sleep_window_key");

  // Clear sleep intervals
  if (windowKey != null) {
    await prefs.remove('sleep_intervals_$windowKey');
    await prefs.remove('last_screen_off_$windowKey');
  }

  print("✅ Sleep data saved successfully");

  // Notify UI
  service.invoke("sleep_saved", {
    "duration": totalSleepMinutes,
    "goal_minutes": goalMinutes,
    "start_time": effectiveStart.toIso8601String(),
    "end_time": effectiveEnd.toIso8601String(),
  });

  // Reset notification
  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: "Health Tracking",
      content: "Monitoring steps & sleep...",
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 🧮 HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════════

_SleepWindow? _computeActiveSleepWindow(
  int bedtimeMinutes,
  int waketimeMinutes,
  DateTime now,
) {
  final bedHour = bedtimeMinutes ~/ 60;
  final bedMinute = bedtimeMinutes % 60;
  final wakeHour = waketimeMinutes ~/ 60;
  final wakeMinute = waketimeMinutes % 60;

  // Build bedtime for today
  DateTime start = DateTime(now.year, now.month, now.day, bedHour, bedMinute);

  // If bedtime is in the future (more than 5 min from now), use yesterday's bedtime
  if (start.isAfter(now.add(const Duration(minutes: 5)))) {
    start = start.subtract(const Duration(days: 1));
  }

  // Build wake time
  DateTime end = DateTime(
    start.year,
    start.month,
    start.day,
    wakeHour,
    wakeMinute,
  );

  // If wake time is before or equal to bedtime, it's next day
  if (!end.isAfter(start)) {
    end = end.add(const Duration(days: 1));
  }

  final key =
      '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';

  return _SleepWindow(start: start, end: end, dateKey: key);
}

String _formatDuration(int minutes) {
  final hours = minutes ~/ 60;
  final mins = minutes % 60;

  if (hours > 0) {
    return "${hours}h ${mins}m";
  } else {
    return "${mins}m";
  }
}

class _SleepWindow {
  final DateTime start;
  final DateTime end;
  final String dateKey;

  _SleepWindow({required this.start, required this.end, required this.dateKey});
}

bool _isValidMinutesOfDay(int? value) {
  return value != null && value >= 0 && value < 24 * 60;
}

int _coerceMinutesOfDay(int? value, {required int fallback}) {
  return _isValidMinutesOfDay(value) ? value! : fallback;
}
