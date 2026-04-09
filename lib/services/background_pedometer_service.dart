import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

@pragma("vm:entry-point")
Future<bool> backgroundEntry(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  debugPrint("Legacy background pedometer entry invoked; native step service is now the source of truth.");
  return true;
}

Future<void> stopBackgroundService() async {
  final service = FlutterBackgroundService();
  final isRunning = await service.isRunning();
  if (!isRunning) {
    debugPrint("Legacy background pedometer service not running");
    return;
  }

  debugPrint("Sending stop signal to legacy background pedometer service");
  service.invoke('stopService');
}
