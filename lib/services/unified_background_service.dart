import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:pedometer/pedometer.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/models/hive_models/sleep_log_g.dart';
import 'package:screen_state/screen_state.dart';
import '../common/global_variables.dart';
import '../consts/consts.dart';
import '../models/hive_models/sleep_log.dart';
import '../models/hive_models/steps_model.dart';
import '../common/agent_debug_logger.dart';

// Global references for step counting and sleep tracking
StreamSubscription<StepCount>? _pedometerSubscription;
StreamSubscription<ScreenStateEvent>? _screenSubscription;
Timer? _sleepProgressTimer;

@pragma("vm:entry-point")
Future<bool> unifiedBackgroundEntry(ServiceInstance service) async {
  try {
    DartPluginRegistrant.ensureInitialized();

    debugPrint('🧵 BG isolate started');

    // #region agent log
    AgentDebugLogger.log(
      runId: 'auth-bg',
      hypothesisId: 'B',
      location: 'unified_background_service.dart:unifiedBackgroundEntry:start',
      message: 'Unified background entry started',
      data: const {},
    );
    // #endregion

    // 🔥 REQUIRED: init Hive for THIS isolate
    await Hive.initFlutter();

    // 🔥 REQUIRED: register adapters AGAIN
    if (!Hive.isAdapterRegistered(SleepLogAdapter().typeId)) {
      Hive.registerAdapter(SleepLogAdapter());
    }
    if (!Hive.isAdapterRegistered(StepEntryAdapter().typeId)) {
      Hive.registerAdapter(StepEntryAdapter());
    }

    debugPrint('📦 Hive ready in BG isolate');

    // Foreground service (Android)
    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();
      service.setForegroundNotificationInfo(
        title: "Health Tracking",
        content: "Monitoring steps & sleep...",
      );
    }

    print("🚀 Unified background service started");

    final stepBox = await Hive.openBox<StepEntry>('step_history');
    final sleepBox = await Hive.openBox<SleepLog>('sleep_log');

    // SharedPrefs
    final prefs = await SharedPreferences.getInstance();

    // ═══════════════════════════════════════════════════════════════
    // 🌙 SLEEP TRACKING SETUP
    // ═══════════════════════════════════════════════════════════════

    service.on("start_sleep").listen((event) async {
      final now = DateTime.now();
      final goalMinutes = event?['goal_minutes'] as int? ?? 480; // default 8h

      await prefs.setBool("is_sleeping", true);
      await prefs.setString("sleep_start_time", now.toIso8601String());
      await prefs.setInt("sleep_goal_minutes", goalMinutes);

      // Send initial update
      service.invoke("sleep_update", {
        "elapsed_minutes": 0,
        "goal_minutes": goalMinutes,
        "is_sleeping": true,
      });

      print("🌙 Sleep started at $now with goal: $goalMinutes mins");

      // Update notification
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "Sleep Tracking Active 😴",
          content:
              "0 min / ${_formatDuration(goalMinutes)} - Target: ${_formatDuration(goalMinutes)}",
        );
      }
    });

    service.on("stop_sleep").listen((event) async {
      final now = DateTime.now();
      final startString = prefs.getString("sleep_start_time");

      if (startString == null) {
        print("⚠️ No sleep start time found");
        return;
      }

      final start = DateTime.parse(startString);
      final totalSleep = now.difference(start);
      final goalMinutes = prefs.getInt("sleep_goal_minutes") ?? 480;

      // START OF FIX: Use Wake Up Date for Attribution
      // If we cross midnight (start != now.day), we attribute to the day we woke up (now).
      // This ensures the data appears on the "morning" of the sleep.
      final key =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      await sleepBox.put(
        key,
        SleepLog(
          date: DateTime(
            now.year,
            now.month,
            now.day,
          ), // Persistence Date = Wake Date
          durationMinutes: totalSleep.inMinutes,
          startTime: start,
          endTime: now,
          goalMinutes: goalMinutes,
        ),
      );

      // Clear sleep state
      await prefs.setBool("is_sleeping", false);
      await prefs.remove("sleep_start_time");
      await prefs.remove("sleep_goal_minutes");

      // Stop screen monitoring
      await _screenSubscription?.cancel();
      _screenSubscription = null;

      print(
        "☀️ Sleep ended. Duration: ${totalSleep.inMinutes} mins. Saved to $key",
      );

      // Notify UI
      service.invoke("sleep_saved", {
        "duration": totalSleep.inMinutes,
        "goal_minutes": goalMinutes,
        "start_time": start.toIso8601String(),
        "end_time": now.toIso8601String(),
        "date_key": key,
      });

      // Reset notification
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "Health Tracking",
          content: "Monitoring steps & sleep...",
        );
      }
    });

    // ═══════════════════════════════════════════════════════════════
    // 📱 SCREEN STATE MONITORING (For Deep Sleep Analysis)
    // ═══════════════════════════════════════════════════════════════

    void _startScreenMonitoring() {
      _screenSubscription?.cancel();
      try {
        final Screen _screen = Screen();
        _screenSubscription = _screen.screenStateStream?.listen((event) async {
          print('📱 BG Screen event: $event');

          if (event == ScreenStateEvent.SCREEN_OFF) {
            final now = DateTime.now();
            final dateKey =
                "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
            await prefs.setString(
              'last_screen_off_$dateKey',
              now.toIso8601String(),
            );
          } else if (event == ScreenStateEvent.SCREEN_ON) {
            // Logic to track awake intervals during sleep
            // This can be expanded to refine "deep sleep" vs "light sleep"
          }
        });
      } catch (e) {
        print('❌ BG Screen stream error: $e');
      }
    }

    // Auto-start monitoring if already sleeping
    if (prefs.getBool("is_sleeping") ?? false) {
      _startScreenMonitoring();
    }

    // Also hook into start_sleep
    service.on("start_sleep").listen((event) {
      _startScreenMonitoring();
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

      final startString = prefs.getString("sleep_start_time");
      if (startString == null) return;

      final start = DateTime.parse(startString);
      final now = DateTime.now();
      final elapsedMinutes = now.difference(start).inMinutes;
      final goalMinutes = prefs.getInt("sleep_goal_minutes") ?? 480;

      // Send progress update to UI
      service.invoke("sleep_update", {
        "elapsed_minutes": elapsedMinutes,
        "goal_minutes": goalMinutes,
        "is_sleeping": true,
      });

      // Update notification
      if (service is AndroidServiceInstance) {
        final progress =
            ((elapsedMinutes / goalMinutes) * 100).clamp(0, 100).toInt();
        service.setForegroundNotificationInfo(
          title: "Sleep Tracking 😴 ($progress%)",
          content:
              "${_formatDuration(elapsedMinutes)} / ${_formatDuration(goalMinutes)} - Target: ${_formatDuration(goalMinutes)}",
        );
      }

      // Check if goal reached
      if (elapsedMinutes >= goalMinutes) {
        service.invoke("sleep_goal_reached", {
          "elapsed_minutes": elapsedMinutes,
          "goal_minutes": goalMinutes,
        });
      }

      print("💤 Sleep progress: $elapsedMinutes / $goalMinutes mins");
    });

    // ═══════════════════════════════════════════════════════════════
    // 👣 STEP COUNTING SETUP
    // ═══════════════════════════════════════════════════════════════
    print("👣 Initializing step counter...");

    // Check for day reset (steps)
    final now = DateTime.now();
    final todayKey = "${now.year}-${now.month}-${now.day}";
    final lastDate = prefs.getString("last_step_date");

    if (lastDate != todayKey) {
      // New day - reset steps
      await prefs.setString("last_step_date", todayKey);
      await prefs.remove('lastRawSteps');
      await stepBox.put(todayKey, StepEntry(date: now, steps: 0));
      service.invoke("steps_updated", {"steps": 0});
    }

    // Listen to pedometer
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

        // Update notification with sleep status
        if (service is AndroidServiceInstance) {
          final isSleeping = prefs.getBool("is_sleeping") ?? false;

          if (isSleeping) {
            final startString = prefs.getString("sleep_start_time");
            if (startString != null) {
              final start = DateTime.parse(startString);
              final elapsedMinutes = DateTime.now().difference(start).inMinutes;
              final goalMinutes = prefs.getInt("sleep_goal_minutes") ?? 480;
              final progress =
                  ((elapsedMinutes / goalMinutes) * 100).clamp(0, 100).toInt();

              service.setForegroundNotificationInfo(
                title: "Sleep Tracking 😴 ($progress%)",
                content:
                    "${_formatDuration(elapsedMinutes)} / ${_formatDuration(goalMinutes)}",
              );
            }
          } else {
            service.setForegroundNotificationInfo(
              title: "Health Tracking",
              content: "$newSteps steps tracked",
            );
          }
        }

        print("👣 Steps: $newSteps (diff: $diff)");
      },
      onError: (error) {
        print("❌ Pedometer error: $error");
      },
    );

    // ═══════════════════════════════════════════════════════════════
    // 🛑 SERVICE STOP LISTENER
    // ═══════════════════════════════════════════════════════════════
    service.on('stopService').listen((_) {
      print("🛑 Stopping unified background service...");

      // #region agent log
      AgentDebugLogger.log(
        runId: 'auth-bg',
        hypothesisId: 'C',
        location: 'unified_background_service.dart:stopService:listener',
        message: 'Received stopService in background isolate',
        data: const {},
      );
      // #endregion

      _pedometerSubscription?.cancel();
      _sleepProgressTimer?.cancel();
      _screenSubscription?.cancel();
      service.stopSelf();
    });

    print("✅ Unified background service fully initialized");

    return true;
  } catch (e) {
    print("❌ Unified background service failed: $e");
    return false;
  }
}

// Helper function to format duration
String _formatDuration(int minutes) {
  final hours = minutes ~/ 60;
  final mins = minutes % 60;

  if (hours > 0) {
    return "${hours}h ${mins}m";
  } else {
    return "${mins}m";
  }
}
