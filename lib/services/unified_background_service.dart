import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../consts/consts.dart';
import '../common/agent_debug_logger.dart';
import '../services/sleep/sleep_noticing_service.dart';
import '../services/file_storage_service.dart';

// ───────────────────────────────────────────────────────────────────
// Constants
// ───────────────────────────────────────────────────────────────────

const String _lastAutoStartedSleepWindowKey = 'last_auto_started_sleep_window';
const String _manualStoppedWindowKey = 'manually_stopped_window_key';

// Single instance of SleepNoticingService per BG isolate lifetime
final SleepNoticingService _sleepNoticingService = SleepNoticingService();

// 1-minute periodic timer that ticks the sleep notification while sleeping
Timer? _sleepProgressTimer;

// ───────────────────────────────────────────────────────────────────
// BG ISOLATE ENTRY POINT
// ───────────────────────────────────────────────────────────────────

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

    // No Hive init needed in the BG isolate — file storage is stateless.
    debugPrint('📦 File storage ready in BG isolate at ${DateTime.now()}');

    // ── Become a foreground service ──────────────────────────────
    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();
      // NOTE: We do NOT call setForegroundNotificationInfo here.
      // The native Kotlin StepCounterService owns the notification content
      // (it shows both steps + sleep simultaneously). Dart only updates
      // SharedPrefs values that Kotlin reads on its 1-min ticker.
    }

    print("🚀 Unified background service started at ${DateTime.now()}");

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    // Seed sleep_elapsed_minutes = 0 so Kotlin notification starts clean.
    await prefs.setInt('sleep_elapsed_minutes', 0);

    await _ensureCurrentDayStepState(
      service: service,
      prefs: prefs,
      forceNotify: true,
    );

    await _restoreOrAutoStartSleepTracking(
      service: service,
      prefs: prefs,
    );

    // ── Always-on 1-min heartbeat ─────────────────────────────────
    _startHeartbeatTimer(
      service: service,
      prefs: prefs,
    );

    // 🌙 SLEEP TRACKING — start_sleep event
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

      // Calculate and store sleep window
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
      _sleepNoticingService.startMonitoring();

      service.invoke("sleep_update", {
        "elapsed_minutes": 0,
        "goal_minutes": goalMinutes,
        "is_sleeping": true,
      });

      print("🌙 Sleep tracking started at ${DateTime.now()}");
      print("   Goal: $goalMinutes mins");
      print("   Window: ${sleepWindow?.start} → ${sleepWindow?.end}");

      // Seed elapsed minutes so Kotlin's ticker shows sleep data immediately.
      await prefs.setInt('sleep_elapsed_minutes', 0);
      _startSleepProgressTimer(
        service: service,
        prefs: prefs,
        goalMinutes: goalMinutes,
      );
    });

    // ═══════════════════════════════════════════════════════════════
    // 🌙 SLEEP TRACKING — stop_sleep event
    // ═══════════════════════════════════════════════════════════════

    service.on("stop_sleep").listen((event) async {
      _sleepProgressTimer?.cancel();
      _sleepProgressTimer = null;
      _sleepNoticingService.stopMonitoring();
      print("✅ SleepNoticingService stopped at ${DateTime.now()}");
      await _stopSleepAndSave(service, prefs);
    });

    // ═══════════════════════════════════════════════════════════════
    // 👣 STEP COUNTING — onStepDetected event (from native service)
    // ═══════════════════════════════════════════════════════════════

    print("👣 Initializing step counter at ${DateTime.now()}...");

    service.on('onStepDetected').listen((event) async {
      if (event == null) return;

      final int newTotalSteps = event['steps'] as int;

      await prefs.reload();
      final savedSteps = prefs.getInt("today_steps") ?? 0;

      if (newTotalSteps > savedSteps) {
        await prefs.setInt("today_steps", newTotalSteps);

        // Append to file buffer — no Hive write
        await FileStorageService().appendStepEvent(newTotalSteps);

        service.invoke("steps_updated", {"steps": newTotalSteps});

        // Update notification only when NOT in sleep mode
        final isSleeping = prefs.getBool("is_sleeping") ?? false;
        if (!isSleeping) {
          _updateStepNotification(service: service, steps: newTotalSteps);
        }
      }
    });

    // ═══════════════════════════════════════════════════════════════
    // ⏰ ALARM WAKEUP — sparse 15-min heartbeat
    // ═══════════════════════════════════════════════════════════════

    service.on('onAlarmWakeup').listen((_) async {
      await prefs.reload();

      await _ensureCurrentDayStepState(
        service: service,
        prefs: prefs,
      );

      await _restoreOrAutoStartSleepTracking(
        service: service,
        prefs: prefs,
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

        _updateSleepNotification(
          service: service,
          elapsedMinutes: totalSleepMinutes,
          goalMinutes: goalMinutes,
        );

        // Auto-close if sleep window has ended
        final windowEndStr = prefs.getString("current_sleep_window_end");
        if (windowEndStr != null) {
          final windowEnd = DateTime.parse(windowEndStr);
          if (DateTime.now().isAfter(windowEnd)) {
            _sleepProgressTimer?.cancel();
            _sleepProgressTimer = null;
            await _stopSleepAndSave(service, prefs);
          }
        }
      }
    });

    // ═══════════════════════════════════════════════════════════════
    // 🛑 SERVICE STOP
    // ═══════════════════════════════════════════════════════════════

    service.on('stopService').listen((_) async {
      print("🛑 Stopping unified background service at ${DateTime.now()}...");
      _sleepProgressTimer?.cancel();
      _sleepProgressTimer = null;
      _sleepNoticingService.stopMonitoring();

      // Flush buffers before stopping so no data is lost
      await FileStorageService().flushStepsToDaily();
      await FileStorageService().flushSleepToDaily();

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

// ───────────────────────────────────────────────────────────────────
// 🔔 NOTIFICATION HELPERS — single source of truth
// ───────────────────────────────────────────────────────────────────

/// Notification updates are now owned entirely by the native Kotlin
/// StepCounterService. This function is intentionally a no-op so that
/// any remaining call-sites compile without changes.
void _updateStepNotification({
  required ServiceInstance service,
  required int steps,
}) {
  // No-op: Kotlin reads flutter.today_steps and updates the notification itself.
}

/// Notification updates are now owned entirely by the native Kotlin
/// StepCounterService. This function is intentionally a no-op so that
/// any remaining call-sites compile without changes.
void _updateSleepNotification({
  required ServiceInstance service,
  required int elapsedMinutes,
  required int goalMinutes,
}) {
  // No-op: Kotlin reads flutter.sleep_elapsed_minutes and updates the notification itself.
}

// ───────────────────────────────────────────────────────────────────
// ⏱️ ALWAYS-ON 1-MIN HEARTBEAT TIMER
// ───────────────────────────────────────────────────────────────────

void _startHeartbeatTimer({
  required ServiceInstance service,
  required SharedPreferences prefs,
}) {
  _sleepProgressTimer?.cancel();
  _sleepProgressTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
    await prefs.reload();
    final isSleeping = prefs.getBool('is_sleeping') ?? false;

    if (isSleeping) {
      final goalMinutes = prefs.getInt('sleep_goal_minutes') ?? 480;
      final totalSleepMinutes =
          await _sleepNoticingService.getTotalSleepMinutes();
      final windowKey = prefs.getString('current_sleep_window_key');
      final startTime = prefs.getString('sleep_start_time');

      // Write elapsed minutes so Kotlin can display it in the unified notification.
      await prefs.setInt('sleep_elapsed_minutes', totalSleepMinutes);

      service.invoke('sleep_update', {
        'elapsed_minutes': totalSleepMinutes,
        'goal_minutes': goalMinutes,
        'is_sleeping': true,
        'current_sleep_window_key': windowKey,
        'start_time': startTime,
      });

      // Auto-close when window has passed
      final windowEndStr = prefs.getString('current_sleep_window_end');
      if (windowEndStr != null) {
        try {
          final windowEnd = DateTime.parse(windowEndStr);
          if (DateTime.now().isAfter(windowEnd)) {
            _sleepNoticingService.stopMonitoring();
            await _stopSleepAndSave(service, prefs);
          }
        } catch (_) {}
      }
    } else {
      await _restoreOrAutoStartSleepTracking(
        service: service,
        prefs: prefs,
      );
    }
  });
}

