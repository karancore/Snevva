import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionRequirement {
  const PermissionRequirement({
    required this.id,
    required this.title,
    required this.description,
    this.permission,
    this.minSdk,
    this.requestable = true,
  });

  final String id;
  final String title;
  final String description;
  final Permission? permission;
  final int? minSdk;
  final bool requestable;

  bool appliesTo(int sdkInt) => minSdk == null || sdkInt >= minSdk!;

  Future<PermissionStatus> checkStatus() async {
    if (permission == null) return PermissionStatus.granted;
    return permission!.status;
  }

  Future<PermissionStatus> request() async {
    if (permission == null) return PermissionStatus.granted;
    return permission!.request();
  }
}

class PermissionManager {
  static const String _prefsDoneKey = 'post_login_permissions_done';
  static const String _prefsTokenKey = 'post_login_permissions_token';

  static bool _sessionHandled = false;
  static int? _cachedAndroidSdk;

  Future<int> _androidSdkInt() async {
    if (!Platform.isAndroid) return 0;
    if (_cachedAndroidSdk != null) return _cachedAndroidSdk!;
    final info = await DeviceInfoPlugin().androidInfo;
    _cachedAndroidSdk = info.version.sdkInt;
    return _cachedAndroidSdk!;
  }

  Future<List<PermissionRequirement>> getRequiredPermissions({
    bool includeBodySensors = true,
  }) async {
    if (!Platform.isAndroid) return const [];

    final sdkInt = await _androidSdkInt();
    final requirements = <PermissionRequirement>[];

    if (sdkInt >= 29) {
      requirements.add(
        const PermissionRequirement(
          id: 'activity_recognition',
          title: 'Activity Recognition',
          description: 'Required to count steps in the background.',
          permission: Permission.activityRecognition,
          minSdk: 29,
        ),
      );
    }

    // if (includeBodySensors) {
    //   requirements.add(
    //     const PermissionRequirement(
    //       id: 'body_sensors',
    //       title: 'Body Sensors',
    //       description: 'Used for sleep insights when available on device.',
    //       permission: Permission.sensors,
    //     ),
    //   );
    // }

    if (sdkInt >= 33) {
      requirements.add(
        const PermissionRequirement(
          id: 'post_notifications',
          title: 'Notifications',
          description:
              'Needed for the foreground service notification on Android 13+.',
          permission: Permission.notification,
          minSdk: 33,
        ),
      );
    }

    if (sdkInt >= 31) {
      requirements.add(
        const PermissionRequirement(
          id: 'schedule_exact_alarm',
          title: 'Exact Alarms',
          description: 'Ensures sleep reminders fire at the right time.',
          permission: Permission.scheduleExactAlarm,
          minSdk: 31,
        ),
      );
    }

    if (sdkInt >= 23) {
      requirements.add(
        const PermissionRequirement(
          id: 'ignore_battery_optimizations',
          title: 'Ignore Battery Optimizations',
          description: 'Prevents Android from pausing step/sleep tracking.',
          permission: Permission.ignoreBatteryOptimizations,
          minSdk: 23,
        ),
      );
    }

    if (sdkInt >= 28) {
      requirements.add(
        const PermissionRequirement(
          id: 'foreground_service',
          title: 'Foreground Service',
          description: 'Keeps tracking alive while the app is closed.',
          minSdk: 28,
          requestable: false,
        ),
      );
    }

    if (sdkInt >= 31) {
      requirements.add(
        const PermissionRequirement(
          id: 'background_execution',
          title: 'Background Execution',
          description: 'Allows continuous tracking on Android 12+.',
          minSdk: 31,
          requestable: false,
        ),
      );
    }

    return requirements
        .where((r) => r.appliesTo(sdkInt))
        .toList(growable: false);
  }

  Future<Map<String, PermissionStatus>> checkStatuses(
    List<PermissionRequirement> requirements,
  ) async {
    final statuses = <String, PermissionStatus>{};
    for (final req in requirements) {
      statuses[req.id] = await req.checkStatus();
    }
    return statuses;
  }

  bool isGranted(PermissionStatus status) {
    return status.isGranted || status.isLimited;
  }

  Future<bool> areAllRequiredGranted(
    List<PermissionRequirement> requirements,
  ) async {
    for (final req in requirements) {
      final status = await req.checkStatus();
      if (!isGranted(status)) return false;
    }
    return true;
  }

  Future<bool> shouldRunPostLoginFlow(SharedPreferences prefs) async {
    if (_sessionHandled) return false;

    final token = prefs.getString('auth_token') ?? '';
    final done = prefs.getBool(_prefsDoneKey) ?? false;
    final lastToken = prefs.getString(_prefsTokenKey) ?? '';

    if (done && lastToken == token) {
      _sessionHandled = true;
      return false;
    }

    return true;
  }

  Future<void> markPostLoginFlowDone(SharedPreferences prefs) async {
    final token = prefs.getString('auth_token') ?? '';
    await prefs.setBool(_prefsDoneKey, true);
    await prefs.setString(_prefsTokenKey, token);
    _sessionHandled = true;
  }
}
