import 'package:get/get_connect/http/src/response/response.dart' as http;

import '../consts/consts.dart';
import '../env/env.dart';
import '../services/api_service.dart';

class PushNotificationsController extends GetxController {
  final isEnable = false.obs;

  Future<void> disableNotifications(bool isEnabled) async {
    try {
      debugPrint("🚀 disableNotifications() called");
      debugPrint("📤 Sending payload: ${{"Value": isEnable.value}}");

      final payload = {"Value": isEnabled};

      final response = await ApiService.post(
        dnd,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      debugPrint("📥 Raw response type: ${response.runtimeType}");

      if (response is http.Response) {
        debugPrint(
          "❌ [API - disableNotifications] Failed: HTTP ${response.statusCode}",
        );
        debugPrint("📄 Response body: ${response.body}");
        return;
      }

      debugPrint("✅ Notifications API success");
      debugPrint("🔕 Push notifications have been disabled.");
    } catch (e, stackTrace) {
      debugPrint("❌ Error disabling push notifications: $e");
      debugPrint("📌 StackTrace: $stackTrace");
    }
  }
}
