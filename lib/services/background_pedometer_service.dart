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
  // MUST be the first thing on Android
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();

    // Synchronously set the notification
    service.setForegroundNotificationInfo(
      title: "Step Tracking",
      content: "Tracking your steps in the background",
    );
  }

  // Initialize Dart plugins
  DartPluginRegistrant.ensureInitialized();

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
  Pedometer.stepCountStream.listen((StepCount event) async {
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
  });

  return true; // ✅ important: must return a bool
}

/// Initialize the background service
Future<void> initBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: backgroundEntry,
      isForegroundMode: true,
      autoStart: true,
      autoStartOnBoot: true,
      initialNotificationTitle: "Step Tracking",
      initialNotificationContent: "Tracking steps in background...",
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: backgroundEntry,
      onBackground: backgroundEntry,
    ),
  );

  await service.startService();
}
