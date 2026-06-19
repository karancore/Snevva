import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../models/blood_glucose_record.dart';
import '../models/blood_pressure_record.dart';
import '../models/heart_rate_record.dart';
import '../models/sleep_record.dart';
import '../models/watch_connection_state.dart';
import '../permission/health_permission_manager.dart';
import '../repositories/health_repository.dart';
import '../services/health_data_service.dart';

/// GetX controller that drives the smartwatch Health SDK dashboard.
///
/// Lifecycle:
///   onInit  → initialize HealthDataService → check permissions → auto-sync
///             → start watch monitoring → subscribe to watch stream
///   resumed → re-sync (via WidgetsBindingObserver)
///   watch connected → immediate sync
///   periodic → sync every [_autoSyncInterval] while watch is connected
///   onClose → cancel subscriptions, stop monitoring
class HealthSdkController extends GetxController with WidgetsBindingObserver {
  static const Duration _autoSyncInterval = Duration(minutes: 15);

  // ─── Observables — permissions & platform ────────────────────────────────

  final Rx<HealthPermissionStatus> permissionStatus =
      HealthPermissionStatus.unknown.obs;
  final Rx<AndroidHealthConnectStatus?> healthConnectStatus = Rx(null);

  // ─── Observables — watch connection ──────────────────────────────────────

  final Rx<WatchConnectionState> watchState =
      WatchConnectionState.initial().obs;

  // ─── Observables — vitals ────────────────────────────────────────────────

  final Rx<HeartRateRecord?> latestHeartRate = Rx(null);
  final Rx<BloodGlucoseRecord?> latestGlucose = Rx(null);
  final Rx<BloodPressureRecord?> latestBloodPressure = Rx(null);
  final Rx<SleepRecord?> latestSleep = Rx(null);

  final RxList<HeartRateRecord> heartRateHistory = <HeartRateRecord>[].obs;
  final RxList<BloodGlucoseRecord> glucoseHistory = <BloodGlucoseRecord>[].obs;
  final RxList<BloodPressureRecord> bloodPressureHistory =
      <BloodPressureRecord>[].obs;
  final RxList<SleepRecord> sleepHistory = <SleepRecord>[].obs;

  // ─── Observables — sync state ────────────────────────────────────────────

  final RxBool isSyncing = false.obs;
  final RxString errorMessage = ''.obs;
  final Rx<DateTime?> lastSyncTime = Rx(null);

  // ─── Internal ────────────────────────────────────────────────────────────

  StreamSubscription<WatchConnectionState>? _watchSub;
  Timer? _autoSyncTimer;

  // ─── Derived getters ─────────────────────────────────────────────────────

  bool get isAndroid => Platform.isAndroid;

  bool get healthConnectMissing =>
      isAndroid &&
      healthConnectStatus.value != null &&
      healthConnectStatus.value != AndroidHealthConnectStatus.available;

  bool get needsPermission =>
      permissionStatus.value == HealthPermissionStatus.denied ||
      permissionStatus.value == HealthPermissionStatus.unknown;

  bool get isUnavailable =>
      permissionStatus.value == HealthPermissionStatus.unavailable;

