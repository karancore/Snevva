import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/services/file_storage_service.dart';

import '../common/global_variables.dart';
import '../consts/consts.dart';

// Global reference to the pedometer stream subscription
StreamSubscription<StepCount>? _pedometerSubscription;

@pragma("vm:entry-point")
Future<bool> backgroundEntry(ServiceInstance service) async {
  try {
    DartPluginRegistrant.ensureInitialized();

    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();
      // NOTE: Notification content is managed by the native StepCounterService (Kotlin).
      // Do NOT call setForegroundNotificationInfo here.
    }

    // File-based storage — no Hive init needed in this isolate
    final fileStorage = FileStorageService();

    final prefs = await SharedPreferences.getInstance();

    final todayKey = "${now.year}-${now.month}-${now.day}";
    final lastDate = prefs.getString("last_step_date");

    if (lastDate != todayKey) {
      await prefs.setString("last_step_date", todayKey);
      await prefs.remove('lastRawSteps');
      await prefs.setInt('today_steps', 0);
      service.invoke("steps_updated", {"steps": 0});
    }

    await _pedometerSubscription?.cancel();

    _pedometerSubscription = Pedometer.stepCountStream.listen(
      (StepCount event) async {
        final lastRawSteps = prefs.getInt('lastRawSteps') ?? event.steps;

        int diff = event.steps - lastRawSteps;
        if (diff < 0) diff = event.steps;

        final currentSteps = prefs.getInt('today_steps') ?? 0;
        final newSteps = currentSteps + diff;

        // Append to file buffer (O(1), no read)
        await fileStorage.appendStepEvent(newSteps);

        await prefs.setInt('today_steps', newSteps);
        await prefs.setInt('lastRawSteps', event.steps);

        service.invoke("steps_updated", {"steps": newSteps});

        // Notification is owned by native StepCounterService — no call here.

        debugPrint("👣 Steps updated → $newSteps (diff: $diff)");
      },
      onError: (error) {
        debugPrint("❌ Pedometer error: $error");
      },
    );

    service.on('stopService').listen((_) async {
      debugPrint("🛑 Stopping background service...");
      _pedometerSubscription?.cancel();
      // Flush buffer before stopping so no data is lost
      await fileStorage.flushStepsToDaily();
      service.stopSelf();
    });

    return true;
  } catch (e) {
    debugPrint("❌ Background service failed: $e");
    return false;
  }
}

Future<void> stopBackgroundService() async {
  final service = FlutterBackgroundService();
  final isRunning = await service.isRunning();
  if (!isRunning) {
    debugPrint("ℹ️ Background service not running");
    return;
  }
  debugPrint("🛑 Sending stop signal to background service");
  service.invoke('stopService');
  await Future.delayed(const Duration(milliseconds: 300));
}
