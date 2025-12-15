import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:snevva/env/env.dart';

class AuthService {
  Future<String> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      return data['token'];
    } else {
      throw Exception('Failed to login: ${response.body}');
    }
  }

  Future<void> logout() async {
    final response = await http.post(
      Uri.parse('$baseUrl/logout'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to logout: ${response.body}');
    }
  }
}
