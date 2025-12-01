import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:pedometer/pedometer.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart';
import 'package:timezone/data/latest.dart';

import '../models/steps_model.dart';

/// Background entry point for pedometer service
@pragma("vm:entry-point")
Future<bool> backgroundEntry(ServiceInstance service) async {
  try {
    // Initialize Dart plugins FIRST
    DartPluginRegistrant.ensureInitialized();
    
    // CRITICAL: Set foreground notification IMMEDIATELY on Android
    // This MUST happen before any other async operations to prevent
    // ForegroundServiceDidNotStartInTimeException
    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();
      service.setForegroundNotificationInfo(
        title: "Step Tracking",
        content: "Tracking your steps in the background",
      );
    }

    // Timezone setup
    initializeTimeZones();

    // SharedPreferences
    final prefs = await SharedPreferences.getInstance();

    // Hive setup
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(StepEntryAdapter().typeId)) {
      Hive.registerAdapter(StepEntryAdapter());
    }
    final box = await Hive.openBox<StepEntry>("step_history");

    // Track last step count to calculate diff
    int? lastRawSteps;

    // Listen to pedometer updates
    Pedometer.stepCountStream.listen(
      (StepCount event) async {
        try {
          final int raw = event.steps;
          final now = TZDateTime.now(local);
          final todayKey = "${now.year}-${now.month}-${now.day}";

          StepEntry? todayEntry = box.get(todayKey);

          if (lastRawSteps == null) {
            lastRawSteps = raw;
            return;
          }

          int diff = raw - lastRawSteps!;
          if (diff < 0) diff = 0;

          final newSteps = (todayEntry?.steps ?? 0) + diff;

          // Save in Hive
          await box.put(
            todayKey,
            StepEntry(date: now, steps: newSteps),
          );

          // Save in SharedPreferences
          await prefs.setInt("todaySteps", newSteps);

          print("📌 BG STEPS UPDATED: $newSteps");

          lastRawSteps = raw;
        } catch (e) {
          print("❌ Error in pedometer listener: $e");
        }
      },
      onError: (error) {
        print("❌ Pedometer stream error: $error");
      },
    );

    return true;
  } catch (e) {
    print("❌ Error in backgroundEntry: $e");
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
