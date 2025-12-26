import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:screen_state/screen_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sleep_log.dart';

// Global reference to the screen state stream subscription
StreamSubscription<ScreenStateEvent>? _screenStateSubscription;

// Global references for sleep tracking state
DateTime? _sleepStartTime;
DateTime? _usageStartTime;
bool _isUserUsingPhone = false;

@pragma("vm:entry-point")
Future<bool> backgroundSleepEntry(ServiceInstance service) async {
  try {
    // Initialize plugins
    final screen = Screen();

    // Init Hive (safe to call multiple times)
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(SleepLogAdapter().typeId)) {
      Hive.registerAdapter(SleepLogAdapter());
    }
    final box = await Hive.openBox<SleepLog>('sleep_log');

    // SharedPrefs
    final prefs = await SharedPreferences.getInstance();

    print("🌙 Background sleep monitoring initialized");

    // Cancel any existing subscription
    await _screenStateSubscription?.cancel();

    // Listen to screen state changes
    _screenStateSubscription = screen.screenStateStream?.listen((event) {
      _handleScreenStateChange(event, service, box, prefs);
    });

    // Listen for service stop and cancel screen state listener
    service.on('stopService').listen((_) {
      print("🛑 Stopping background sleep service...");
      _screenStateSubscription?.cancel();
      _sleepStartTime = null;
      _usageStartTime = null;
      service.stopSelf();
    });

    return true;
  } catch (e) {
    print("❌ Background sleep service failed: $e");
    return false;
  }
}

void _handleScreenStateChange(
  ScreenStateEvent event,
  ServiceInstance service,
  Box<SleepLog> box,
  SharedPreferences prefs,
) async {
  final now = DateTime.now();

  if (event == ScreenStateEvent.SCREEN_ON) {
    // Screen turned ON
    print("☀️ [BG Sleep] Screen ON at ${now.hour}:${now.minute}");

    // CASE 1: Waking from sleep
    if (_sleepStartTime != null && !_isUserUsingPhone) {
      final sleepDuration = now.difference(_sleepStartTime!);
      print(
        "😴 [BG Sleep] Woke up! Sleep duration: ${sleepDuration.inMinutes} mins",
      );

      // Save sleep log to Hive
      final todayKey = "${now.year}-${now.month}-${now.day}";
      final sleepLog = SleepLog(
        date: _sleepStartTime!,
        durationMinutes: sleepDuration.inMinutes,
      );

      await box.put(todayKey, sleepLog);

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
    print("📱 [BG Sleep] Phone usage started at ${now.hour}:${now.minute}");
  } else if (event == ScreenStateEvent.SCREEN_OFF) {
    // Screen turned OFF
    print("🌙 [BG Sleep] Screen OFF at ${now.hour}:${now.minute}");

    // CASE 1: No usage start time → phone was idle, now sleeping
    if (_usageStartTime == null) {
      _sleepStartTime = now;
      _isUserUsingPhone = false;
      print("😴 [BG Sleep] Sleep likely started at ${now.hour}:${now.minute}");
      return;
    }

    // CASE 2: Had usage time → phone is being put away
    if (_isUserUsingPhone) {
      final usageDuration = now.difference(_usageStartTime!);
      print(
        "📵 [BG Sleep] Phone usage ended. Duration: ${usageDuration.inMinutes} mins",
      );

      // Could log usage if needed
      _sleepStartTime = now;
      _isUserUsingPhone = false;
    }
  }
}
