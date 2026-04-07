import 'dart:async';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/models/hive_models/sleep_log_g.dart';
import 'package:snevva/services/health_file_storage_service.dart';
import 'package:snevva/services/hive_service.dart';

import '../common/agent_debug_logger.dart';
import '../consts/consts.dart';
import '../models/hive_models/sleep_log.dart';
import '../models/hive_models/steps_model.dart';
import '../services/sleep/sleep_noticing_service.dart';

// ───────────────────────────────────────────────────────────────────
// Constants
// ───────────────────────────────────────────────────────────────────

const String _lastAutoStartedSleepWindowKey = 'last_auto_started_sleep_window';
const String _manualStoppedWindowKey = 'manually_stopped_window_key';

// Single instance of SleepNoticingService per BG isolate lifetime
final SleepNoticingService _sleepNoticingService = SleepNoticingService();
var sleepHeartbeatInterval = Duration(minutes: 1);
var sleepWindowFreshnessTolerance = Duration(hours: 6);
var sleepWindowLookahead = Duration(minutes: 5);
var sleepWindowDayOffset = Duration(days: 1);

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

    await HiveService().initBackground();
    // Bug 1E fix: Do NOT call Hive.initFlutter() here — HiveService().initBackground()
    // already handles Hive initialization. Calling it twice caused issues on some devices.

    if (!Hive.isAdapterRegistered(SleepLogAdapter().typeId)) {
      Hive.registerAdapter(SleepLogAdapter());
    }
    if (!Hive.isAdapterRegistered(StepEntryAdapter().typeId)) {
      Hive.registerAdapter(StepEntryAdapter());
    }

    debugPrint('📦 Hive ready in BG isolate at ${DateTime.now()}');

    // ── Become a foreground service ──────────────────────────────
    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();
      service.setForegroundNotificationInfo(
        title: 'Snevva Active',
        content: '👟 Steps: 0',
      );
    }

    print("🚀 Unified background service started at ${DateTime.now()}");

    final fileStorage = HealthFileStorageService.instance;
    await fileStorage.ensureInitialized();
    await fileStorage.syncSleepScheduleFromPrefs();

    final sleepBox = await HiveService().sleepLogBox();
    final stepBox = await HiveService().stepHistoryBox();
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    // ── Always-on screen monitoring ───────────────────────────────
    // Start 24/7 screen-off/on recording immediately — BEFORE the session
    // restore logic runs. This ensures no events are lost between service
    // boot and the first heartbeat tick.
    _sleepNoticingService.startMonitoring();
    print("🔍 Always-on sleep monitoring started at ${DateTime.now()}");

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

    // ── Always-on 1-min heartbeat ─────────────────────────────────
    // Drives sleep notification ticks, auto-close at window end, AND
    // nightly auto-start of sleep sessions when the window opens.
    _startHeartbeatTimer(
      service: service,
      prefs: prefs,
      sleepBox: sleepBox,
      stepBox: stepBox,
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

      // Pin the sleep window so the screen monitor and calculator agree.
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

      // Screen monitoring is already running 24/7 — only seed the rolling
      // anchor so a service-restart mid-window doesn't lose early sleep.
      await _sleepNoticingService.initializeForSleepWindow();
      // NOTE: do NOT call startMonitoring() here — it was started at boot.

      final totalSleepMinutes =
          await _sleepNoticingService.getTotalSleepMinutes();

      service.invoke("sleep_update", {
        "elapsed_minutes": totalSleepMinutes,
        "goal_minutes": goalMinutes,
        "is_sleeping": true,
      });

      print("🌙 Sleep tracking started at ${DateTime.now()}");
      print("   Goal: $goalMinutes mins");
      print("   Window: ${sleepWindow?.start} → ${sleepWindow?.end}");

      _updateSleepNotification(
        service: service,
        elapsedMinutes: totalSleepMinutes,
        goalMinutes: goalMinutes,
      );
      // Heartbeat timer already running — no need to restart it.
    });

    // ═══════════════════════════════════════════════════════════════
    // 🌙 SLEEP TRACKING — stop_sleep event
    // ═══════════════════════════════════════════════════════════════

    service.on("stop_sleep").listen((event) async {
      // NOTE: we do NOT stop screen monitoring — it must remain alive for
      // the next night's sleep window even after the current session ends.
      print("⏹️ stop_sleep received at ${DateTime.now()}");
      await _stopSleepAndSave(service, prefs, sleepBox);
    });

    // ═══════════════════════════════════════════════════════════════
    // 👣 STEP COUNTING — onStepDetected event (from native service)
    // ═══════════════════════════════════════════════════════════════

    print("👣 Initializing step counter at ${DateTime.now()}...");

    service.on('onStepDetected').listen((event) async {
      if (event == null) return;

      final int newTotalSteps = event['steps'] as int;

      service.invoke("steps_updated", {"steps": newTotalSteps});

      // Update notification only when NOT in sleep mode
      final isSleeping = prefs.getBool("is_sleeping") ?? false;
      if (!isSleeping) {
        _updateStepNotification(service: service, steps: newTotalSteps);
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
            await _stopSleepAndSave(service, prefs, sleepBox);
          }
        }
      }
    });

    // ═══════════════════════════════════════════════════════════════
    // 🛑 SERVICE STOP
    // ═══════════════════════════════════════════════════════════════

    service.on('stopService').listen((_) {
      print("🛑 Stopping unified background service at ${DateTime.now()}...");
      _sleepProgressTimer?.cancel();
      _sleepProgressTimer = null;
      // Service is truly stopping — stop screen monitoring.
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

// ───────────────────────────────────────────────────────────────────
// 🔔 NOTIFICATION HELPERS — single source of truth
// ───────────────────────────────────────────────────────────────────

/// Update notification with step count (outside sleep window).
void _updateStepNotification({
  required ServiceInstance service,
  required int steps,
}) {
  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: 'Snevva Active',
      content: '👟 Steps: $steps',
    );
  }
}

