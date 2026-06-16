import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../models/watch_connection_state.dart';
import 'health_service.dart';

/// Continuously monitors smartwatch connectivity by detecting recent
/// watch-sourced health data from Health Connect (Android) or HealthKit (iOS).
///
/// Detection strategy:
///   - Fetches heart rate data from the last hour on each poll.
///   - Inspects the `sourceName` of every data point.
///   - If any point came from a known wearable source, the watch is "connected".
///   - Polls every [_pollInterval]; fires immediately on app resume.
///
/// Neither Health Connect nor HealthKit exposes a direct Bluetooth/pairing API
/// to Flutter, so source-name heuristics are the platform-standard approach.
class WatchConnectionMonitor with WidgetsBindingObserver {
  static const Duration _pollInterval = Duration(minutes: 5);

  // Known wearable source-name substrings (case-insensitive).
  // This covers the most common watch brands that write to HC / HealthKit.
  static const List<String> _watchKeywords = [
    'watch',
    'fitbit',
    'garmin',
    'polar',
    'suunto',
    'amazfit',
    'mi band',
    'miband',
    'mi watch',
    'redmi watch',
    'realme watch',
    'noise',
    'fossil',
    'mobvoi',
    'withings',
    'huami',
    'zepp',
    'coros',
    'wahoo',
    'whoop',
    'stryd',
    'oura',
  ];

  final StreamController<WatchConnectionState> _controller =
      StreamController<WatchConnectionState>.broadcast();

  Timer? _pollTimer;
  bool _running = false;

  /// Emits [WatchConnectionState] on each poll and whenever the app resumes.
  Stream<WatchConnectionState> get stream => _controller.stream;

  // ─── Lifecycle ───────────────────────────────────────────────────────────

  void start() {
    if (_running) return;
    _running = true;
    WidgetsBinding.instance.addObserver(this);
    debugPrint(
        '[WatchMonitor] started — polling every ${_pollInterval.inMinutes} min');
    _poll(); // immediate check
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  void stop() {
    if (!_running) return;
    _running = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    WidgetsBinding.instance.removeObserver(this);
    debugPrint('[WatchMonitor] stopped');
  }

  void dispose() {
    stop();
    _controller.close();
  }

  // ─── WidgetsBindingObserver ──────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('[WatchMonitor] app resumed — immediate watch check');
      _poll();
    }
  }

  // ─── Public API ──────────────────────────────────────────────────────────

  /// Forces an immediate connection check and emits on [stream].
  Future<WatchConnectionState> checkNow() async {
    final state = await _detect();
    if (!_controller.isClosed) {
      _controller.add(state);
    }
    return state;
  }

  // ─── Internal ────────────────────────────────────────────────────────────

  Future<void> _poll() async {
    if (_controller.isClosed) return;
    final state = await _detect();
    _controller.add(state);
  }

  Future<WatchConnectionState> _detect() async {
    try {
      final end = DateTime.now();
      final start = end.subtract(const Duration(hours: 1));

      // Heart rate is the most reliably synced wearable metric — every watch
      // with an optical sensor writes HR to the health platform continuously.
      final points = await HealthService.fetchHeartRate(start: start, end: end);

      debugPrint('[WatchMonitor] ${points.length} HR point(s) in last 1h');

      String? watchName;
      DateTime? lastDataAt;

      for (final p in points) {
        debugPrint(
            '[WatchMonitor]   source="${p.sourceName}" at=${p.dateTo}');

        if (_isWatchSource(p.sourceName)) {
          if (lastDataAt == null || p.dateTo.isAfter(lastDataAt)) {
            lastDataAt = p.dateTo;
            watchName = p.sourceName;
          }
        }
      }

      if (watchName != null) {
        debugPrint(
            '[WatchMonitor] connected: "$watchName" lastSync=$lastDataAt');
        return WatchConnectionState(
          status: WatchConnectionStatus.connected,
          watchName: watchName,
          lastDataAt: lastDataAt,
          checkedAt: DateTime.now(),
        );
      }

      debugPrint('[WatchMonitor] no watch data found — disconnected/unknown');
      return WatchConnectionState(
        status: WatchConnectionStatus.disconnected,
        checkedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[WatchMonitor] detection error: $e');
      return WatchConnectionState(
        status: WatchConnectionStatus.unknown,
        checkedAt: DateTime.now(),
      );
    }
  }

  static bool _isWatchSource(String sourceName) {
    final lower = sourceName.toLowerCase();
    return _watchKeywords.any(lower.contains);
  }
}