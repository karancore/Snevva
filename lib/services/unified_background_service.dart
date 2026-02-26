import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:pedometer/pedometer.dart';
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
StreamSubscription<StepCount>? _pedometerSubscription;
Timer? _sleepProgressTimer;
Timer? _sleepIntervalAggregatorTimer;
Timer? _sleepWindowWatchdogTimer;

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
      DateTime now = DateTime.now();
      final wakeMinutes = prefs.getInt('flutter.user_waketime_ms') ?? 420;

      final wakeTimeToday = DateTime(
        now.year,
        now.month,
        now.day,
        wakeMinutes ~/ 60,
        wakeMinutes % 60,
      );

      DateTime sleepDay =
          now.isBefore(wakeTimeToday) ? now.subtract(Duration(days: 1)) : now;

      String key =
          "flutter.sleep_intervals_${sleepDay.year}-${sleepDay.month.toString().padLeft(2, '0')}-${sleepDay.day.toString().padLeft(2, '0')}";

      final goalMinutes = event?['goal_minutes'] as int? ?? 480;
      final bedtimeMinutes = event?['bedtime_minutes'] as int? ?? 0;
      final waketimeMinutes = event?['waketime_minutes'] as int? ?? 0;

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
      _startSleepIntervalAggregator(service, prefs);
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
    _sleepProgressTimer?.cancel();
    _sleepProgressTimer = Timer.periodic(const Duration(minutes: 1), (
      timer,
    ) async {
      final isSleeping = prefs.getBool("is_sleeping") ?? false;

      if (!isSleeping) return;

      final goalMinutes = prefs.getInt("sleep_goal_minutes") ?? 480;

      // Updated: Use the Dart service to get aggregated sleep time
      final totalSleepMinutes =
          await _sleepNoticingService.getTotalSleepMinutes();
      final windowKey = prefs.getString("current_sleep_window_key"); // Add this
      final startTime = prefs.getString("sleep_start_time"); // Add this

      // Send progress update to UI
      service.invoke("sleep_update", {
        "elapsed_minutes": totalSleepMinutes,
        "goal_minutes": goalMinutes,
        "is_sleeping": true,
        "current_sleep_window_key": windowKey, // Add this
        "start_time": startTime, // Add this
      });

      // Update notification
      if (service is AndroidServiceInstance) {
        final progress =
            ((totalSleepMinutes / goalMinutes) * 100).clamp(0, 100).toInt();
        service.setForegroundNotificationInfo(
          title: "Sleep Tracking 😴 ($progress%)",
          content:
              "${_formatDuration(totalSleepMinutes)} / ${_formatDuration(goalMinutes)} - Auto-tracking",
        );
      }

      // Check if goal reached
      if (totalSleepMinutes >= goalMinutes) {
        service.invoke("sleep_goal_reached", {
          "elapsed_minutes": totalSleepMinutes,
          "goal_minutes": goalMinutes,
        });
      }

      print(
        "💤 Sleep progress at ${DateTime.now()}: $totalSleepMinutes / $goalMinutes mins",
      );

      // Check if sleep window has ended
      final windowEndStr = prefs.getString("current_sleep_window_end");
      if (windowEndStr != null) {
        final windowEnd = DateTime.parse(windowEndStr);
        if (DateTime.now().isAfter(windowEnd)) {
          print(
            "⏰ Sleep window ended at ${DateTime.now()}, auto-saving sleep data",
          );
          await _stopSleepAndSave(service, prefs, sleepBox);
        }
      }
    });

    // ═══════════════════════════════════════════════════════════════
    // 👣 STEP COUNTING SETUP
    // ═══════════════════════════════════════════════════════════════
    print("👣 Initializing step counter at ${DateTime.now()}...");

    await _pedometerSubscription?.cancel();
    _pedometerSubscription = Pedometer.stepCountStream.listen(
      (StepCount event) async {
        await _ensureCurrentDayStepState(
          service: service,
          prefs: prefs,
          stepBox: stepBox,
        );

        final now = DateTime.now();
        final todayKey = "${now.year}-${now.month}-${now.day}";

        final lastRawSteps = prefs.getInt('lastRawSteps') ?? event.steps;
        int diff = event.steps - lastRawSteps;

        if (diff < 0) {
          diff = event.steps;
        }

        final todayEntry = stepBox.get(todayKey);
        final currentSteps = todayEntry?.steps ?? 0;
        final newSteps = currentSteps + diff;

        await stepBox.put(todayKey, StepEntry(date: now, steps: newSteps));
        await prefs.setInt('today_steps', newSteps);
        await prefs.setInt('lastRawSteps', event.steps);

        service.invoke("steps_updated", {"steps": newSteps});

        // Update notification
        if (service is AndroidServiceInstance) {
          final isSleeping = prefs.getBool("is_sleeping") ?? false;

          if (isSleeping) {
            final goalMinutes = prefs.getInt("sleep_goal_minutes") ?? 480;
            final totalSleepMinutes =
                await _sleepNoticingService.getTotalSleepMinutes();
            final progress =
                ((totalSleepMinutes / goalMinutes) * 100).clamp(0, 100).toInt();

            service.setForegroundNotificationInfo(
              title: "Sleep Tracking 😴 ($progress%)",
              content:
                  "${_formatDuration(totalSleepMinutes)} / ${_formatDuration(goalMinutes)}",
            );
          } else {
            service.setForegroundNotificationInfo(
              title: "Health Tracking",
              content: "$newSteps steps tracked",
            );
          }
        }
      },
      onError: (error) {
        print("❌ Pedometer error: $error at ${DateTime.now()}");
      },
    );

    _startSleepWindowWatchdog(
      service: service,
      prefs: prefs,
      sleepBox: sleepBox,
      stepBox: stepBox,
    );

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

      _pedometerSubscription?.cancel();
      _sleepProgressTimer?.cancel();
      _sleepIntervalAggregatorTimer?.cancel();
      _sleepWindowWatchdogTimer?.cancel();
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

