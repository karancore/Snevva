import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:pedometer/pedometer.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:screen_state/screen_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/steps_model.dart';
import '../models/sleep_log.dart';

// Global references for step counting
StreamSubscription<StepCount>? _pedometerSubscription;

// Global references for sleep tracking
StreamSubscription<ScreenStateEvent>? _screenStateSubscription;
DateTime? _sleepStartTime;
DateTime? _usageStartTime;
bool _isUserUsingPhone = false;

@pragma("vm:entry-point")
Future<bool> unifiedBackgroundEntry(ServiceInstance service) async {
  try {
    DartPluginRegistrant.ensureInitialized();

    // Foreground service (Android)
    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();
      service.setForegroundNotificationInfo(
        title: "Health Tracking",
        content: "Monitoring steps & sleep...",
      );
    }

    print("🚀 Unified background service started");

    // Init Hive
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(StepEntryAdapter().typeId)) {
      Hive.registerAdapter(StepEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(SleepLogAdapter().typeId)) {
      Hive.registerAdapter(SleepLogAdapter());
    }

    final stepBox = await Hive.openBox<StepEntry>('step_history');
    final sleepBox = await Hive.openBox<SleepLog>('sleep_log');

    // SharedPrefs
    final prefs = await SharedPreferences.getInstance();

    // ════════════════════════════════════════════════════
    // 1️⃣ STEP COUNTING SETUP
    // ════════════════════════════════════════════════════
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
        // Also persist a simple shared preference value so main isolate can detect updates
        await prefs.setInt('today_steps', newSteps);
        await prefs.setInt('lastRawSteps', event.steps);

        service.invoke("steps_updated", {"steps": newSteps});

        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "Health Tracking",
            content: "$newSteps steps & sleep tracking",
          );
        }

        print("👣 Steps: $newSteps (diff: $diff)");
      },
      onError: (error) {
        print("❌ Pedometer error: $error");
      },
    );

    // ════════════════════════════════════════════════════
    // 2️⃣ SLEEP TRACKING SETUP
    // ════════════════════════════════════════════════════
    print("😴 Initializing sleep monitor...");

    final screen = Screen();

    // Cancel any existing subscription
    await _screenStateSubscription?.cancel();

    // Listen to screen state changes
    _screenStateSubscription = screen.screenStateStream?.listen((event) {
      _handleScreenStateChange(event, service, sleepBox, prefs);
    });

    // ════════════════════════════════════════════════════
    // 3️⃣ SERVICE STOP LISTENER
    // ════════════════════════════════════════════════════
    service.on('stopService').listen((_) {
      print("🛑 Stopping unified background service...");
      _pedometerSubscription?.cancel();
      _screenStateSubscription?.cancel();
      _sleepStartTime = null;
      _usageStartTime = null;
      service.stopSelf();
    });

    print("✅ Unified background service fully initialized");
    return true;
  } catch (e) {
    print("❌ Unified background service failed: $e");
    return false;
  }
}

void _handleScreenStateChange(
  ScreenStateEvent event,
  ServiceInstance service,
  Box<SleepLog> sleepBox,
  SharedPreferences prefs,
) async {
  final now = DateTime.now();

  if (event == ScreenStateEvent.SCREEN_ON) {
    print("☀️ [BG] Screen ON at ${now.hour}:${now.minute}");

    // CASE 1: Waking from sleep
    if (_sleepStartTime != null && !_isUserUsingPhone) {
      final sleepDuration = now.difference(_sleepStartTime!);
      print("😴 [BG] Woke up! Sleep duration: ${sleepDuration.inMinutes} mins");

      // Save sleep log to Hive
      final todayKey = "${now.year}-${now.month}-${now.day}";
      final sleepLog = SleepLog(
        date: _sleepStartTime!,
        durationMinutes: sleepDuration.inMinutes,
      );

      await sleepBox.put(todayKey, sleepLog);

      // Notify UI
      service.invoke("sleep_updated", {
        "sleep_duration_minutes": sleepDuration.inMinutes,
        "bedtime": _sleepStartTime?.toString(),
        "waketime": now.toString(),
      });

      _sleepStartTime = null;
      _isUserUsingPhone = true;
      return;
    }

    // CASE 2: Normal phone usage resumed
    _usageStartTime = now;
    _isUserUsingPhone = true;
    print("📱 [BG] Phone usage started");
  } else if (event == ScreenStateEvent.SCREEN_OFF) {
    print("🌙 [BG] Screen OFF at ${now.hour}:${now.minute}");

    // CASE 1: No usage start time → phone was idle, now sleeping
    if (_usageStartTime == null) {
      _sleepStartTime = now;
      _isUserUsingPhone = false;
      print("😴 [BG] Sleep likely started");
      return;
    }

    // CASE 2: Had usage time → phone is being put away
    if (_isUserUsingPhone) {
      final usageDuration = now.difference(_usageStartTime!);
      print("📵 [BG] Phone put away. Usage: ${usageDuration.inMinutes} mins");

      _sleepStartTime = now;
      _isUserUsingPhone = false;
    }
  }
}