/// Update notification with sleep progress (inside sleep window).
void _updateSleepNotification({
  required ServiceInstance service,
  required int elapsedMinutes,
  required int goalMinutes,
}) {
  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: 'Snevva Active',
      content: '😴 Sleeping · ${_formatDuration(elapsedMinutes)}',
    );
  }
}

// ───────────────────────────────────────────────────────────────────
// ⏱️ ALWAYS-ON 1-MIN HEARTBEAT TIMER
// ───────────────────────────────────────────────────────────────────

/// Starts a timer that fires every 60 seconds for the lifetime of the
/// background service. On each tick it:
///  • If sleeping  → updates the sleep notification + auto-closes when the
///                   window ends.
///  • If not sleeping → checks whether the sleep window just opened and
///                      auto-starts the session.  This is what makes the
///                      whole week / month of sleep data accumulate without
///                      the user doing anything after setting bedtime once.
void _startHeartbeatTimer({
  required ServiceInstance service,
  required SharedPreferences prefs,
  required Box<SleepLog> sleepBox,
  required Box<StepEntry> stepBox,
}) {
  _sleepProgressTimer?.cancel();
  _sleepProgressTimer = Timer.periodic(sleepHeartbeatInterval, (_) async {
    await prefs.reload();
    final isSleeping = prefs.getBool('is_sleeping') ?? false;

    if (isSleeping) {
      // ── Active sleep: update notification + check window end ──────
      final goalMinutes = prefs.getInt('sleep_goal_minutes') ?? 480;
      final totalSleepMinutes =
          await _sleepNoticingService.getTotalSleepMinutes();
      final windowKey = prefs.getString('current_sleep_window_key');
      final startTime = prefs.getString('sleep_start_time');

      service.invoke('sleep_update', {
        'elapsed_minutes': totalSleepMinutes,
        'goal_minutes': goalMinutes,
        'is_sleeping': true,
        'current_sleep_window_key': windowKey,
        'start_time': startTime,
      });

      _updateSleepNotification(
        service: service,
        elapsedMinutes: totalSleepMinutes,
        goalMinutes: goalMinutes,
      );

      // Auto-close when window has passed
      final windowEndStr = prefs.getString('current_sleep_window_end');
      if (windowEndStr != null) {
        try {
          final windowEnd = DateTime.parse(windowEndStr);
          if (DateTime.now().isAfter(windowEnd)) {
            // NOTE: do NOT stop monitoring here — it must keep running 24/7
            // so the next night's screen events are recorded.
            await _stopSleepAndSave(service, prefs, sleepBox);
          }
        } catch (_) {}
      }
    } else {
      // ── Not sleeping: check if the window just opened (nightly auto-start) ──
      // This is the key to automatic multi-night/week/month data collection:
      // every minute the service re-checks whether now falls inside the user's
      // sleep window and auto-starts if so.
      await _restoreOrAutoStartSleepTracking(
        service: service,
        prefs: prefs,
        sleepBox: sleepBox,
      );
    }
  });
}


