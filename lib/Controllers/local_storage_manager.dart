import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/device_token_service.dart';

class LocalStorageManager extends GetxService {
  RxMap<String, dynamic> userMap = <String, dynamic>{}.obs;
  bool _sessionChecked = false;

  RxMap<String, dynamic> userGoalDataMap = <String, dynamic>{}.obs;

  final DeviceTokenService _deviceTokenService = DeviceTokenService();

  @override
  void onInit() {
    super.onInit();
    reloadUserMap();
    loadProfilePicture();
  }

  Future<void> loadProfilePicture() async {
    final String? cdnUrl = userMap['ProfilePicture']?['CdnUrl'];

    String profilePictureUrl = 'https://$cdnUrl';
    if (profilePictureUrl.isNotEmpty) {
      try {
        // Preload the image to cache it
        await precacheImage(
          CachedNetworkImageProvider(profilePictureUrl),
          Get.context!,
        );
      } catch (e) {
        debugPrint('Error preloading profile picture: $e');
      }
    }
  }
  // // Optional: use this if you need async init
  // @override
  // Future<void> onReady() async {
  //   await reloadUserMap();
  // }

  Future<bool> hasValidSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    debugPrint("hasValidSession $token");
    return token != null && token.isNotEmpty;
  }

  /// ✅ Call this AFTER login success
  Future<void> registerDeviceFCMIfNeeded() async {
    await _deviceTokenService.handleDeviceRegistration();
  }

  // Future<void> checkSession() async {
  //   if (_sessionChecked) return;
  //   _sessionChecked = true;
  //
  //   final prefs = await SharedPreferences.getInstance();
  //   final token = prefs.getString('auth_token');
  //
  //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //     if (token == null) {
  //       Get.offAll(() => SignInScreen());
  //     }
  //   });
  //
  //   await reloadUserMap();
  // }

  Future<void> reloadUserMap() async {
    final prefs = await SharedPreferences.getInstance();

    userMap.value = _safeDecode(prefs.getString('userdata'));
    userGoalDataMap.value = _safeDecode(prefs.getString('userGoaldata'));

    userMap['HeightData']?['Value'] ??= {'Value': null};
    userMap['WeightData']?['Value'] ??= {'Value': null};
  }

  Map<String, dynamic> _safeDecode(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return {};
    try {
      final decoded = jsonDecode(jsonStr);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return {};
    }
  }

  dynamic getValue(String key) => userMap[key] ?? "";
  dynamic getGoalValue(String key) => userGoalDataMap[key] ?? "";
}
