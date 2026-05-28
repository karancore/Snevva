import 'package:flutter/material.dart';

class NoInternetBanner {
  static OverlayEntry? _overlayEntry;

  static void show(BuildContext context) {
    if (_overlayEntry != null) return; // already showing

    final entry = OverlayEntry(
      builder:
          (_) => Positioned(
            bottom: 0,
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
                  top: false,
                  child: Row(
                    children: [
                      Icon(Icons.wifi_off, color: Colors.white, size: 18),
                      SizedBox(width: 10),
                      Text(
                        'No internet connection',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );

    try {
      Overlay.of(context).insert(entry);
      _overlayEntry = entry;
    } catch (_) {}
  }

  static void hide() {
    try {
      _overlayEntry?.remove();
    } catch (_) {}
    _overlayEntry = null;
  }
}

class YesInternetBanner {
  static OverlayEntry? _overlayEntry;

  static void show(BuildContext context) {
    if (_overlayEntry != null) return; // already showing

    final entry = OverlayEntry(
      builder:
          (_) => Positioned(
            bottom: 0,
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
                  top: false,
                  child: Row(
                    children: [
                      Icon(Icons.wifi, color: Colors.white, size: 18),
                      SizedBox(width: 10),
                      Text(
                        'You are online',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );

    try {
      Overlay.of(context).insert(entry);
      _overlayEntry = entry;
    } catch (_) {}
  }

  static void hide() {
    try {
      _overlayEntry?.remove();
    } catch (_) {}
    _overlayEntry = null;
  }
}
