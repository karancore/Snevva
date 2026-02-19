import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:pedometer/pedometer.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/models/hive_models/sleep_log_g.dart';
import 'package:snevva/services/hive_service.dart';
import '../common/global_variables.dart';
import '../consts/consts.dart';
import '../models/hive_models/sleep_log.dart';
import '../models/hive_models/steps_model.dart';
import '../common/agent_debug_logger.dart';
import '../services/sleep/sleep_noticing_service.dart';
import 'app_initializer.dart';

// Global references
StreamSubscription<StepCount>? _pedometerSubscription;
Timer? _sleepProgressTimer;
Timer? _sleepIntervalAggregatorTimer;

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

    await HiveService().initBackground();

    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(SleepLogAdapter().typeId)) {
      Hive.registerAdapter(SleepLogAdapter());
    }
    if (!Hive.isAdapterRegistered(StepEntryAdapter().typeId)) {
      Hive.registerAdapter(StepEntryAdapter());
    }

    debugPrint('📦 Hive ready in BG isolate at ${DateTime.now()}');

    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();
      service.setForegroundNotificationInfo(
        title: "Health Tracking",
        content: "Monitoring steps & sleep...",
      );
    }

    print("🚀 Unified background service started at ${DateTime.now()}");

    final sleepBox = HiveService().sleepLog;
    final stepBox = HiveService().stepHistory;
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    // ═══════════════════════════════════════════════════════════════
    // 🌙 SLEEP TRACKING SETUP
    // ═══════════════════════════════════════════════════════════════

    service.on("start_sleep").listen((event) async {
      await prefs.reload(); // Always reload before reading in BG isolate

      final goalMinutes = event?['goal_minutes'] as int? ?? 480;
      final bedtimeMinutes = event?['bedtime_minutes'] as int? ?? 0;
      final waketimeMinutes = event?['waketime_minutes'] as int? ?? 0;

      final now = DateTime.now();

      await prefs.setBool("is_sleeping", true);
      await prefs.setString("sleep_start_time", now.toIso8601String());
      await prefs.setInt("sleep_goal_minutes", goalMinutes);

      // ✅ FIX #1: Use consistent keys — NO 'flutter.' prefix, plain SharedPreferences keys only
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

        debugPrint(
          '🛏️ Sleep window: ${sleepWindow.start} → ${sleepWindow.end}',
        );
        debugPrint('🗓️ Window key: ${sleepWindow.dateKey}');
      } else {
        debugPrint(
          '⚠️ Could not compute sleep window — bedtime=$bedtimeMinutes wake=$waketimeMinutes',
        );
      }

      await _sleepNoticingService.initializeForSleepWindow();
      _sleepNoticingService.startMonitoring();

      print("✅ SleepNoticingService started at ${DateTime.now()}");

      service.invoke("sleep_update", {
        "elapsed_minutes": 0,
        "goal_minutes": goalMinutes,
        "is_sleeping": true,
        "current_sleep_window_key": sleepWindow?.dateKey,
        "start_time": now.toIso8601String(),
      });

      print("🌙 Sleep tracking started at ${DateTime.now()}");
      print("   Goal: $goalMinutes mins");
      print("   Window: ${sleepWindow?.start} → ${sleepWindow?.end}");

      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "Sleep Tracking Active 😴",
          content:
              "0 min / ${_formatDuration(goalMinutes)} - Auto-tracking screen off time",
        );
      }

      _startSleepIntervalAggregator(service, prefs);
    });

    service.on("stop_sleep").listen((event) async {
      _sleepNoticingService.stopMonitoring();
      print("✅ SleepNoticingService stopped at ${DateTime.now()}");

      await _stopSleepAndSave(service, prefs, sleepBox);
    });

    // ═══════════════════════════════════════════════════════════════
    // ⏱️ SLEEP PROGRESS TIMER (updates every minute)
    // ═══════════════════════════════════════════════════════════════
    _sleepProgressTimer?.cancel();
    _sleepProgressTimer = Timer.periodic(const Duration(minutes: 1), (
      timer,
    ) async {
      await prefs
          .reload(); // ✅ FIX #2: Always reload in timer — stale reads cause 0 data on real devices
      final isSleeping = prefs.getBool("is_sleeping") ?? false;

      if (!isSleeping) return;

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

      if (totalSleepMinutes >= goalMinutes) {
        service.invoke("sleep_goal_reached", {
          "elapsed_minutes": totalSleepMinutes,
          "goal_minutes": goalMinutes,
        });
      }

      print(
        "💤 Sleep progress at ${DateTime.now()}: $totalSleepMinutes / $goalMinutes mins",
      );

      // Auto-save when window ends
      final windowEndStr = prefs.getString("current_sleep_window_end");
      if (windowEndStr != null) {
        final windowEnd = DateTime.parse(windowEndStr);
        if (DateTime.now().isAfter(windowEnd)) {
          print("⏰ Sleep window ended, auto-saving...");
          await _stopSleepAndSave(service, prefs, sleepBox);
        }
      }
    });

    // ═══════════════════════════════════════════════════════════════
    // 👣 STEP COUNTING SETUP
    // ═══════════════════════════════════════════════════════════════
    print("👣 Initializing step counter at ${DateTime.now()}...");

    final now = DateTime.now();
    final todayKey = "${now.year}-${now.month}-${now.day}";
    final lastDate = prefs.getString("last_step_date");

    if (lastDate != todayKey) {
      await prefs.setString("last_step_date", todayKey);
      await prefs.remove('lastRawSteps');
      await stepBox.put(todayKey, StepEntry(date: now, steps: 0));
      service.invoke("steps_updated", {"steps": 0});
    }

    await _pedometerSubscription?.cancel();
    _pedometerSubscription = Pedometer.stepCountStream.listen(
      (StepCount event) async {
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

    // ═══════════════════════════════════════════════════════════════
    // 🛑 SERVICE STOP LISTENER
    // ═══════════════════════════════════════════════════════════════
    service.on('stopService').listen((_) {
      print("🛑 Stopping unified background service at ${DateTime.now()}...");

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

// ═══════════════════════════════════════════════════════════════
// 📊 SLEEP INTERVAL AGGREGATION
// ═══════════════════════════════════════════════════════════════

void _startSleepIntervalAggregator(
  ServiceInstance service,
  SharedPreferences prefs,
) {
  _sleepIntervalAggregatorTimer?.cancel();

  _sleepIntervalAggregatorTimer = Timer.periodic(const Duration(seconds: 30), (
    timer,
  ) async {
    await prefs.reload(); // ✅ FIX #2 continued: reload before every read
    final isSleeping = prefs.getBool("is_sleeping") ?? false;
    if (!isSleeping) {
      timer.cancel();
      return;
    }

    final totalSleepMinutes =
        await _sleepNoticingService.getTotalSleepMinutes();
    final goalMinutes = prefs.getInt("sleep_goal_minutes") ?? 480;
    final windowKey = prefs.getString("current_sleep_window_key");
    final startTime = prefs.getString("sleep_start_time");

    service.invoke("sleep_update", {
      "elapsed_minutes": totalSleepMinutes,
      "goal_minutes": goalMinutes,
      "is_sleeping": true,
      "current_sleep_window_key": windowKey,
      "start_time": startTime,
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
  await prefs.reload();

  final now = DateTime.now();
  final startString = prefs.getString("sleep_start_time");

  if (startString == null) {
    print("⚠️ No sleep start time found");
    return;
  }

  final start = DateTime.parse(startString);
  final goalMinutes = prefs.getInt("sleep_goal_minutes") ?? 480;
  final windowKey = prefs.getString("current_sleep_window_key");

  final totalSleepMinutes = await _sleepNoticingService.getTotalSleepMinutes();

  print("💾 Saving sleep data:");
  print("   Start: $start");
  print("   End: $now");
  print("   Total sleep: $totalSleepMinutes mins");
  print("   Goal: $goalMinutes mins");
  print("   Window key: $windowKey");

  if (windowKey != null) {
    await sleepBox.put(
      windowKey,
      SleepLog(
        date: DateTime.parse(windowKey),
        durationMinutes: totalSleepMinutes,
        startTime: start,
        endTime: now,
        goalMinutes: goalMinutes,
      ),
    );
    print("✅ Saved to Hive: $windowKey → $totalSleepMinutes min");
  } else {
    // ✅ FIX #3: Fallback — if window key is missing for any reason, still save to today
    final fallbackKey =
        "${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}";
    await sleepBox.put(
      fallbackKey,
      SleepLog(
        date: DateTime(start.year, start.month, start.day),
        durationMinutes: totalSleepMinutes,
        startTime: start,
        endTime: now,
        goalMinutes: goalMinutes,
      ),
    );
    print(
      "✅ Saved to Hive (fallback key): $fallbackKey → $totalSleepMinutes min",
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
  final keyToClear =
      windowKey ??
      "${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}";
  await prefs.remove('sleep_intervals_$keyToClear');
  await prefs.remove('last_screen_off_$keyToClear');

  print("✅ Sleep state cleared from SharedPreferences");

  service.invoke("sleep_saved", {
    "duration": totalSleepMinutes,
    "goal_minutes": goalMinutes,
    "start_time": start.toIso8601String(),
    "end_time": now.toIso8601String(),
  });

  _sleepIntervalAggregatorTimer?.cancel();

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
  // ✅ FIX #4: Guard against both being 0 (means data was never set)
  if (bedtimeMinutes == 0 && waketimeMinutes == 0) {
    debugPrint(
      '⚠️ _computeActiveSleepWindow: both times are 0, returning null',
    );
    return null;
  }

  final bedHour = bedtimeMinutes ~/ 60;
  final bedMinute = bedtimeMinutes % 60;
  final wakeHour = waketimeMinutes ~/ 60;
  final wakeMinute = waketimeMinutes % 60;

  DateTime start = DateTime(now.year, now.month, now.day, bedHour, bedMinute);

  // If bedtime is more than 5 min in the future, use yesterday's bedtime
  if (start.isAfter(now.add(const Duration(minutes: 5)))) {
    start = start.subtract(const Duration(days: 1));
  }

  DateTime end = DateTime(
    start.year,
    start.month,
    start.day,
    wakeHour,
    wakeMinute,
  );

  // Wake time is next day if before or same as bedtime
  if (!end.isAfter(start)) {
    end = end.add(const Duration(days: 1));
  }

  final key =
      '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';

  debugPrint('✅ Sleep window computed: $start → $end (key: $key)');

  return _SleepWindow(start: start, end: end, dateKey: key);
}

String _formatDuration(int minutes) {
  final hours = minutes ~/ 60;
  final mins = minutes % 60;
  if (hours > 0) return "${hours}h ${mins}m";
  return "${mins}m";
}

class _SleepWindow {
  final DateTime start;
  final DateTime end;
  final String dateKey;

  _SleepWindow({required this.start, required this.end, required this.dateKey});
}