// Keep old thin wrapper so existing call-sites compile.
void _startSleepProgressTimer({
  required ServiceInstance service,
  required SharedPreferences prefs,
  required int goalMinutes,
}) {
  _startHeartbeatTimer(service: service, prefs: prefs);
}

// ───────────────────────────────────────────────────────────────────
// 🌙 SLEEP SESSION RESTORE / AUTO-START
// ───────────────────────────────────────────────────────────────────

Future<void> _restoreOrAutoStartSleepTracking({
  required ServiceInstance service,
  required SharedPreferences prefs,
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
    // Past window end → auto-save and exit sleep mode
    if (sleepWindow != null && nowTime.isAfter(sleepWindow.end)) {
      print("⏰ Service recovery detected window end. Auto-saving sleep...");
      _sleepProgressTimer?.cancel();
      _sleepProgressTimer = null;
      await _stopSleepAndSave(service, prefs);
      return;
    }

    // Resume active sleep session
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

    // Seed elapsed minutes so Kotlin's ticker shows current sleep data
    // immediately after a service restore/restart.
    await prefs.setInt('sleep_elapsed_minutes', totalSleepMinutes);

    _startSleepProgressTimer(
      service: service,
      prefs: prefs,
      goalMinutes: goalMinutes,
    );
    return;
  }

  // Not sleeping — check if we should auto-start
  if (sleepWindow == null) return;

  final blockedByManualStop = await _isManualStopBlockingThisWindow(
    prefs: prefs,
    currentWindow: sleepWindow,
  );
  if (blockedByManualStop) return;

  if (!_isWithinWindow(nowTime, sleepWindow.start, sleepWindow.end)) return;

  final lastAutoStarted = prefs.getString(_lastAutoStartedSleepWindowKey);
  if (lastAutoStarted == sleepWindow.dateKey) return;

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

// ───────────────────────────────────────────────────────────────────
// 🌙 SLEEP SESSION START
// ───────────────────────────────────────────────────────────────────

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

  // Seed elapsed minutes in SharedPrefs so Kotlin's 1-min ticker
  // immediately picks up the correct value without waiting for the first heartbeat.
  await prefs.setInt('sleep_elapsed_minutes', totalSleepMinutes);

  _startSleepProgressTimer(
    service: service,
    prefs: prefs,
    goalMinutes: goalMinutes,
  );
}