  // ─── Lifecycle ───────────────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _watchSub?.cancel();
    _autoSyncTimer?.cancel();
    HealthDataService.instance.stopWatchMonitoring();
    super.onClose();
  }

  // ─── WidgetsBindingObserver ──────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        permissionStatus.value == HealthPermissionStatus.granted) {
      debugPrint('[HealthSdkController] app resumed — re-syncing');
      syncLast30Days();
    }
  }

  // ─── Private initialisation ──────────────────────────────────────────────

  Future<void> _initialize() async {
    await HealthDataService.instance.initialize();
    await _refreshPermissionStatus();

    if (permissionStatus.value == HealthPermissionStatus.granted) {
      await syncLast30Days();
      _startWatchMonitoring();
    }
  }

  void _startWatchMonitoring() {
    HealthDataService.instance.startWatchMonitoring();

    _watchSub?.cancel();
    _watchSub = HealthDataService.instance.watchStream.listen(
      _onWatchStateChanged,
      onError: (e) => debugPrint('[HealthSdkController] watchStream error: $e'),
    );

    // Auto-sync every 15 min regardless of watch state, so data stays fresh.
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(_autoSyncInterval, (_) {
      if (permissionStatus.value == HealthPermissionStatus.granted) {
        debugPrint('[HealthSdkController] periodic auto-sync');
        syncLast30Days();
      }
    });

    debugPrint('[HealthSdkController] watch monitoring started');
  }

  void _onWatchStateChanged(WatchConnectionState state) {
    watchState.value = state;
    debugPrint(
        '[HealthSdkController] watch state → ${state.status} '
        '(${state.watchName ?? "unknown"}) lastData=${state.lastDataAt}');

    // Trigger an immediate sync when the watch connects so new data appears
    // in the UI without waiting for the periodic timer.
    if (state.status == WatchConnectionStatus.connected) {
      syncLast30Days();
    }
  }

  // ─── Permission ──────────────────────────────────────────────────────────

  Future<void> _refreshPermissionStatus() async {
    if (Platform.isAndroid) {
      healthConnectStatus.value =
          await HealthPermissionManager.checkHealthConnectStatus();
      debugPrint(
          '[HealthSdkController] HC status: ${healthConnectStatus.value}');
    }
    permissionStatus.value = await HealthPermissionManager.checkPermissions();
    debugPrint(
        '[HealthSdkController] permissionStatus: ${permissionStatus.value}');
  }

  Future<void> requestPermissions() async {
    // On Android, bail early if Health Connect isn't installed.
    if (Platform.isAndroid) {
      final cs = await HealthPermissionManager.checkHealthConnectStatus();
      healthConnectStatus.value = cs;
      if (cs != AndroidHealthConnectStatus.available) {
        permissionStatus.value = HealthPermissionStatus.unavailable;
        return;
      }
    }

    final granted = await HealthPermissionManager.requestPermissions();

    // Re-check the actual status — iOS always returns true regardless of the
    // user's choice, so we must query hasPermissions afterwards.
    await _refreshPermissionStatus();

    if (granted || permissionStatus.value == HealthPermissionStatus.granted) {
      await syncLast30Days();
      _startWatchMonitoring();
    }
  }

  Future<void> openHealthConnectStore() async {
    await HealthDataService.instance.openHealthConnect();
    await _refreshPermissionStatus();
  }

  // ─── Sync ────────────────────────────────────────────────────────────────

  Future<void> syncLast30Days() async {
    if (isSyncing.value) return;
    isSyncing.value = true;
    errorMessage.value = '';

    try {
      final result = await HealthDataService.instance.syncAll(days: 30);

      latestHeartRate.value = result.latestHeartRate;
      latestGlucose.value = result.latestGlucose;
      latestBloodPressure.value = result.latestBloodPressure;
      latestSleep.value = result.latestSleep;

      heartRateHistory.assignAll(result.heartRateHistory);
      glucoseHistory.assignAll(result.glucoseHistory);
      bloodPressureHistory.assignAll(result.bloodPressureHistory);
      sleepHistory.assignAll(result.sleepHistory);

      lastSyncTime.value = result.syncedAt;

      if (result.errorMessage != null) {
        errorMessage.value = result.errorMessage!;
      }
    } catch (e) {
      errorMessage.value = 'Sync failed — ${e.toString()}';
      debugPrint('[HealthSdkController] syncLast30Days error: $e');
    } finally {
      isSyncing.value = false;
    }
  }

  // ─── Manual metric refresh (on-demand) ───────────────────────────────────

  Future<void> refreshHeartRate() async {
    final record = await HealthRepository.latestHeartRate();
    if (record != null) latestHeartRate.value = record;
  }

  Future<void> refreshGlucose() async {
    final record = await HealthRepository.latestBloodGlucose();
    if (record != null) latestGlucose.value = record;
  }

  Future<void> refreshBloodPressure() async {
    final record = await HealthRepository.latestBloodPressure();
    if (record != null) latestBloodPressure.value = record;
  }

  Future<void> refreshSleep() async {
    final record = await HealthRepository.latestSleep();
    if (record != null) latestSleep.value = record;
  }
}