void _startSleepWindowWatchdog({
  required ServiceInstance service,
  required SharedPreferences prefs,
  required Box<SleepLog> sleepBox,
  required Box<StepEntry> stepBox,
}) {
  _sleepWindowWatchdogTimer?.cancel();

  _sleepWindowWatchdogTimer = Timer.periodic(const Duration(minutes: 1), (
    _,
  ) async {
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
  });
}

Future<void> _restoreOrAutoStartSleepTracking({
  required ServiceInstance service,
  required SharedPreferences prefs,
  required Box<SleepLog> sleepBox,
}) async {
  await prefs.reload();

  final bedtimeMinutes = prefs.getInt("user_bedtime_ms") ?? 0;
  final waketimeMinutes = prefs.getInt("user_waketime_ms") ?? 0;
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
    _startSleepIntervalAggregator(service, prefs);

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

  final goalMinutes = _calculateSleepGoalMinutes(
    bedtimeMinutes: bedtimeMinutes,
    waketimeMinutes: waketimeMinutes,
  );

  await _startSleepTrackingSession(
    service: service,
    prefs: prefs,
    goalMinutes: goalMinutes,
    bedtimeMinutes: bedtimeMinutes,
    waketimeMinutes: waketimeMinutes,
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

  _startSleepIntervalAggregator(service, prefs);
}

_SleepWindow? _resolveSleepWindow({
  required SharedPreferences prefs,
  required int bedtimeMinutes,
  required int waketimeMinutes,
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

  return _computeActiveSleepWindow(bedtimeMinutes, waketimeMinutes, nowTime);
}

int _calculateSleepGoalMinutes({
  required int bedtimeMinutes,
  required int waketimeMinutes,
}) {
  if (bedtimeMinutes <= 0 && waketimeMinutes <= 0) {
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
  await prefs.remove('lastRawSteps');

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

void _startSleepIntervalAggregator(
  ServiceInstance service,
  SharedPreferences prefs,
) {
  _sleepIntervalAggregatorTimer?.cancel();

  // Aggregate intervals every 30 seconds for real-time updates
  _sleepIntervalAggregatorTimer = Timer.periodic(const Duration(seconds: 30), (
    timer,
  ) async {
    final isSleeping = prefs.getBool("is_sleeping") ?? false;
    if (!isSleeping) {
      timer.cancel();
      return;
    }

    final totalSleepMinutes =
        await _sleepNoticingService.getTotalSleepMinutes();
    final goalMinutes = prefs.getInt("sleep_goal_minutes") ?? 480;
    final windowKey = prefs.getString("current_sleep_window_key"); // Add this
    final startTime = prefs.getString("sleep_start_time"); // Add this

    // Update UI
    service.invoke("sleep_update", {
      "elapsed_minutes": totalSleepMinutes,
      "goal_minutes": goalMinutes,
      "is_sleeping": true,
      "current_sleep_window_key": windowKey, // Add this
      "start_time": startTime, // Add this
    });

    print(
      "📊 Aggregated sleep at ${DateTime.now()}: $totalSleepMinutes mins (goal: $goalMinutes)",
    );
  });
}

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

  // Get total sleep time from aggregated intervals
  // Get total sleep time from aggregated intervals (use service implementation)
  final totalSleepMinutes = await _sleepNoticingService.getTotalSleepMinutes();

  print("💾 Saving sleep data:");
  print("   Start: $start");
  print("   End: $now");
  print("   Total sleep: $totalSleepMinutes mins");
  print("   Goal: $goalMinutes mins");

  // Save to Hive
  if (windowKey != null) {
    await sleepBox.put(
      windowKey,
      SleepLog(
        date: DateTime.parse(windowKey),
        // Use the sleep window date
        durationMinutes: totalSleepMinutes,
        startTime: start,
        endTime: now,
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
    "start_time": start.toIso8601String(),
    "end_time": now.toIso8601String(),
  });

  // Stop interval aggregator
  _sleepIntervalAggregatorTimer?.cancel();

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
