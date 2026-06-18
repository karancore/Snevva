import 'package:get/get_connect/http/src/response/response.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../consts/consts.dart';
import '../env/env.dart';
import '../services/api_service.dart';

class PushNotificationsController extends GetxController {
  final isNotificationEnabled = false.obs;

  final isUpdatingNotification = false.obs;

  static const String _isDndKey = 'is_dnd_enabled';

  @override
  void onInit() {
    super.onInit();
    _loadNotificationPreference();
  }

  Future<void> _loadNotificationPreference() async {
    final prefs = await SharedPreferences.getInstance();

    final savedValue = prefs.getBool(_isDndKey);

    if (savedValue != null) {
      isNotificationEnabled.value = savedValue;
    }
  }

  Future<void> disableNotifications(bool isEnabled) async {
    /// Prevent duplicate requests
    if (isUpdatingNotification.value) return;

    try {
      isUpdatingNotification.value = true;

      debugPrint("🚀 disableNotifications() called");

      final payload = {"Value": isEnabled};

      final response = await ApiService.post(
        dnd,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response) {
        debugPrint(
          "❌ HTTP ${response.statusCode}",
        );

        return;
      }

      /// Update UI state
      isNotificationEnabled.value = isEnabled;

      /// Save locally
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(_isDndKey, isEnabled);

      debugPrint("✅ Notification preference updated");
    } catch (e, stackTrace) {
      debugPrint("❌ Error: $e");
      debugPrint("$stackTrace");
    } finally {
      isUpdatingNotification.value = false;
    }
  }
}