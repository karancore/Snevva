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

    // Seed sleep_elapsed_minutes = 0 ONLY if it doesn't already exist.
    // This allows the notification to continue showing yesterday's sleep
    // until a new sleep session officially begins.
    if (!prefs.containsKey('sleep_elapsed_minutes')) {
      await prefs.setInt('sleep_elapsed_minutes', 0);
    }

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

      // NOTE: Auto-close on window end is intentionally NOT done here.
      // SleepCalcWorker.kt owns sleep finalization — it fires at the exact
      // wake time, writes flutter.sleep_final_minutes, clears is_sleeping,
      // and enqueues the sleep API call. Dart duplicating that logic would
      // cause race conditions and double API calls.
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

      // Write elapsed minutes so Kotlin's StepCounterService 1-min ticker can
      // display CASE A (live progress) in the unified notification.
      // SleepCalcWorker will overwrite this with the final value when the
      // window ends — Dart must NOT call _stopSleepAndSave() for that.
      await prefs.setInt('sleep_elapsed_minutes', totalSleepMinutes);

      service.invoke('sleep_update', {
        'elapsed_minutes': totalSleepMinutes,
        'goal_minutes': goalMinutes,
        'is_sleeping': true,
        'current_sleep_window_key': windowKey,
        'start_time': startTime,
      });

      // NOTE: Auto-close on window end is intentionally NOT performed here.
      // SleepCalcWorker.kt is scheduled for the exact wake time and handles:
      //   • flushing sleep_buf.tmp → daily JSON
      //   • writing flutter.sleep_final_minutes + clearing is_sleeping
      //   • queuing the sleep API call
      //   • rescheduling itself for the next night
      // Dart interfering here would cause race conditions and double-queuing.
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

  final bedtimeMinutes  = prefs.getInt("user_bedtime_ms");
  final waketimeMinutes = prefs.getInt("user_waketime_ms");
  final nowTime         = DateTime.now();
  final sleepWindow     = _resolveSleepWindow(
    prefs: prefs,
    bedtimeMinutes: bedtimeMinutes,
    waketimeMinutes: waketimeMinutes,
    nowTime: nowTime,
  );

  final isSleeping = prefs.getBool("is_sleeping") ?? false;

  if (isSleeping) {
    // Past window end: do NOT call _stopSleepAndSave() here.
    // SleepCalcWorker.kt fires at the wake time and owns finalization:
    //   flush → compute final total → write flutter.sleep_final_minutes
    //   → clear is_sleeping → queue sleep API.
    // If the BG isolate somehow wakes us after the window, just stop
    // monitoring screen events and let SleepCalcWorker finish the job.
    if (sleepWindow != null && nowTime.isAfter(sleepWindow.end)) {
      print("⏰ _restoreOrAutoStart: window passed — stopping screen monitor, SleepCalcWorker handles finalization.");
      _sleepNoticingService.stopMonitoring();
      return;
    }

    // Resume active sleep session (still within window)
    await _sleepNoticingService.initializeForSleepWindow();
    _sleepNoticingService.startMonitoring();

    final goalMinutes       = prefs.getInt("sleep_goal_minutes") ?? 480;
    final totalSleepMinutes = await _sleepNoticingService.getTotalSleepMinutes();

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

  // Not sleeping — check if we should auto-start the session
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

  // ── Day-change pipeline is now owned entirely by Kotlin (StepCounterService) ──
  // StepCounterService.onSensorChanged() fires on every step; when it detects a
  // new calendar date it:
  //   1. Flushes yesterday's step buffer → daily JSON (BufferManager.flushStepsToDaily)
  //   2. Adds yesterday to sync_queue.json (BufferManager.addToSyncQueue)
  //   3. Enqueues ApiSyncWorker with network constraint
  //
  // The Dart BG service must NOT duplicate these operations — it may be dead
  // overnight and would then flush an empty buffer over the correct Kotlin data.

  // Read today's steps from the ground-truth daily JSON file.
  // This avoids the "0 flash" seen when SharedPrefs cache is stale at startup.
  // Fall back to SharedPrefs fast-path if the file hasn't been flushed yet
  // (first few minutes of the day before the first 5-min flush).
  int todaySteps = await FileStorageService().readDailySteps(todayKey);
  if (todaySteps == 0) {
    await prefs.reload();
    todaySteps = prefs.getInt('today_steps') ?? 0;
  }

  service.invoke("steps_updated", {"steps": todaySteps});

  final isSleeping = prefs.getBool("is_sleeping") ?? false;
  if (!isSleeping) {
    _updateStepNotification(service: service, steps: todaySteps);
  }
}


