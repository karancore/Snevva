import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/device_token_service.dart';

class LocalStorageManager extends GetxService {
  static const String userGoalDataPrefsKey = 'userGoaldata';
  static const List<String> legacyUserGoalDataPrefsKeys = [
    'userGoalDataMap',
    'useractivedata',
  ];

  RxMap<String, dynamic> userMap = <String, dynamic>{}.obs;

  RxMap<String, dynamic> userGoalDataMap = <String, dynamic>{}.obs;

  final DeviceTokenService _deviceTokenService = DeviceTokenService();

  @override
  void onInit() {
    super.onInit();
    // ✅ Load user map first, then attempt to precache profile picture.
    // Calling loadProfilePicture() before reloadUserMap() completes causes
    // the 'https://null' precache crash (ProfilePicture not yet in map).
    reloadUserMap().then((_) => loadProfilePicture());
  }

  Future<void> loadProfilePicture() async {
    final String? cdnUrl = userMap['ProfilePicture']?['CdnUrl']?.toString();
    final trimmedCdnUrl = cdnUrl?.trim();

    if (trimmedCdnUrl == null ||
        trimmedCdnUrl.isEmpty ||
        trimmedCdnUrl.toLowerCase() == 'null') {
      return;
    }

    final context = Get.context;
    if (context == null) return;

    final profilePictureUrl =
        trimmedCdnUrl.startsWith('http')
            ? trimmedCdnUrl
            : 'https://$trimmedCdnUrl';
    try {
      await precacheImage(
        CachedNetworkImageProvider(profilePictureUrl),
        context,
      );
    } catch (e) {
      debugPrint('Error preloading profile picture: $e');
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

  // In LocalStorageManager
  Future<void> updateUserField(String key, dynamic value) async {
    userMap[key] = value;
    await saveUserMap();
  }

  Future<void> updateGoalField(String key, dynamic value) async {
    userGoalDataMap[key] = value;
    await saveUserGoalMap();
  }

  /// ✅ Call this AFTER login success
  Future<void> registerDeviceFCMIfNeeded() async {
    await _deviceTokenService.handleDeviceRegistration();
  }

  Future<void> saveUserMap() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('userdata', jsonEncode(userMap));

    userMap.refresh();
  }

  Future<void> saveUserGoalMap() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(userGoalDataPrefsKey, jsonEncode(userGoalDataMap));

    userGoalDataMap.refresh();
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
    userGoalDataMap.value = _safeDecode(_readUserGoalDataJson(prefs));

    userMap['HeightData']?['Value'] ??= {'Value': null};
    userMap['Email'] ??= '';
    userMap['PhoneNumber'] ??= '';
    userMap['Name'] ??= '';
    userMap['AddressByUser'] ??= '';

    userMap['OccupationData']?['Name'] ??= {'Name': null};

    userMap['WeightData']?['Value'] ??= {'Value': null};
  }

  String? _readUserGoalDataJson(SharedPreferences prefs) {
    final current = prefs.getString(userGoalDataPrefsKey);
    if (current != null && current.isNotEmpty) return current;

    for (final key in legacyUserGoalDataPrefsKeys) {
      final legacy = prefs.getString(key);
      if (legacy != null && legacy.isNotEmpty) return legacy;
    }

    return null;
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
