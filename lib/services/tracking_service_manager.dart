import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_initializer.dart';

class TrackingServiceManager {
  TrackingServiceManager._();

  static final TrackingServiceManager instance = TrackingServiceManager._();
  static const MethodChannel _stepServiceChannel = MethodChannel(
    'com.coretegra.snevvaa/step_service',
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

  /// Seeds the native StepCounterService with an existing step count fetched
  /// from the API at login time (e.g. the user reinstalled and already had 644
  /// steps on the server for today).
  ///
  /// Only updates if [steps] > the current native counter, so it can never go
  /// backward. Also triggers an immediate notification refresh so the user sees
  /// the correct count right away instead of having to take a step first.
  Future<void> seedTodaySteps(int steps) async {
    if (!Platform.isAndroid || steps <= 0) return;

    try {
      await _stepServiceChannel.invokeMethod<bool>('seedTodaySteps', steps);
      debugPrint('🌱 seedTodaySteps($steps) sent to native');
    } on PlatformException catch (e) {
      debugPrint('⚠️ seedTodaySteps failed: $e');
    }
  }

  /// Stops the native StepCounterService foreground service and removes the
  /// persistent notification. Call this on logout so the sticky notification
  /// disappears when the user is signed out.
  Future<void> stopNativeStepService() async {
    if (!Platform.isAndroid) return;

    try {
      await _stepServiceChannel.invokeMethod<bool>('stopStepService');
      debugPrint('🛑 stopNativeStepService: foreground service stopped');
    } on PlatformException catch (e) {
      debugPrint('⚠️ stopNativeStepService failed: $e');
    }
  }

  /// Sends a REFRESH_NOTIFICATION intent to the native StepCounterService so
  /// the sticky notification re-reads steps + sleep from SharedPreferences and
  /// updates immediately (instead of waiting up to 60 s for the 1-min ticker).
  /// Call this after seeding sleep data into FlutterSharedPreferences at login.
  Future<void> refreshStickyNotification() async {
    if (!Platform.isAndroid) return;

    try {
      await _stepServiceChannel.invokeMethod<bool>('refreshNotification');
      debugPrint('🔔 refreshStickyNotification sent');
    } on PlatformException catch (e) {
      debugPrint('⚠️ refreshStickyNotification failed: $e');
    }
  }
}