// ───────────────────────────────────────────────────────────────────
// 💾 STOP SLEEP AND SAVE — writes to file storage, not Hive
// ───────────────────────────────────────────────────────────────────

/// Clears Dart-side sleep session state so the UI knows the session ended.
///
/// ⚠️  This is now a THIN UI-STATE CLEAR ONLY.
/// All durable work (flush buffers, compute final total, update notification
/// SharedPrefs, queue sleep API) is performed by SleepCalcWorker.kt which
/// fires at the exact wake time — completely independently of the Dart UI.
///
/// This function MUST NOT:
///   • flush sleep_buf.tmp
///   • write flutter.sleep_elapsed_minutes or flutter.sleep_final_minutes
///   • call FileStorageService().addToSyncQueue()
///   • call FileStorageService().flushSleepToDaily()
/// Doing any of those would race against SleepCalcWorker and cause
/// double-queuing or stale data overwriting the Kotlin-computed final total.
Future<void> _stopSleepAndSave(
  ServiceInstance service,
  SharedPreferences prefs,
) async {
  final windowKey    = prefs.getString("current_sleep_window_key");
  final goalMinutes  = prefs.getInt("sleep_goal_minutes") ?? 480;
  final startString  = prefs.getString("sleep_start_time");
  final endString    = prefs.getString("current_sleep_window_end");

  // Relay a best-effort UI update using the last known elapsed minutes.
  // SleepCalcWorker will shortly overwrite flutter.sleep_elapsed_minutes
  // with the true final total; the notification will self-correct on the
  // next 1-min Kotlin tick.
  final lastElapsed = prefs.getInt('sleep_elapsed_minutes') ?? 0;

  // Clear Dart-side session state (UI only)
  await prefs.setBool("is_sleeping", false);
  await prefs.remove("sleep_start_time");
  await prefs.remove("sleep_goal_minutes");
  await prefs.remove("current_sleep_window_start");
  await prefs.remove("current_sleep_window_end");
  await prefs.remove("current_sleep_window_key");

  print("✅ Dart sleep state cleared (SleepCalcWorker owns finalization).");

  // Notify UI so Sleep screen can display a result immediately
  service.invoke("sleep_saved", {
    "duration":     lastElapsed,
    "goal_minutes": goalMinutes,
    "start_time":   startString ?? DateTime.now().toIso8601String(),
    "end_time":     endString   ?? DateTime.now().toIso8601String(),
  });
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
    // The bedtime is more than 5 minutes in the future — candidate: yesterday's window.
    final candidateStart = start.subtract(const Duration(days: 1));
    DateTime candidateEnd = DateTime(
      candidateStart.year,
      candidateStart.month,
      candidateStart.day,
      wakeHour,
      wakeMinute,
    );
    if (!candidateEnd.isAfter(candidateStart)) {
      candidateEnd = candidateEnd.add(const Duration(days: 1));
    }

    if (now.isAfter(candidateEnd)) {
      // Yesterday's window has already ended completley — keep tonight's
      // forward-looking window so we don't start a session for a past window.
      // (start stays as tonight's bedtime; it is in the future.)
    } else {
      start = candidateStart;
    }
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
