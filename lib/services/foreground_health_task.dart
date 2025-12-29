// import 'dart:isolate';
// import 'dart:ui';
// import 'package:pedometer/pedometer.dart';
// import 'package:hive_flutter/hive_flutter.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// import '../models/steps_model.dart';
//
// @pragma('vm:entry-point')
// void foregroundHealthTaskStart() async {
//   DartPluginRegistrant.ensureInitialized();
//
//   // Init Hive (foreground isolate)
//   await Hive.initFlutter();
//   if (!Hive.isAdapterRegistered(StepEntryAdapter().typeId)) {
//     Hive.registerAdapter(StepEntryAdapter());
//   }
//   final box = await Hive.openBox<StepEntry>('step_history');
//   final prefs = await SharedPreferences.getInstance();
//
//   int lastRawSteps = prefs.getInt('lastRawSteps') ?? 0;
//
//   Pedometer.stepCountStream.listen((event) async {
//     final now = DateTime.now();
//     final todayKey = "${now.year}-${now.month}-${now.day}";
//
//     int diff = event.steps - lastRawSteps;
//     if (diff < 0) diff = event.steps;
//
//     final current = box.get(todayKey)?.steps ?? 0;
//     final updated = current + diff;
//
//     await box.put(todayKey, StepEntry(date: now, steps: updated));
//     await prefs.setInt('lastRawSteps', event.steps);
//
//     lastRawSteps = event.steps;
//
//     // 🔥 Send to UI isolate
//     FlutterForegroundTask.sendDataToMain({
//       "type": "steps",
//       "value": updated,
//     });
//   });
// }
