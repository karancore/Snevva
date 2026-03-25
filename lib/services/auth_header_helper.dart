import 'package:shared_preferences/shared_preferences.dart';

class AuthHeaderHelper {
  static Future<Map<String, String>> getHeaders({bool withAuth = false}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (withAuth) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
        // debugPrint("👉 Using Bearer Token: $token"); // Debug
      } else {
        // debugPrint("❌ No token found in SharedPreferences");
      }
    }

    return headers;
  }
}
