import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

class FrameTimingMonitor {
  FrameTimingMonitor._();

  static final FrameTimingMonitor instance = FrameTimingMonitor._();

  bool _isRunning = false;
  double _frameBudgetMs = 1000.0 / 60.0;
  int _sampleCount = 0;
  int _slowFrameCount = 0;
  DateTime _lastSlowFrameLogAt = DateTime.fromMillisecondsSinceEpoch(0);

  void start({required double targetFrameRateHz}) {
    if (_isRunning) return;

    _frameBudgetMs = _frameBudgetFromHz(targetFrameRateHz);
    _sampleCount = 0;
    _slowFrameCount = 0;
    _isRunning = true;

    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    debugPrint(
      '[FrameTiming] started: target=${targetFrameRateHz.toStringAsFixed(1)}Hz '
      'budget=${_frameBudgetMs.toStringAsFixed(2)}ms',
    );
  }

  void updateTargetFrameRate(double targetFrameRateHz) {
    final nextBudgetMs = _frameBudgetFromHz(targetFrameRateHz);
    if ((_frameBudgetMs - nextBudgetMs).abs() < 0.1) return;
    _frameBudgetMs = nextBudgetMs;
    debugPrint(
      '[FrameTiming] budget updated: target=${targetFrameRateHz.toStringAsFixed(1)}Hz '
      'budget=${_frameBudgetMs.toStringAsFixed(2)}ms',
    );
  }

  void stop() {
    if (!_isRunning) return;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _isRunning = false;
    debugPrint('[FrameTiming] stopped');
  }

  double _frameBudgetFromHz(double frameRateHz) {
    final normalizedHz = frameRateHz.clamp(30.0, 240.0).toDouble();
    return 1000.0 / normalizedHz;
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _sampleCount++;

      final buildMs = timing.buildDuration.inMicroseconds / 1000.0;
      final rasterMs = timing.rasterDuration.inMicroseconds / 1000.0;
      final totalMs = buildMs + rasterMs;

      if (totalMs > _frameBudgetMs) {
        _slowFrameCount++;
        _logSlowFrameIfNeeded(
          buildMs: buildMs,
          rasterMs: rasterMs,
          totalMs: totalMs,
        );
      }

      if (_sampleCount % 120 == 0) {
        final slowPercent = (_slowFrameCount / _sampleCount) * 100.0;
        debugPrint(
          '[FrameTiming] samples=$_sampleCount '
          'slow=$_slowFrameCount (${slowPercent.toStringAsFixed(1)}%) '
          'budget=${_frameBudgetMs.toStringAsFixed(2)}ms',
        );
      }
    }
  }

  void _logSlowFrameIfNeeded({
    required double buildMs,
    required double rasterMs,
    required double totalMs,
  }) {
    final now = DateTime.now();
    final shouldLog =
        _slowFrameCount <= 5 ||
        now.difference(_lastSlowFrameLogAt) > const Duration(seconds: 2);
    if (!shouldLog) return;

    _lastSlowFrameLogAt = now;
    debugPrint(
      '[FrameTiming] slow frame: '
      'total=${totalMs.toStringAsFixed(2)}ms '
      'build=${buildMs.toStringAsFixed(2)}ms '
      'raster=${rasterMs.toStringAsFixed(2)}ms '
      'budget=${_frameBudgetMs.toStringAsFixed(2)}ms '
      'over=${math.max(0, totalMs - _frameBudgetMs).toStringAsFixed(2)}ms',
    );
  }
}
