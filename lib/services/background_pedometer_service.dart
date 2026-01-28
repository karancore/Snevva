import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:pedometer/pedometer.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../common/global_variables.dart';
import '../models/hive_models/steps_model.dart';

// Global reference to the pedometer stream subscription
StreamSubscription<StepCount>? _pedometerSubscription;

@pragma("vm:entry-point")
Future<bool> backgroundEntry(ServiceInstance service) async {
  try {
    DartPluginRegistrant.ensureInitialized();

    // Foreground service (Android)
    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();
      service.setForegroundNotificationInfo(
        title: "Step Tracking",
        content: "Tracking your steps in background",
      );
    }

    final box = Hive.box<StepEntry>('step_history');

    // SharedPrefs (ONCE)
    final prefs = await SharedPreferences.getInstance();

    // Check for day reset

    final todayKey = "${now.year}-${now.month}-${now.day}";
    final lastDate = prefs.getString("last_step_date");

    if (lastDate != todayKey) {
      // New day - reset everything
      await prefs.setString("last_step_date", todayKey);
      await prefs.remove('lastRawSteps'); // Clear last raw steps for new day
      await box.put(todayKey, StepEntry(date: now, steps: 0));

      // Notify UI of reset
      service.invoke("steps_updated", {"steps": 0});
    }

    // Cancel any existing pedometer subscription before starting a new one
    await _pedometerSubscription?.cancel();

    // Listen to pedometer
    _pedometerSubscription = Pedometer.stepCountStream.listen(
      (StepCount event) async {

        final todayKey = "${now.year}-${now.month}-${now.day}";

        // Get last raw step count
        final lastRawSteps = prefs.getInt('lastRawSteps') ?? event.steps;

        // Calculate difference
        int diff = event.steps - lastRawSteps;

        // Handle pedometer reset (device reboot or app restart)
        if (diff < 0) {
          diff = event.steps; // Use current steps as delta
        }

        // Get current stored steps for today
        final todayEntry = box.get(todayKey);
        final currentSteps = todayEntry?.steps ?? 0;
        final newSteps = currentSteps + diff;

        // Save to Hive
        await box.put(todayKey, StepEntry(date: now, steps: newSteps));

        // Also persist a simple shared preference value so main isolate can detect updates
        await prefs.setInt('today_steps', newSteps);

        // Update last raw steps
        await prefs.setInt('lastRawSteps', event.steps);

        // 🔥 Emit event to UI
        service.invoke("steps_updated", {"steps": newSteps});

        // Update notification
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "Step Tracking",
            content: "$newSteps steps today",
          );
        }

        print("👣 Steps updated → $newSteps (diff: $diff)");
      },
      onError: (error) {
        print("❌ Pedometer error: $error");
      },
    );

    // Listen for service stop and cancel pedometer stream
    service.on('stopService').listen((_) {
      print("🛑 Stopping background service...");
      _pedometerSubscription?.cancel();
      service.stopSelf();
    });

    return true;
  } catch (e) {
    print("❌ Background service failed: $e");
    return false;
  }
}

/// Initialize the background service
Future<void> initBackgroundService() async {
  final service = FlutterBackgroundService();

  // Check if service is already running
  final isRunning = await service.isRunning();
  if (isRunning) {
    print("⚠️ Background service already running, skipping initialization");
    return;
  }

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: backgroundEntry,
      isForegroundMode: true,
      autoStart: true,
      autoStartOnBoot: true,
      notificationChannelId: "flutter_background_service",
      initialNotificationTitle: "Step Tracking",
      initialNotificationContent: "Tracking steps in background...",
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: backgroundEntry,
      onBackground: backgroundEntry,
    ),
  );

  try {
    await service.startService();
    print("✅ Background service started successfully");
  } catch (e) {
    print("❌ Failed to start background service: $e");
  }
}
