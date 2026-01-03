import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart';
import 'package:get/get_connect/http/src/response/response.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../common/custom_snackbar.dart';
import '../consts/consts.dart';
import '../env/env.dart';
import '../services/api_service.dart';
import '../views/SignUp/sign_in_screen.dart';
import 'package:http/http.dart';

class LocalStorageManager extends GetxController {
  RxMap<String, dynamic> userMap = <String, dynamic>{}.obs;
  RxMap<String, dynamic> userGoalDataMap = <String, dynamic>{}.obs;

  @override
  void onInit() {
    super.onInit();
    checkSession();
  }

  Future<void> getFCMToken() async {
    debugPrint('🔔 getFCMToken() called');

    try {
      String? token = await FirebaseMessaging.instance.getToken();

      debugPrint('📱 Raw FCM Token: $token');

      if (token != null && token.isNotEmpty) {
        debugPrint('✅ FCM token is valid, sending to server...');
        await sendFCMTokenToServer(token);
      } else {
        debugPrint('⚠️ FCM token is null or empty');
      }

      return;
    } catch (e, stack) {
      debugPrint('❌ Error while fetching FCM token');
      debugPrint('Error: $e');
      debugPrint('StackTrace: $stack');
      return;
    }
  }

  Future<void> sendFCMTokenToServer(String token) async {
    debugPrint('🚀 sendFCMTokenToServer() called');
    debugPrint('📦 Token being sent: $token');

    try {
      final payload = {'Value': token};

      debugPrint('📤 Request payload: $payload');
      debugPrint('🌐 API endpoint: $fcmTokenApi');

      final response = await ApiService.post(
        fcmTokenApi,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      debugPrint('📥 Raw API response: $response');

      if (response is http.Response) {
        debugPrint('❌ HTTP error response');
        debugPrint('Status code: ${response.statusCode}');
        debugPrint('Body: ${response.body}');

        CustomSnackbar.showError(
          context: Get.context!,
          title: 'Error',
          message: 'Failed to send token: ${response.statusCode}',
        );
        return;
      }

      final responseData = jsonDecode(jsonEncode(response));
      debugPrint('✅ Parsed API response: $responseData');
    } catch (e, stack) {
      debugPrint('❌ Exception while sending FCM token');
      debugPrint('Error: $e');
      debugPrint('StackTrace: $stack');

      CustomSnackbar.showError(
        context: Get.context!,
        title: 'Error',
        message: 'Failed to send token: $e',
      );
    }
  }

  Future<void> checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (token == null) {
        Get.offAll(() => SignInScreen());
      }
    });
    await reloadUserMap();
  }

  Future<void> reloadUserMap() async {
    final prefs = await SharedPreferences.getInstance();
    final userdataString = prefs.getString('userdata');
    final userGoaldataString = prefs.getString('userGoaldata');

    userMap.value = _safeDecode(userdataString);

    userGoalDataMap.value = _safeDecode(userGoaldataString);

    userMap['Height'] ??= {'Value': null};
    userMap['Weight'] ??= {'Value': null};

    debugPrint("✅ userMap loaded: ${userMap.value}");
    debugPrint("✅ userGoalDataMap loaded: ${userGoalDataMap.value}");
  }

  Map<String, dynamic> _safeDecode(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return {};
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  /// 🚀 Helper getter to avoid null access anywhere
  dynamic getValue(String key) => userMap[key] ?? "";

  dynamic getGoalValue(String key) => userGoalDataMap[key] ?? "";
}
