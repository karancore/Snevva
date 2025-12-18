import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:pedometer/pedometer.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/steps_model.dart';

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

    // Init Hive
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(StepEntryAdapter().typeId)) {
      Hive.registerAdapter(StepEntryAdapter());
    }
    final box = await Hive.openBox<StepEntry>('step_history');

    // SharedPrefs (ONCE)
    final prefs = await SharedPreferences.getInstance();

    // Listen to pedometer
    Pedometer.stepCountStream.listen(
      (StepCount event) async {
        final now = DateTime.now();
        final todayKey = "${now.year}-${now.month}-${now.day}";

        // Load last raw steps
        final lastRawSteps = prefs.getInt('lastRawSteps') ?? event.steps;

        int diff = event.steps - lastRawSteps;
        if (diff < 0) diff = 0;

        final todayEntry = box.get(todayKey);
        final newSteps = (todayEntry?.steps ?? 0) + diff;

        // Save
        await box.put(todayKey, StepEntry(date: now, steps: newSteps));

        await prefs.setInt('todaySteps', newSteps);
        await prefs.setInt('lastRawSteps', event.steps);

        print("👣 Steps updated → $newSteps");
      },
      onError: (e) {
        print("❌ Pedometer error: $e");
      },
    );

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
