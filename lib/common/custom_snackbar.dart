import 'package:flutter/material.dart';
import 'package:snevva/env/env.dart';
import '../consts/colors.dart';

class CustomSnackbar {
  CustomSnackbar._(); // prevent instantiation

  static void showError({
    required BuildContext context,
    required String title,
    required String message,
  }) {
    if (!Env.enableSnackbar) return;

    _show(
      context: context,
      title: title,
      message: message,
      backgroundColor: Colors.red,
    );
  }

  static void showSuccess({
    required BuildContext context,
    required String title,
    required String message,
  }) {
    if (!Env.enableSnackbar) return;

    _show(
      context: context,
      title: title,
      message: message,
      backgroundColor: Colors.green,
    );
  }

  static void showSnackbar({
    required BuildContext context,
    required String title,
    required String message,
  }) {
    if (!Env.enableSnackbar) return;

    _show(
      context: context,
      title: title,
      message: message,
      backgroundColor: AppColors.primaryColor,
    );
  }

  // 🔒 Single private renderer (no duplication)
  static void _show({
    required BuildContext context,
    required String title,
    required String message,
    required Color backgroundColor,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor,
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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
                  Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
