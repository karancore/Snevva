import 'package:flutter/foundation.dart';

import '../models/health_sync_result.dart';
import '../models/watch_connection_state.dart';
import '../permission/health_permission_manager.dart';
import '../repositories/health_repository.dart';
import 'health_service.dart';
import 'watch_connection_monitor.dart';

/// Platform-agnostic service layer for smartwatch health data.
///
/// This is the single entry point for all health + wearable functionality.
/// It abstracts all differences between Android (Health Connect) and iOS
/// (HealthKit / Apple Watch), so the controller and UI layers never need
/// to know which platform they're running on.
///
/// Lifecycle:
///   1. Call [initialize] once on app start (or from the controller's onInit).
///   2. Call [startWatchMonitoring] to begin continuous connection detection.
///   3. Listen to [watchStream] for real-time watch state updates.
///   4. Call [syncAll] to pull the latest health metrics.
///   5. Call [stopWatchMonitoring] / [dispose] on teardown.
class HealthDataService {
  HealthDataService._();

  static final HealthDataService instance = HealthDataService._();

  final WatchConnectionMonitor _watchMonitor = WatchConnectionMonitor();
  bool _initialized = false;

  // ─── Streams ─────────────────────────────────────────────────────────────

  /// Emits [WatchConnectionState] on each poll cycle (every 5 minutes) and
  /// immediately whenever the app returns to the foreground.
  ///
  /// A [WatchConnectionStatus.connected] state means recent watch-sourced data
  /// was found in Health Connect / HealthKit within the last hour.
  Stream<WatchConnectionState> get watchStream => _watchMonitor.stream;

  // ─── Lifecycle ───────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    debugPrint('[HealthDataService] initializing');
    await HealthService.configure();
    debugPrint('[HealthDataService] initialized');
  }

  void startWatchMonitoring() {
    debugPrint('[HealthDataService] starting watch monitoring');
    _watchMonitor.start();
  }

  void stopWatchMonitoring() {
    debugPrint('[HealthDataService] stopping watch monitoring');
    _watchMonitor.stop();
  }

  void dispose() {
    _watchMonitor.dispose();
    _initialized = false;
  }

  // ─── Permissions ─────────────────────────────────────────────────────────

  /// Checks current health permission status without showing any UI.
  ///
  /// Logs:
  ///   [HealthPermission] permissionStatus: <value>
  Future<HealthPermissionStatus> checkPermissions() async {
    final status = await HealthPermissionManager.checkPermissions();
    debugPrint('[HealthDataService] permission status: $status');
    return status;
  }

  /// Requests health permissions — shows the system permission dialog.
  ///
  /// On iOS, HealthKit always returns `true` regardless of the user's actual
  /// choice (privacy design). Always re-check [checkPermissions] afterwards.
  ///
  /// Logs:
  ///   [HealthDataService] permission request result: <bool>
  Future<bool> requestPermissions() async {
    final result = await HealthPermissionManager.requestPermissions();
    debugPrint('[HealthDataService] permission request result: $result');
    return result;
  }

  /// Opens the Health Connect store page on Android.
  Future<void> openHealthConnect() => HealthPermissionManager.openHealthConnect();

  // ─── Data sync ───────────────────────────────────────────────────────────

  /// Syncs all available health metrics for the last [days] days.
  ///
  /// Includes heart rate, blood glucose, blood pressure, and sleep data.
  /// Metrics not supported by the connected device or not yet recorded will
  /// have null values in the result — the UI should show "Not Available".
  ///
  /// Logs:
  ///   [HealthDataService] sync: hr=<n> bg=<n> bp=<n> sleep=<n>
  ///   [HealthDataService] sync error: <message>  (on partial/full failure)
  Future<HealthSyncResult> syncAll({int days = 30}) async {
    debugPrint('[HealthDataService] syncing (last $days days)');
    final result = await HealthRepository.syncLastDays(days: days);
    debugPrint(
      '[HealthDataService] sync complete — '
      'HR=${result.latestHeartRate?.beatsPerMinute?.toStringAsFixed(0) ?? "—"} bpm  '
      'BG=${result.latestGlucose?.mmolPerL?.toStringAsFixed(1) ?? "—"} mmol/L  '
      'BP=${result.latestBloodPressure?.formatted ?? "—"}  '
      'sleep=${result.sleepHistory.length} segment(s)',
    );
    if (result.errorMessage != null) {
      debugPrint('[HealthDataService] sync error: ${result.errorMessage}');
    }
    return result;
  }

  /// Forces an immediate watch connection check, bypassing the poll timer.
  Future<WatchConnectionState> checkWatchNow() {
    debugPrint('[HealthDataService] forcing watch check');
    return _watchMonitor.checkNow();
  }
}