// ───────────────────────────────────────────────────────────────────
// 🛡️ MANUAL STOP GUARD
// ───────────────────────────────────────────────────────────────────

Future<bool> _isManualStopBlockingThisWindow({
  required SharedPreferences prefs,
  required _SleepWindow currentWindow,
}) async {
  final manuallyStopped = prefs.getBool('manually_stopped') ?? false;
  if (!manuallyStopped) return false;

  final manuallyStoppedForWindow = prefs.getString(_manualStoppedWindowKey);

  if (manuallyStoppedForWindow == null) {
    await prefs.setString(_manualStoppedWindowKey, currentWindow.dateKey);
    return true;
  }

  if (manuallyStoppedForWindow == currentWindow.dateKey) return true;

  await prefs.setBool('manually_stopped', false);
  await prefs.remove(_manualStoppedWindowKey);
  return false;
}

// ───────────────────────────────────────────────────────────────────
// 👣 STEP STATE — day boundary / first-run
// ───────────────────────────────────────────────────────────────────

Future<void> _ensureCurrentDayStepState({
  required ServiceInstance service,
  required SharedPreferences prefs,
  bool forceNotify = false,
}) async {
  final nowTime = DateTime.now();
  final todayKey =
      "${nowTime.year}-${nowTime.month.toString().padLeft(2, '0')}-${nowTime.day.toString().padLeft(2, '0')}";
  final lastDate = prefs.getString("last_step_date");

  if (lastDate == todayKey && !forceNotify) return;

  await prefs.setString("last_step_date", todayKey);

  // On day change: flush step buffer so the completed day is written to its
  // daily JSON, then queue it for sync.
  if (lastDate != null && lastDate != todayKey) {
    await FileStorageService().flushStepsToDaily();
    await FileStorageService().flushSleepToDaily();
    await FileStorageService().addToSyncQueue(lastDate);
    debugPrint('📤 Day change: queued $lastDate for sync');
  }

  // Read today's steps from file (or SharedPrefs fast path)
  final todaySteps = prefs.getInt('today_steps') ?? 0;
  service.invoke("steps_updated", {"steps": todaySteps});

  final isSleeping = prefs.getBool("is_sleeping") ?? false;
  if (!isSleeping) {
    _updateStepNotification(service: service, steps: todaySteps);
  }
}

