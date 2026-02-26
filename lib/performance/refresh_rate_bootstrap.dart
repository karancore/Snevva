import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

@immutable
class RefreshRateProfile {
  final double detectedRefreshRateHz;
  final double maxSupportedRefreshRateHz;
  final bool highRefreshRequested;
  final double targetFrameRateHz;

  const RefreshRateProfile({
    required this.detectedRefreshRateHz,
    required this.maxSupportedRefreshRateHz,
    required this.highRefreshRequested,
    required this.targetFrameRateHz,
  });

  bool get supportsHighRefresh => maxSupportedRefreshRateHz >= 90.0;

  double get frameBudgetMs => 1000.0 / targetFrameRateHz;

  RefreshRateProfile copyWith({
    double? detectedRefreshRateHz,
    double? maxSupportedRefreshRateHz,
    bool? highRefreshRequested,
    double? targetFrameRateHz,
  }) {
    return RefreshRateProfile(
      detectedRefreshRateHz:
          detectedRefreshRateHz ?? this.detectedRefreshRateHz,
      maxSupportedRefreshRateHz:
          maxSupportedRefreshRateHz ?? this.maxSupportedRefreshRateHz,
      highRefreshRequested: highRefreshRequested ?? this.highRefreshRequested,
      targetFrameRateHz: targetFrameRateHz ?? this.targetFrameRateHz,
    );
  }
}

class RefreshRateBootstrap {
  RefreshRateBootstrap._();

  static const MethodChannel _displayChannel = MethodChannel(
    'com.coretegra.snevva/display_config',
  );

  static const double _fallbackRefreshRateHz = 60.0;
  static const double _highRefreshThresholdHz = 90.0;

  static RefreshRateProfile _profile = const RefreshRateProfile(
    detectedRefreshRateHz: _fallbackRefreshRateHz,
    maxSupportedRefreshRateHz: _fallbackRefreshRateHz,
    highRefreshRequested: false,
    targetFrameRateHz: _fallbackRefreshRateHz,
  );

  static RefreshRateProfile get profile => _profile;

  static Future<RefreshRateProfile> initialize() async {
    var detectedHz = _readFlutterDisplayRefreshRate() ?? _fallbackRefreshRateHz;
    var maxSupportedHz = detectedHz;
    var highRefreshRequested = false;

    if (_canUseDisplayChannel) {
      final nativeCurrentHz = await _invokeDouble('getDisplayRefreshRate');
      if (nativeCurrentHz != null && nativeCurrentHz > 0) {
        detectedHz = nativeCurrentHz;
      }

      final nativeMaxHz = await _invokeDouble('getHighestSupportedRefreshRate');
      if (nativeMaxHz != null && nativeMaxHz > 0) {
        maxSupportedHz = nativeMaxHz;
      }

      if (maxSupportedHz >= _highRefreshThresholdHz) {
        highRefreshRequested =
            await _invokeBool('requestHighestRefreshRate') ?? false;
        final updatedCurrentHz = await _invokeDouble('getDisplayRefreshRate');
        if (updatedCurrentHz != null && updatedCurrentHz > 0) {
          detectedHz = updatedCurrentHz;
        }
      }
    }

    final normalizedDetectedHz = _normalizeRefreshRate(detectedHz);
    final normalizedMaxHz = _normalizeRefreshRate(
      math.max(maxSupportedHz, normalizedDetectedHz),
    );

    _profile = RefreshRateProfile(
      detectedRefreshRateHz: normalizedDetectedHz,
      maxSupportedRefreshRateHz: normalizedMaxHz,
      highRefreshRequested: highRefreshRequested,
      targetFrameRateHz: _resolveTargetFrameRate(normalizedDetectedHz),
    );

    _logProfile('startup', _profile);
    return _profile;
  }

  static RefreshRateProfile? updateFromContext(BuildContext context) {
    final contextHz = readContextRefreshRate(context);
    if (contextHz == null || contextHz <= 0) {
      return null;
    }

    final normalizedContextHz = _normalizeRefreshRate(contextHz);
    final nextProfile = _profile.copyWith(
      detectedRefreshRateHz: normalizedContextHz,
      maxSupportedRefreshRateHz: math.max(
        _profile.maxSupportedRefreshRateHz,
        normalizedContextHz,
      ),
      targetFrameRateHz: _resolveTargetFrameRate(normalizedContextHz),
    );

    final hasChanged =
        (nextProfile.detectedRefreshRateHz - _profile.detectedRefreshRateHz)
                .abs() >=
            0.5 ||
        (nextProfile.targetFrameRateHz - _profile.targetFrameRateHz).abs() >=
            0.5;

    if (!hasChanged) {
      return null;
    }

    _profile = nextProfile;
    _logProfile('context', _profile);
    return _profile;
  }

  static double? readContextRefreshRate(BuildContext context) {
    try {
      final dynamic display = View.of(context).display;
      final dynamic refreshRate = display.refreshRate;
      if (refreshRate is num && refreshRate > 0) {
        return refreshRate.toDouble();
      }
    } catch (_) {}
    return null;
  }

  static Duration quantizeDuration(
    Duration targetDuration, {
    double? refreshRateHz,
  }) {
    final hz = (refreshRateHz ?? _profile.targetFrameRateHz)
        .clamp(30.0, 240.0)
        .toDouble();
    final microsPerFrame = Duration.microsecondsPerSecond / hz;
    final frameCount = math.max(
      1,
      (targetDuration.inMicroseconds / microsPerFrame).round(),
    );
    return Duration(microseconds: (frameCount * microsPerFrame).round());
  }

  static bool get _canUseDisplayChannel {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static double _resolveTargetFrameRate(double detectedRefreshRateHz) {
    return detectedRefreshRateHz >= _highRefreshThresholdHz
        ? 120.0
        : _fallbackRefreshRateHz;
  }

  static double _normalizeRefreshRate(double value) {
    if (value <= 0) return _fallbackRefreshRateHz;
    return value.clamp(24.0, 240.0).toDouble();
  }

  static double? _readFlutterDisplayRefreshRate() {
    try {
      final views = WidgetsBinding.instance.platformDispatcher.views;
      if (views.isEmpty) return null;
      final dynamic display = views.first.display;
      final dynamic refreshRate = display.refreshRate;
      if (refreshRate is num && refreshRate > 0) {
        return refreshRate.toDouble();
      }
    } catch (_) {}
    return null;
  }

  static Future<double?> _invokeDouble(String method) async {
    try {
      final value = await _displayChannel.invokeMethod<dynamic>(method);
      if (value is num && value > 0) {
        return value.toDouble();
      }
    } on MissingPluginException {
      return null;
    } catch (error, stackTrace) {
      debugPrint('[RefreshRate] $method failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    return null;
  }

  static Future<bool?> _invokeBool(String method) async {
    try {
      final value = await _displayChannel.invokeMethod<dynamic>(method);
      if (value is bool) {
        return value;
      }
    } on MissingPluginException {
      return null;
    } catch (error, stackTrace) {
      debugPrint('[RefreshRate] $method failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    return null;
  }

  static void _logProfile(String source, RefreshRateProfile profile) {
    debugPrint(
      '[RefreshRate:$source] '
      'detected=${profile.detectedRefreshRateHz.toStringAsFixed(1)}Hz '
      'max=${profile.maxSupportedRefreshRateHz.toStringAsFixed(1)}Hz '
      'target=${profile.targetFrameRateHz.toStringAsFixed(1)}Hz '
      'budget=${profile.frameBudgetMs.toStringAsFixed(2)}ms '
      'requestedHigh=${profile.highRefreshRequested}',
    );
  }
}
