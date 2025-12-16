import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:snevva/services/encryption_service.dart';
import '../env/env.dart';
import 'auth_header_helper.dart';

class ApiService {
  static const String _baseUrl = baseUrl;

  static Future<Object> post(
    String endpoint,
    Map<String, dynamic>? plainBody, {
    bool withAuth = false,
    bool encryptionRequired = true,
  }) async {
    final headers = await AuthHeaderHelper.getHeaders(withAuth: withAuth);
    final uri = Uri.parse("$_baseUrl$endpoint");

    // print(uri);

    if (encryptionRequired && plainBody != null) {
      // 🔐 Step 1: Encode Map to JSON string
      final jsonString = jsonEncode(plainBody);

      // print(jsonString);

      // 🔐 Step 2: Encrypt JSON string
      final encrypted = EncryptionService.encryptData(jsonString);

      // 🔐 Step 3: Set hash header
      headers['X-Data-Hash'] = encrypted['hash']!;

      // 🔐 Step 4: Prepare encrypted request body
      final encryptedBody = jsonEncode({'data': encrypted['encryptedData']});

      // 🔐 Step 5: Send encrypted POST request
      final response = await http.post(
        uri,
        headers: headers,
        body: encryptedBody,
      );
      print(response.body);
      _handleErrors(response);

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final encryptedBody = responseBody['data'];
        print(encryptedBody);
        final responseHash = response.headers['x-data-hash'];
        print(responseHash);

        // 🔐 Step 6: Decrypt response
        final decrypted = EncryptionService.decryptData(
          encryptedBody,
          responseHash!,
        );
        final Map<String, dynamic> responseData = jsonDecode(decrypted!);

        // print(responseData);

        return responseData;
      } else {
        return response;
      }
    } else {
      String? bodyPayload;
      if (plainBody != null) {
        bodyPayload = jsonEncode(plainBody);
      }

      // 🔓 No encryption — send regular POST
      final response = await http.post(
        uri,
        headers: headers,
        body: bodyPayload,
      );

      _handleErrors(response);
      if (response.statusCode == 200) {
        // print("👉1");

        final responseBody = jsonDecode(response.body);
        final encryptedBody = responseBody['data'];
        final responseHash = response.headers['x-data-hash'];

        // 🔐 Step 6: Decrypt response
        final decrypted = EncryptionService.decryptData(
          encryptedBody,
          responseHash!,
        );
        // print("$decrypted");
        final Map<String, dynamic> responseData = jsonDecode(decrypted!);
        // print("$responseData");

        return responseData;
      }
      return response;
    }
  }

  static void _handleErrors(http.Response response) {
    if (response.statusCode >= 400) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }
}
