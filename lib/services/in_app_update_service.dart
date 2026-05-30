import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

class InAppUpdateService {
  static Future<void> checkForUpdate() async {
    if (!Platform.isAndroid) return;

    try {
      final AppUpdateInfo info = await InAppUpdate.checkForUpdate();

      debugPrint("Update Availability: ${info.updateAvailability}");

      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        // Immediate Update
        await _performImmediateUpdate();

        // OR Flexible Update
        // await _performFlexibleUpdate();
      }
    } catch (e) {
      debugPrint("In-app update error: $e");
    }
  }

  static Future<void> _performImmediateUpdate() async {
    try {
      await InAppUpdate.performImmediateUpdate();
    } catch (e) {
      debugPrint("Immediate update failed: $e");
    }
  }

  static Future<void> _performFlexibleUpdate() async {
    try {
      await InAppUpdate.startFlexibleUpdate();

      await InAppUpdate.completeFlexibleUpdate();
    } catch (e) {
      debugPrint("Flexible update failed: $e");
    }
  }
}