// ───────────────────────────────────────────────────────────────────
// 🌙 SLEEP SESSION RESTORE / AUTO-START
// ───────────────────────────────────────────────────────────────────

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
    // Past window end → auto-save and exit sleep mode
    if (sleepWindow != null && nowTime.isAfter(sleepWindow.end)) {
      print("⏰ Service recovery detected window end. Auto-saving sleep...");
      _sleepProgressTimer?.cancel();
      _sleepProgressTimer = null;
      await _stopSleepAndSave(service, prefs, sleepBox);
      return;
    }

    // Resume active sleep session
    // Seed rolling anchor only if not already set (avoids overwriting real data).
    await _sleepNoticingService.initializeForSleepWindow();
    // Screen monitoring already running 24/7 — do NOT call startMonitoring().

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

    _updateSleepNotification(
      service: service,
      elapsedMinutes: totalSleepMinutes,
      goalMinutes: goalMinutes,
    );
    // Heartbeat timer already running — no need to restart.
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
    sleepBox: sleepBox,
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
  required Box<SleepLog> sleepBox,
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

  // Only seed the rolling anchor — monitoring is already running 24/7.
  await _sleepNoticingService.initializeForSleepWindow();
  // NOTE: do NOT call startMonitoring() here.

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

  _updateSleepNotification(
    service: service,
    elapsedMinutes: totalSleepMinutes,
    goalMinutes: goalMinutes,
  );
  // Heartbeat timer already running — no need to restart.
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
  required Box<StepEntry> stepBox,
  bool forceNotify = false,
}) async {
  final nowTime = DateTime.now();
  final todayKey = "${nowTime.year}-${nowTime.month}-${nowTime.day}";
  final lastDate = prefs.getString("last_step_date");

  if (lastDate == todayKey && !forceNotify) return;

  await prefs.setString("last_step_date", todayKey);
  // NOTE: Do NOT remove 'lastRawSteps' — keeps hardware tally correct at midnight.

  final todaySteps = await HealthFileStorageService.instance.readStepCount(
    todayKey,
  );
  service.invoke("steps_updated", {"steps": todaySteps});

  final isSleeping = prefs.getBool("is_sleeping") ?? false;
  if (!isSleeping) {
    _updateStepNotification(service: service, steps: todaySteps);
  }
}

// ───────────────────────────────────────────────────────────────────
// 💾 STOP SLEEP AND SAVE
// ───────────────────────────────────────────────────────────────────

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

  // Calculate sleep minutes: the SleepNoticingService clips the 24h raw
  // buffer to the resolved sleep window, so totalSleepMinutes already
  // respects the window boundaries.
  final totalSleepMinutes = await _sleepNoticingService.getTotalSleepMinutes(
    windowStart:
        windowStartString != null ? DateTime.tryParse(windowStartString) : null,
    windowEnd:
        windowEndString != null ? DateTime.tryParse(windowEndString) : null,
    windowDateKey: windowKey,
  );

  print("💾 Saving sleep data:");
  print("   Start: $effectiveStart");
  print("   End: $effectiveEnd");
  print("   Total sleep: $totalSleepMinutes mins");
  print("   Goal: $goalMinutes mins");

  if (windowKey != null) {
    final logDate = DateTime.tryParse(windowKey) ?? effectiveStart;
    await HealthFileStorageService.instance.writeSleepSummary(
      windowKey,
      durationMinutes: totalSleepMinutes,
      startTime: DateTime(logDate.year, logDate.month, logDate.day),
      endTime: effectiveEnd,
      goalMinutes: goalMinutes,
    );
  }

  // Clear the is_sleeping session state — but leave the raw screen-event
  // buffer intact so the next window calculation (or a late wake detection)
  // can still read it. The buffer is date-keyed and naturally expires.
  await prefs.setBool("is_sleeping", false);
  await prefs.remove("sleep_start_time");
  await prefs.remove("sleep_goal_minutes");
  await prefs.remove("current_sleep_window_start");
  await prefs.remove("current_sleep_window_end");
  await prefs.remove("current_sleep_window_key");

  // Clean up legacy per-window interval keys (old architecture).
  if (windowKey != null) {
    await prefs.remove('sleep_intervals_$windowKey');
    await prefs.remove('last_screen_off_$windowKey');
  }

  print("✅ Sleep data saved successfully");

  // ── Pending upload queue ────────────────────────────────────────────
  // Write the sleep data to SharedPrefs so the main isolate's
  // SleepController can pick it up and call uploadsleepdatatoServer even
  // if no listener was registered at the moment this isolate fires
  // sleep_saved (e.g. the sleep screen was never opened this session).
  await prefs.setString('pending_sleep_upload_start', effectiveStart.toIso8601String());
  await prefs.setString('pending_sleep_upload_end', effectiveEnd.toIso8601String());
  await prefs.setInt('pending_sleep_upload_duration', totalSleepMinutes);
  print('📋 Pending upload queued for main isolate');

  // Notify UI
  service.invoke("sleep_saved", {
    "duration": totalSleepMinutes,
    "goal_minutes": goalMinutes,
    "start_time": effectiveStart.toIso8601String(),
    "end_time": effectiveEnd.toIso8601String(),
  });

  // Restore step notification
  await prefs.reload();
  final steps = await HealthFileStorageService.instance.readStepCount(
    '${DateTime
        .now()
        .year}-${DateTime
        .now()
        .month}-${DateTime
        .now()
        .day}',
  );
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
      final isFreshEnough =
      end.add(sleepWindowFreshnessTolerance).isAfter(nowTime);
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

  // If bedtime is in the future (more than 5 min from now), use yesterday's bedtime
  if (start.isAfter(now.add(sleepWindowLookahead))) {
    start = start.subtract(sleepWindowDayOffset);
  }

  DateTime end = DateTime(
    start.year,
    start.month,
    start.day,
    wakeHour,
    wakeMinute,
  );

  // If wake time is before or equal to bedtime, it's next calendar day
  if (!end.isAfter(start)) {
    end = end.add(sleepWindowDayOffset);
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
