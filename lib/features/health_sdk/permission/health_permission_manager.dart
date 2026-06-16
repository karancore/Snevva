import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

enum HealthPermissionStatus {
  granted,
  denied,
  // Health Connect not installed / HealthKit not available on device
  unavailable,
  unknown,
}

enum AndroidHealthConnectStatus {
  available,
  // Installed but needs an update
  updateRequired,
  notInstalled,
}

/// Manages platform-specific health permission flows.
///
/// iOS  → HealthKit (authorization sheet shown once; subsequent calls are
///         silently no-ops so we treat unknown as "may be granted").
/// Android → Health Connect (rationale activity → permission picker).
class HealthPermissionManager {
  HealthPermissionManager._();

  static final Health _health = Health();

  // Vitals types supported on both platforms.
  static const List<HealthDataType> _vitalsTypes = [
    HealthDataType.HEART_RATE,
    HealthDataType.BLOOD_GLUCOSE,
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
  ];

  // Sleep types differ by platform.
  // iOS:     SLEEP_IN_BED is the primary bucket; DEEP/LIGHT/REM are iOS 16+ stages.
  // Android: SLEEP_SESSION is the Health Connect container; DEEP/LIGHT/REM are stages inside it.
  static List<HealthDataType> get _sleepTypes {
    if (Platform.isAndroid) {
      return [
        HealthDataType.SLEEP_SESSION,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_AWAKE,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_LIGHT,
        HealthDataType.SLEEP_REM,
      ];
    }
    return [
      HealthDataType.SLEEP_IN_BED,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_AWAKE,
      HealthDataType.SLEEP_DEEP,
      HealthDataType.SLEEP_LIGHT,
      HealthDataType.SLEEP_REM,
    ];
  }

  static List<HealthDataType> get _dataTypes => [
        ..._vitalsTypes,
        ..._sleepTypes,
      ];

  static List<HealthDataAccess> get _readOnly =>
      List.filled(_dataTypes.length, HealthDataAccess.READ);

  // ─── Android Health Connect ──────────────────────────────────────────────

  static Future<AndroidHealthConnectStatus> checkHealthConnectStatus() async {
    if (!Platform.isAndroid) return AndroidHealthConnectStatus.available;

    try {
      // getHealthConnectSdkStatus() returns HealthConnectSdkStatus enum.
      // isHealthConnectAvailable() is a bool shortcut and cannot be used in a switch.
      final status = await _health.getHealthConnectSdkStatus();
      return switch (status) {
        HealthConnectSdkStatus.sdkAvailable =>
          AndroidHealthConnectStatus.available,
        HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired =>
          AndroidHealthConnectStatus.updateRequired,
        _ => AndroidHealthConnectStatus.notInstalled,
      };
    } catch (e) {
      debugPrint('[HealthPermission] getHealthConnectSdkStatus error: $e');
      return AndroidHealthConnectStatus.notInstalled;
    }
  }

  // ─── Permission check ────────────────────────────────────────────────────

  static Future<HealthPermissionStatus> checkPermissions() async {
    try {
      if (Platform.isAndroid) {
        final connectStatus = await checkHealthConnectStatus();
        if (connectStatus != AndroidHealthConnectStatus.available) {
          debugPrint(
              '[HealthPermission] Health Connect status: $connectStatus');
          return HealthPermissionStatus.unavailable;
        }
      }

      // hasPermissions returns null on iOS when the user has never been asked
      // (HealthKit does not expose a "not-determined" state to apps).
      final hasPerms = await _health.hasPermissions(
        _dataTypes,
        permissions: _readOnly,
      );

      debugPrint('[HealthPermission] hasPermissions: $hasPerms');

      if (hasPerms == null) return HealthPermissionStatus.unknown;
      return hasPerms
          ? HealthPermissionStatus.granted
          : HealthPermissionStatus.denied;
    } catch (e) {
      debugPrint('[HealthPermission] checkPermissions error: $e');
      return HealthPermissionStatus.unknown;
    }
  }

  // ─── Permission request ──────────────────────────────────────────────────

  /// Returns true if the user granted all (or at least the read) permissions.
  ///
  /// On iOS, HealthKit always returns true even when the user denies — the
  /// framework hides the user's decision for privacy reasons. Treat the result
  /// as "the dialog was shown" rather than "access was confirmed."
  static Future<bool> requestPermissions() async {
    try {
      debugPrint(
          '[HealthPermission] requesting ${_dataTypes.length} types: $_dataTypes');
      return await _health.requestAuthorization(
        _dataTypes,
        permissions: _readOnly,
      );
    } catch (e) {
      debugPrint('[HealthPermission] requestAuthorization error: $e');
      return false;
    }
  }

  // ─── Deep-link to Health Connect ─────────────────────────────────────────

  /// Directs the user to the Play Store to install / update Health Connect.
  static Future<void> openHealthConnect() async {
    if (!Platform.isAndroid) return;
    try {
      await _health.installHealthConnect();
    } catch (e) {
      debugPrint('[HealthPermission] installHealthConnect error: $e');
    }
  }
}