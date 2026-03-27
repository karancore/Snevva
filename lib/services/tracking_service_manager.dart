import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_initializer.dart';

class TrackingServiceManager {
  TrackingServiceManager._();

  static final TrackingServiceManager instance = TrackingServiceManager._();
  static const MethodChannel _stepServiceChannel = MethodChannel(
    'com.coretegra.snevva/step_service',
  );

  Future<void> start() async {
    await createServiceNotificationChannel();
    await _startNativeStepServiceIfNeeded();
    await initBackgroundService();
  }

  Future<void> _startNativeStepServiceIfNeeded() async {
    if (!Platform.isAndroid) return;

    try {
      await _stepServiceChannel.invokeMethod<bool>('startStepService');
    } on PlatformException catch (error) {
      debugPrint(
        'Failed to start native step service after permissions were granted: $error',
      );
    }
  }
}
