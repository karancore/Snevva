import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class TrackingServiceManager {
  TrackingServiceManager._();

  static final TrackingServiceManager instance = TrackingServiceManager._();
  static const MethodChannel _stepServiceChannel = MethodChannel(
    'com.coretegra.snevva/step_counter_channel',
  );

  Future<void> start() async {
    await startStepService();
  }

  Future<void> startStepService() async {
    if (!Platform.isAndroid) return;

    try {
      await _stepServiceChannel.invokeMethod<bool>('startStepService');
    } on PlatformException catch (error) {
      debugPrint(
        'Failed to start native step service after permissions were granted: $error',
      );
    }
  }

  Future<int> getTodaySteps() async {
    if (!Platform.isAndroid) return 0;

    try {
      final result = await _stepServiceChannel.invokeMethod<int>('getTodaySteps');
      return result ?? 0;
    } on PlatformException catch (error) {
      debugPrint('Failed to fetch today steps from native service: $error');
      return 0;
    }
  }
}
