import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../env/env.dart';

class DeviceTokenService {
  /// ✅ Get stable device ID
  // Future<String> getDeviceId() async {
  //   final deviceInfo = DeviceInfoPlugin();

  //   if (defaultTargetPlatform == TargetPlatform.android) {
  //     final android = await deviceInfo.androidInfo;
  //     return android.id ?? "unknown_android";
  //   }

  //   if (defaultTargetPlatform == TargetPlatform.iOS) {
  //     final ios = await deviceInfo.iosInfo;
  //     return ios.identifierForVendor ?? "unknown_ios";
  //   }

  //   return "unknown_device";
  // }

  Map<String, dynamic> decodeDeviceInfoHeader(String? encodedHeader) {
  if (encodedHeader == null || encodedHeader.isEmpty) {
    return {};
  }

  try {
    final decodedBytes = base64Decode(encodedHeader);
    final decodedString = utf8.decode(decodedBytes);
    return jsonDecode(decodedString) as Map<String, dynamic>;
  } catch (e) {
    debugPrint("DeviceInfo decode failed: $e");
    return {};
  }
}


  

// Future<String> buildDeviceInfoHeader() async {
//   final deviceHeaders = await getDeviceHeaders();
//
//   final jsonString = jsonEncode(deviceHeaders);
//
//   // Optional but recommended (safe for headers)
//   return base64Encode(utf8.encode(jsonString));
// }

  // Future<String> buildDeviceInfoHeader() async {
  //   final deviceInfo = await getDeviceHeaders();
  //
  //   final fingerprint = [
  //     deviceInfo['platform'],
  //     deviceInfo['brand'],
  //     deviceInfo['model'],
  //     deviceInfo['hardware'],
  //   ].join('|');
  //
  //   return fingerprint; // 👈 plain string, no Base64, no JSON
  // }

  Future<String> buildDeviceInfoHeader() async {
    final deviceHeaders = await getDeviceHeaders();
    return base64Encode(utf8.encode(jsonEncode(deviceHeaders)));
  }


  Future<Map<String, String>> getDeviceHeaders() async {
  final deviceInfo = DeviceInfoPlugin();

  if (defaultTargetPlatform == TargetPlatform.android) {
    final android = await deviceInfo.androidInfo;
    return {
      "platform": "android",
      "brand": android.brand ?? "unknown",
      "model": android.model ?? "unknown",
      "device": android.device ?? "unknown",
      "product": android.product ?? "unknown",
      "hardware": android.hardware ?? "unknown",
      "physical": (android.isPhysicalDevice ?? false).toString(),
      "abi": (android.supportedAbis.isNotEmpty ? android.supportedAbis.first : "unknown"),
      "androidVersion": android.version.release ?? "unknown",
      "sdkInt": android.version.sdkInt.toString(),
      "securityPatch": android.version.securityPatch ?? "unknown",
      "lowRam": (android.isLowRamDevice ?? false).toString(),
    };
  }

  if (defaultTargetPlatform == TargetPlatform.iOS) {
    final ios = await deviceInfo.iosInfo;
    return {
      "platform": "ios",
      "brand": "apple",
      "model": ios.utsname.machine ?? "unknown",
      "device": ios.name ?? "unknown",
      "product": ios.model ?? "unknown",
      "hardware": ios.utsname.machine ?? "unknown",
      "physical": (ios.isPhysicalDevice ?? false).toString(),
      "abi": "arm64", // iOS default
      "iosVersion": ios.systemVersion ?? "unknown",
      "securityPatch": "unknown",
      "lowRam": "false",
    };
  }

  return {"platform": "unknown"};
}


  /// ✅ Register device token
  Future<bool> registerDeviceToken({
    required String fcmToken,
  }) async {
    final payload = {
      "FCMToken": fcmToken,
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
  // Future<bool> changeDeviceToken({
  //   required String newDeviceId,
  //   required String oldDeviceId,
  //   required String fcmToken,
  // }) async {
  //   final payload = {
  //     "DeviceInfo": newDeviceId,
  //     "FCMToken": fcmToken,
  //     "OldDeviceInfoId": oldDeviceId,
  //   };

  //   final response = await ApiService.post(
  //     changeDeviceApi,
  //     payload,
  //     withAuth: true,
  //     encryptionRequired: true,
  //   );

  //   return _isSuccess(response);
  // }

  /// ✅ Unified response check
  bool _isSuccess(dynamic response) {
    try {
      final decoded = jsonDecode(jsonEncode(response));
      return decoded['status'] == true;
    } catch (_) {
      return false;
    }
  }

  // ✅ Main entry point (call after login)
  Future<void> handleDeviceRegistration() async {
    final prefs = await SharedPreferences.getInstance();

    // final currentDeviceId = await getDeviceId();
    // final storedDeviceId = prefs.getString('device_id');

    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken == null || fcmToken.isEmpty) return;

    // First login
    // if (storedDeviceId == null) {
      final success = await registerDeviceToken(
        fcmToken: fcmToken,
      );

      if (success) {
        await _persist(prefs, fcmToken);
      }
      return;
    }

    // // Same device → skip
    // if (storedDeviceId == currentDeviceId) {
    //   debugPrint("✅ Same device, skipping registration");
    //   return;
    // }

    // // Different device → update backend
    // final success = await changeDeviceToken(
    //   newDeviceId: currentDeviceId,
    //   oldDeviceId: storedDeviceId,
    //   fcmToken: fcmToken,
    // );

    // if (success) {
    //   await _persist(prefs, currentDeviceId, fcmToken);
    // }
  // }

  Future<void> _persist(
    SharedPreferences prefs,
    String fcmToken,
  ) async {
    // await prefs.setString('device_id', deviceId);
    await prefs.setString('fcm_token', fcmToken);
  }
}