// ───────────────────────────────────────────────────────────────────
// 💾 STOP SLEEP AND SAVE — writes to file storage, not Hive
// ───────────────────────────────────────────────────────────────────

Future<void> _stopSleepAndSave(
  ServiceInstance service,
  SharedPreferences prefs,
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
      if (effectiveStart.isBefore(windowStart)) effectiveStart = windowStart;
    } catch (_) {}
  }

  if (windowEndString != null) {
    try {
      final windowEnd = DateTime.parse(windowEndString);
      if (effectiveEnd.isAfter(windowEnd)) effectiveEnd = windowEnd;
    } catch (_) {}
  }

  if (!effectiveEnd.isAfter(effectiveStart)) effectiveEnd = effectiveStart;

  // ── Step 1: Close any open interval (screen still off at wake time) ─────
  // If the screen is still off when the session ends, the open interval has
  // NOT yet been written to sleep_buf.tmp. We compute and flush it now so
  // that it is included in the final total.
  if (windowKey != null) {
    final openMins = await _sleepNoticingService.flushOpenInterval(windowKey);
    if (openMins > 0) {
      debugPrint('📱 Flushed open interval at session end: ${openMins}m');
    }
  }

  // ── Step 2: Flush buffer → daily JSON BEFORE reading the total ──────────
  // sleep_buf.tmp may contain intervals from earlier SCREEN_ON events that
  // have never been merged into the daily JSON yet.  Reading the total before
  // this flush caused those intervals to be silently ignored.
  if (windowKey != null) {
    await FileStorageService().flushSleepToDaily();
    debugPrint('✅ Sleep buffer flushed before total read');
  }

  // ── Step 3: Read the accurate total from the daily JSON ─────────────────
  final totalSleepMinutes = await _sleepNoticingService.getTotalSleepMinutes();

  print("💾 Saving sleep data:");
  print("   Start: $effectiveStart");
  print("   End: $effectiveEnd");
  print("   Total sleep: $totalSleepMinutes mins");
  print("   Goal: $goalMinutes mins");

  // ── Step 4: Queue the day for API sync ──────────────────────────────────
  if (windowKey != null) {
    await FileStorageService().addToSyncQueue(windowKey);
    debugPrint('✅ Sleep session saved to file storage: $windowKey');
  }

  // Clear sleep state
  await prefs.setBool("is_sleeping", false);
  await prefs.remove("sleep_start_time");
  await prefs.remove("sleep_goal_minutes");
  await prefs.remove("current_sleep_window_start");
  await prefs.remove("current_sleep_window_end");
  await prefs.remove("current_sleep_window_key");
  // Reset elapsed minutes so Kotlin notification reverts to "😴 Sleep: --"
  await prefs.setInt("sleep_elapsed_minutes", 0);

  // Clear sleep intervals from SharedPrefs (no longer the source of truth)
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

  // Restore step notification
  await prefs.reload();
  final steps = prefs.getInt("today_steps") ?? 0;
  _updateStepNotification(service: service, steps: steps);
}

// ───────────────────────────────────────────────────────────────────
// 🧮 SLEEP WINDOW HELPERS
// ───────────────────────────────────────────────────────────────────

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
      !_isValidMinutesOfDay(waketimeMinutes))
    return 480;

  var wake = waketimeMinutes;
  if (wake <= bedtimeMinutes) wake += 24 * 60;
  final diff = wake - bedtimeMinutes;
  return diff <= 0 ? 480 : diff;
}

bool _isWithinWindow(DateTime nowTime, DateTime start, DateTime end) {
  return (!nowTime.isBefore(start)) && nowTime.isBefore(end);
}

_SleepWindow? _computeActiveSleepWindow(
  int bedtimeMinutes,
  int waketimeMinutes,
  DateTime now,
) {
  final bedHour = bedtimeMinutes ~/ 60;
  final bedMinute = bedtimeMinutes % 60;
  final wakeHour = waketimeMinutes ~/ 60;
  final wakeMinute = waketimeMinutes % 60;

  DateTime start = DateTime(now.year, now.month, now.day, bedHour, bedMinute);

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
  if (hours > 0) return "${hours}h ${mins}m";
  return "${mins}m";
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
