import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:pedometer/pedometer.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:screen_state/screen_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../common/global_variables.dart';
import '../consts/consts.dart';
import '../models/hive_models/sleep_log.dart';
import '../models/hive_models/steps_model.dart';
import '../common/agent_debug_logger.dart';


// Global references for step counting
StreamSubscription<StepCount>? _pedometerSubscription;

// Global references for sleep tracking
StreamSubscription<ScreenStateEvent>? _screenStateSubscription;
DateTime? _sleepStartTime;
DateTime? _usageStartTime;
bool _isUserUsingPhone = false;
DateTime? _currentScreenOffStart; // Track when screen turned OFF
List<Map<String, String>> _sleepIntervals = []; // Store sleep intervals as ISO strings

@pragma("vm:entry-point")
Future<bool> unifiedBackgroundEntry(ServiceInstance service) async {
  try {
    DartPluginRegistrant.ensureInitialized();

    debugPrint('🧵 BG isolate started');

    // #region agent log
    AgentDebugLogger.log(
      runId: 'auth-bg',
      hypothesisId: 'B',
      location: 'unified_background_service.dart:unifiedBackgroundEntry:start',
      message: 'Unified background entry started',
      data: const {},
    );
    // #endregion

    // 🔥 REQUIRED: init Hive for THIS isolate
    await Hive.initFlutter();

    // 🔥 REQUIRED: register adapters AGAIN
    if (!Hive.isAdapterRegistered(SleepLogAdapter().typeId)) {
      Hive.registerAdapter(SleepLogAdapter());
    }

    // 🔥 REQUIRED: open boxes AGAIN
    final sleepBox = await Hive.openBox<SleepLog>('sleep_log');

    debugPrint('📦 Hive ready in BG isolate');

    // ⚠️ REMOVED: save_sleep listener - SleepController is the single source of truth
    // Sleep logs should only be saved by SleepController at configured wake time,
    // not by background services on screen events or service invocations.

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

    // SharedPrefs
    final prefs = await SharedPreferences.getInstance();

    // ════════════════════════════════════════════════════
    // 1️⃣ STEP COUNTING SETUP
    // ════════════════════════════════════════════════════
    print("👣 Initializing step counter...");

    // Check for day reset (steps)

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

      // #region agent log
      AgentDebugLogger.log(
        runId: 'auth-bg',
        hypothesisId: 'C',
        location: 'unified_background_service.dart:stopService:listener',
        message: 'Received stopService in background isolate',
        data: const {},
      );
      // #endregion

      _pedometerSubscription?.cancel();
      _screenStateSubscription?.cancel();
      _sleepStartTime = null;
      _usageStartTime = null;
      _currentScreenOffStart = null;
      _sleepIntervals.clear();
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
  // Get bedtime and wakeup time from SharedPreferences
  final bedtimeMinutes = prefs.getInt('user_bedtime_ms');
  final waketimeMinutes = prefs.getInt('user_waketime_ms');
  
  if (bedtimeMinutes == null || waketimeMinutes == null) {
    // Bedtime/waketime not set, use old behavior
    _handleScreenStateChangeLegacy(event, service, sleepBox, prefs);
    return;
  }

  // Convert minutes to TimeOfDay
  final bedtimeHour = bedtimeMinutes ~/ 60;
  final bedtimeMin = bedtimeMinutes % 60;
  final waketimeHour = waketimeMinutes ~/ 60;
  final waketimeMin = waketimeMinutes % 60;

  // Calculate bedtime and wakeup DateTime for today
  DateTime bedtimeToday = DateTime(now.year, now.month, now.day, bedtimeHour, bedtimeMin);
  DateTime waketimeToday = DateTime(now.year, now.month, now.day, waketimeHour, waketimeMin);
  
  // If wakeup time is before bedtime, wakeup is next day
  if (waketimeToday.isBefore(bedtimeToday) || waketimeToday.isAtSameMomentAs(bedtimeToday)) {
    waketimeToday = waketimeToday.add(const Duration(days: 1));
  }
  
  // If bedtime is in the future (more than 1 hour), it's from yesterday
  if (bedtimeToday.isAfter(now.add(const Duration(hours: 1)))) {
    bedtimeToday = bedtimeToday.subtract(const Duration(days: 1));
    waketimeToday = waketimeToday.subtract(const Duration(days: 1));
  }

  if (event == ScreenStateEvent.SCREEN_ON) {
    print("☀️ [BG] Screen ON at ${now.hour}:${now.minute}");

    // If screen was OFF and now ON, end the sleep interval if within sleep window
    if (_currentScreenOffStart != null) {
      // Check if the screen OFF period was within the sleep window
      final screenOffStart = _currentScreenOffStart!;
      final screenOnTime = now;
      
      // Clamp times to sleep window boundaries
      final clampedStart = screenOffStart.isBefore(bedtimeToday) ? bedtimeToday : screenOffStart;
      final clampedEnd = screenOnTime.isAfter(waketimeToday) ? waketimeToday : screenOnTime;
      
      // Only record if the interval is within or overlaps the sleep window
      if (clampedStart.isBefore(clampedEnd) && 
          clampedStart.isBefore(waketimeToday) && 
          clampedEnd.isAfter(bedtimeToday)) {
        // Load existing intervals
        final sleepDateKey = _getSleepDateKey(bedtimeToday);
        final existingIntervals = prefs.getString('sleep_intervals_$sleepDateKey');
        if (existingIntervals != null && existingIntervals.isNotEmpty) {
          final intervalStrings = existingIntervals.split(',');
          _sleepIntervals = intervalStrings.map((s) {
            final parts = s.split('|');
            return {'start': parts[0], 'end': parts[1]};
          }).toList();
        } else {
          _sleepIntervals = [];
        }
        
        final interval = {
          'start': clampedStart.toIso8601String(),
          'end': clampedEnd.toIso8601String(),
        };
        _sleepIntervals.add(interval);
        
        // Save to SharedPreferences
        final intervalsJson = _sleepIntervals.map((i) => '${i['start']}|${i['end']}').join(',');
        await prefs.setString('sleep_intervals_$sleepDateKey', intervalsJson);
        
        print("💤 [BG] Recorded sleep interval: ${clampedStart.hour}:${clampedStart.minute} - ${clampedEnd.hour}:${clampedEnd.minute}");
      }
      
      _currentScreenOffStart = null;
    }

    // Update usage state
    if (_sleepStartTime != null && !_isUserUsingPhone) {
      _sleepStartTime = null;
      _isUserUsingPhone = true;
    }

    _usageStartTime = now;
    _isUserUsingPhone = true;
    print("📱 [BG] Phone usage started");
    
  } else if (event == ScreenStateEvent.SCREEN_OFF) {
    print("🌙 [BG] Screen OFF at ${now.hour}:${now.minute}");

    // Only track if we're within the sleep window
    if (now.isAfter(bedtimeToday.subtract(const Duration(minutes: 30))) && 
        now.isBefore(waketimeToday.add(const Duration(minutes: 30)))) {
      _currentScreenOffStart = now;
      
      // Store last screen OFF time for closing intervals at wakeup
      final sleepDateKey = _getSleepDateKey(bedtimeToday);
      await prefs.setString('last_screen_off_$sleepDateKey', now.toIso8601String());
      
      print("😴 [BG] Screen OFF recorded, sleep tracking active");
    }

    // Legacy state tracking
    if (_usageStartTime == null) {
      _sleepStartTime = now;
      _isUserUsingPhone = false;
      return;
    }

    if (_isUserUsingPhone) {
      final usageDuration = now.difference(_usageStartTime!);
      print("📵 [BG] Phone put away. Usage: ${usageDuration.inMinutes} mins");
      _sleepStartTime = now;
      _isUserUsingPhone = false;
    }
  }
}

// Helper function to get sleep date key (based on bedtime date)
String _getSleepDateKey(DateTime bedtime) {
  return "${bedtime.year}-${bedtime.month.toString().padLeft(2, '0')}-${bedtime.day.toString().padLeft(2, '0')}";
}

// Legacy handler for when bedtime/waketime is not set
void _handleScreenStateChangeLegacy(
  ScreenStateEvent event,
  ServiceInstance service,
  Box<SleepLog> sleepBox,
  SharedPreferences prefs,
) {
  if (event == ScreenStateEvent.SCREEN_ON) {
    print("☀️ [BG] Screen ON at ${now.hour}:${now.minute}");

    if (_sleepStartTime != null && !_isUserUsingPhone) {
      _sleepStartTime = null;
      _isUserUsingPhone = true;
    }

    _usageStartTime = now;
    _isUserUsingPhone = true;
    print("📱 [BG] Phone usage started");
  } else if (event == ScreenStateEvent.SCREEN_OFF) {
    print("🌙 [BG] Screen OFF at ${now.hour}:${now.minute}");

    if (_usageStartTime == null) {
      _sleepStartTime = now;
      _isUserUsingPhone = false;
      print("😴 [BG] Sleep likely started");
      return;
    }

    if (_isUserUsingPhone) {
      final usageDuration = now.difference(_usageStartTime!);
      print("📵 [BG] Phone put away. Usage: ${usageDuration.inMinutes} mins");
      _sleepStartTime = now;
      _isUserUsingPhone = false;
    }
  }
}
