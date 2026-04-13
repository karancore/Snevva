import 'package:flutter/material.dart';
import 'package:snevva/env/env.dart';

import '../consts/colors.dart';
import 'animted_reminder_bar.dart';

enum SnackbarPosition {
  top,
  bottom,
}

class _SnackbarContent extends StatelessWidget {
  final String title;
  final String message;

  const _SnackbarContent({
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(message, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
class CustomSnackbar {
  OverlayEntry? overlay;

  void showReminderBar(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final double topPadding =
        MediaQuery.of(context).padding.top + 10; // 👈 safe area + 10

    overlay = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: topPadding,
          left: 0,
          right: 0,
          child: Material(
            color: isDarkMode ? white : black,
            child: AnimatedReminderBar(show: true),
          ),
        );
      },
    );

    Overlay.of(context).insert(overlay!);

    // Remove after 3 seconds + animation
    Future.delayed(const Duration(seconds: 4), () {
      overlay?.remove();
    });
  }

  static void showCustom({
    required BuildContext context,
    required String title,
    required String message,
    SnackbarPosition position = SnackbarPosition.bottom,
  }) {
    final overlay = Overlay.of(context);

    final topPadding = MediaQuery
        .of(context)
        .padding
        .top + 10;

    final entry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: position == SnackbarPosition.top ? topPadding : null,
          bottom: position == SnackbarPosition.bottom ? 20 : null,
          left: 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: _SnackbarContent(title: title, message: message),
          ),
        );
      },
    );

    overlay.insert(entry);

    Future.delayed(const Duration(seconds: 3), () {
      entry.remove();
    });
  }

  static void showError({
    required BuildContext context,
    required String title,
    required String message,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primaryColor,
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(message, style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static void showSuccess({
    required BuildContext context,
    required String title,
    required String message,
  }) {
    if (!Env.enableSnackbar) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(message, style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static void showSnackbar({
    required BuildContext context,
    required String title,
    required String message,
  }) {
    if (!Env.enableSnackbar) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primaryColor,
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(message, style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static void showOtherDeviceLogoutSuccess({required BuildContext context}) {
    _show(
      context: context,
      backgroundColor: Colors.green.shade700,
      icon: Icons.security,
      title: "Device Logged Out",
      message:
          "The other device has been successfully logged out for your security.",
    );
  }

  /// 🚫 SECURITY: Login blocked from unrecognized device
  static void showDeviceBlocked({required BuildContext context}) {
    _show(
      context: context,
      backgroundColor: Colors.red.shade700,
      icon: Icons.block_outlined,
      title: "Security Alert",
      message: "Login attempt blocked. This device is not recognized.",
    );
  }

  static void _show({
    required BuildContext context,
    required Color backgroundColor,
    required IconData icon,
    required String title,
    required String message,
  }) {
    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor,
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
