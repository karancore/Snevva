import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../views/SignUp/sign_in_screen.dart';

class LocalStorageManager extends GetxController {
  RxMap<String, dynamic> userMap = <String, dynamic>{}.obs;
  RxMap<String, dynamic> userGoalDataMap = <String, dynamic>{}.obs;

  @override
  void onInit() {
    super.onInit();
    //checkSession();
  }

  Future<void> checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    Future.delayed(Duration.zero, () {
      if (token == null) {
        Get.offAll(SignInScreen());
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

    print("✅ userMap loaded: ${userMap.value}");
    print("✅ userGoalDataMap loaded: ${userGoalDataMap.value}");
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
