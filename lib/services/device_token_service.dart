import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../env/env.dart';

class DeviceTokenService {
  /// ✅ Get stable device ID
  Future<String> getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = await deviceInfo.androidInfo;
      return android.id ?? "unknown_android";
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = await deviceInfo.iosInfo;
      return ios.identifierForVendor ?? "unknown_ios";
    }

    return "unknown_device";
  }

  /// ✅ Register device token
  Future<bool> registerDeviceToken({
    required String fcmToken,
    required String deviceId,
  }) async {
    final payload = {
      "FCMToken": fcmToken,
      "DeviceInfo": deviceId,
    };

    final response = await ApiService.post(
      fcmTokenApi,
      payload,
      withAuth: true,
      encryptionRequired: true,
    );

    return _isSuccess(response);
  }

  /// ✅ Change device (logout old one)
  Future<bool> changeDeviceToken({
    required String newDeviceId,
    required String oldDeviceId,
    required String fcmToken,
  }) async {
    final payload = {
      "DeviceInfo": newDeviceId,
      "FCMToken": fcmToken,
      "OldDeviceInfoId": oldDeviceId,
    };

    final response = await ApiService.post(
      changeDeviceApi,
      payload,
      withAuth: true,
      encryptionRequired: true,
    );

    return _isSuccess(response);
  }

  /// ✅ Unified response check
  bool _isSuccess(dynamic response) {
    try {
      final decoded = jsonDecode(jsonEncode(response));
      return decoded['status'] == true;
    } catch (_) {
      return false;
    }
  }

  /// ✅ Main entry point (call after login)
  Future<void> handleDeviceRegistration() async {
    final prefs = await SharedPreferences.getInstance();

    final currentDeviceId = await getDeviceId();
    final storedDeviceId = prefs.getString('device_id');

    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken == null || fcmToken.isEmpty) return;

    // First login
    if (storedDeviceId == null) {
      final success = await registerDeviceToken(
        fcmToken: fcmToken,
        deviceId: currentDeviceId,
      );

      if (success) {
        await _persist(prefs, currentDeviceId, fcmToken);
      }
      return;
    }

    // Same device → skip
    if (storedDeviceId == currentDeviceId) {
      debugPrint("✅ Same device, skipping registration");
      return;
    }

    // Different device → update backend
    final success = await changeDeviceToken(
      newDeviceId: currentDeviceId,
      oldDeviceId: storedDeviceId,
      fcmToken: fcmToken,
    );

    if (success) {
      await _persist(prefs, currentDeviceId, fcmToken);
    }
  }

  Future<void> _persist(
    SharedPreferences prefs,
    String deviceId,
    String fcmToken,
  ) async {
    await prefs.setString('device_id', deviceId);
    await prefs.setString('fcm_token', fcmToken);
  }
}
