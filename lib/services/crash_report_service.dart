import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:snevva/common/ExceptionLogger.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/services/auth_service.dart';

class CrashReportService {
  static _PendingCrash? _pendingCrash;
  static bool _isDialogVisible = false;
  static bool _uiReady = false;
  static String? _lastFingerprint;
  static DateTime? _lastHandledAt;

  static void install() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      unawaited(
        handleException(
          details.exception,
          stackTrace: details.stack,
          source: 'flutter_error',
        ),
      );
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(
        handleException(
          error,
          stackTrace: stack,
          source: 'platform_dispatcher',
        ),
      );
      return true;
    };

    ErrorWidget.builder = (details) {
      unawaited(
        handleException(
          details.exception,
          stackTrace: details.stack,
          source: 'error_widget',
        ),
      );

      return const _CrashFallbackWidget();
    };
  }

  static Future<void> markUiReady() async {
    _uiReady = true;
    await _tryShowDialog();
  }

  static Future<void> handleZoneError(Object error, StackTrace stack) async {
    await handleException(
      error,
      stackTrace: stack,
      source: 'run_zoned_guarded',
    );
  }

  static Future<void> handleException(
    Object error, {
    StackTrace? stackTrace,
    required String source,
  }) async {
    final stack = stackTrace ?? StackTrace.current;
    final fingerprint = _buildFingerprint(error, stack, source);
    if (_isDuplicate(fingerprint)) return;

    try {
      final payload = await ExceptionLogger.buildPayload(
        exception: error,
        stackTrace: stack,
        userInput: 'Unhandled exception from $source',
      );

      _pendingCrash = _PendingCrash(
        payload: payload,
        exceptionSummary: error.toString(),
      );

      await _sendPendingCrash();
      await _tryShowDialog();
    } catch (e) {
      debugPrint('CrashReportService failed to prepare crash report: $e');
    }
  }

  static bool _isDuplicate(String fingerprint) {
    final now = DateTime.now();
    final isRecent =
        _lastHandledAt != null &&
        now.difference(_lastHandledAt!) < const Duration(seconds: 2);

    if (_lastFingerprint == fingerprint && isRecent) {
      return true;
    }

    _lastFingerprint = fingerprint;
    _lastHandledAt = now;
    return false;
  }

  static String _buildFingerprint(
    Object error,
    StackTrace stackTrace,
    String source,
  ) {
    final stackText = stackTrace.toString();
    final head =
        stackText.length > 500 ? stackText.substring(0, 500) : stackText;
    return '$source|${error.runtimeType}|${error.toString()}|$head';
  }

  static Future<void> _tryShowDialog() async {
    if (!_uiReady || _isDialogVisible || _pendingCrash == null) return;
    if (Get.context == null && Get.overlayContext == null) return;

    _isDialogVisible = true;
    try {
      await Get.dialog<void>(
        WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            title: const Text('App Crash Detected'),
            content: Text(
              _pendingCrash?.isSent == true
                  ? 'The app hit an unexpected error and the crash report has '
                      'already been sent to the server.\n\n'
                      'You can close this message, or Clear All to remove local '
                      'app data and go back to sign in.\n\n'
                  : 'The app hit an unexpected error.\n\n'
                      'Tap Report to send the crash log to the server, or Clear '
                      'All to remove local app data and go back to sign in.'
            ),
            actions: [
              TextButton(
                onPressed: _handleReport,
                child: Text(
                  _pendingCrash?.isSent == true ? 'Close' : 'Report',
                ),
              ),
              FilledButton(
                onPressed: _handleClearAll,
                child: const Text('Clear All'),
              ),
            ],
          ),
        ),
        barrierDismissible: false,
      );
    } finally {
      _isDialogVisible = false;
      if (_pendingCrash != null) {
        unawaited(_tryShowDialog());
      }
    }
  }

  static Future<void> _handleReport() async {
    if (_pendingCrash?.isSent == true) {
      _pendingCrash = null;
      if (Get.isDialogOpen ?? false) {
        Get.back<void>();
      }
      return;
    }

    final isSent = await _sendPendingCrash();
    if (!isSent) {
      Get.snackbar(
        'Crash Report',
        'Report send nahi ho paya. Please retry.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    _pendingCrash = null;
    if (Get.isDialogOpen ?? false) {
      Get.back<void>();
    }
  }

  static Future<void> _handleClearAll() async {
    await _sendPendingCrash();
    _pendingCrash = null;

    if (Get.isDialogOpen ?? false) {
      Get.back<void>();
    }

    await AuthService.forceLogout();
  }

  static Future<bool> _sendPendingCrash() async {
    final crash = _pendingCrash;
    if (crash == null) return true;
    if (crash.isSent) return true;

    final isSent = await AuthService.logExceptionToServer(crash.payload);
    if (isSent) {
      crash.isSent = true;
    }

    return isSent;
  }
}

class _PendingCrash {
  final Map<String, dynamic> payload;
  final String exceptionSummary;
  bool isSent = false;

  _PendingCrash({
    required this.payload,
    required this.exceptionSummary,
  });
}

class _CrashFallbackWidget extends StatelessWidget {
  const _CrashFallbackWidget();

  @override
  Widget build(BuildContext context) {
    return const Material(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Something went wrong. A crash report is ready to send.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
