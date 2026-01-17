import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
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


  Future<String> getDeviceId() async {
    // Implementation for registering the device token
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    print('Device ID: ${androidInfo}'); 
    return androidInfo.id ?? "unknown_device_id";  
  }
  

  Future<bool> sendFCMTokenToServer(String fcmtoken, String deviceId) async {
    debugPrint('🚀 sendFCMTokenToServer() called');
    debugPrint('📦 Token being sent: $fcmtoken');

    try {
      final payload = {
        'FCMToken': fcmtoken,
        'DeviceInfo': deviceId,
        };

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
        return false;
      }

      final responseData = jsonDecode(jsonEncode(response));
      debugPrint('✅ Parsed API response: $responseData');

      return true;
    } catch (e, stack) {
      debugPrint('❌ Exception while sending FCM token');
      debugPrint('Error: $e');
      debugPrint('StackTrace: $stack');
      CustomSnackbar.showError(
        context: Get.context!,
        title: 'Error',
        message: 'Failed to send token: $e',
      );
      return false;
    }
  }

  Future<void> handleDeviceTokenRegistration() async {
  final prefs = await SharedPreferences.getInstance();

  final currentDeviceId = await getDeviceId();
  final storedDeviceId = prefs.getString('device_id');

  final fcmToken = await FirebaseMessaging.instance.getToken();
  if (fcmToken == null || fcmToken.isEmpty) return;

  // First-time login
  if (storedDeviceId == null) {
    final success = await sendFCMTokenToServer(fcmToken, currentDeviceId);
    if (success) {
      await prefs.setString('device_id', currentDeviceId);
      await prefs.setString('fcm_token', fcmToken);
    }
    return;
  }

  // Same device → do nothing
  if (storedDeviceId == currentDeviceId) {
    debugPrint("✅ Same device, no change needed");
    return;
  }

  // Different device → logout old device
  final success = await changeDeviceToken(
    currentDeviceId,
    storedDeviceId,
    fcmToken,
  );

  if (success) {
    await prefs.setString('device_id', currentDeviceId);
    await prefs.setString('fcm_token', fcmToken);
  }
}

  Future<bool> changeDeviceToken(String newDeviceId, String oldDeviceId, String fcmToken) async {
    debugPrint('🚀 changeDeviceToken() called');
    debugPrint('📦 New Device ID: $newDeviceId');
    debugPrint('📦 Old Device ID: $oldDeviceId');

    try {
      final payload = {
        'DeviceInfo': newDeviceId,
        'FCMToken': fcmToken,
        'OldDeviceInfoId': oldDeviceId,
      };

      debugPrint('📤 Request payload: $payload');
      debugPrint('🌐 API endpoint: $changeDeviceApi');

      final response = await ApiService.post(
        changeDeviceApi,
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
          message: 'Failed to change device: ${response.statusCode}',
        );
        return false;
      }

      final responseData = jsonDecode(jsonEncode(response));
      debugPrint('✅ Parsed API response: $responseData');

      return true;
    } catch (e, stack) {
      debugPrint('❌ Exception while changing device token');
      debugPrint('Error: $e');
      debugPrint('StackTrace: $stack');
      CustomSnackbar.showError(
        context: Get.context!,
        title: 'Error',
        message: 'Failed to change device: $e',
      );
      return false;
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
