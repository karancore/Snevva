import 'package:flutter/material.dart';
import 'package:snevva/common/app_keys.dart';

class NoInternetBanner {
  static OverlayEntry? _overlayEntry;
  static bool _isShowing = false;

  static void show() {
    if (_isShowing) return;

    final overlay = appNavigatorKey.currentState?.overlay;
    if (overlay == null) {
      debugPrint(
          '❌ NoInternetBanner.show() failed: Navigator overlay not ready');
      return;
    }

    try {
      _isShowing = true;

      _overlayEntry = OverlayEntry(
        builder: (_) =>
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  color: Colors.red.shade700,
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 16,
                  ),
                  child: const SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        Icon(Icons.wifi_off, color: Colors.white, size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                        'No internet connection',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      );

      overlay.insert(_overlayEntry!);
    } catch (e) {
      debugPrint('❌ NoInternetBanner.show() failed: $e');
      _isShowing = false;
      _overlayEntry = null;
    }
  }

  static void hide() {
    // ✅ Guard against double-remove
    if (!_isShowing || _overlayEntry == null) return;

    try {
      _overlayEntry!.remove();
    } catch (e) {
      debugPrint('❌ NoInternetBanner.hide() error: $e');
    } finally {
      _overlayEntry = null;
      _isShowing = false;
    }
  }
}

class YesInternetBanner {
  static OverlayEntry? _overlayEntry;
  static bool _isShowing = false;

  static void show() {
    if (_isShowing) return;

    final overlay = appNavigatorKey.currentState?.overlay;
    if (overlay == null) {
      debugPrint(
          '❌ YesInternetBanner.show() failed: Navigator overlay not ready');
      return;
    }

    try {
      _isShowing = true;

      _overlayEntry = OverlayEntry(
        builder: (_) =>
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  color: Colors.green.shade600,
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 16,
                  ),
                  child: const SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        Icon(Icons.wifi, color: Colors.white, size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                        'You are online',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      );

      overlay.insert(_overlayEntry!);
    } catch (e) {
      debugPrint('❌ YesInternetBanner.show() failed: $e');
      _isShowing = false;
      _overlayEntry = null;
    }
  }

  static void hide() {
    // ✅ Guard against double-remove
    if (!_isShowing || _overlayEntry == null) return;

    try {
      _overlayEntry!.remove();
    } catch (e) {
      debugPrint('❌ YesInternetBanner.hide() error: $e');
    } finally {
      _overlayEntry = null;
      _isShowing = false;
    }
  }
}