import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:snevva/services/encryption_service.dart';
import '../consts/consts.dart';
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

    // debugPrint(uri);

    if (encryptionRequired && plainBody != null) {
      // 🔐 Step 1: Encode Map to JSON string
      final jsonString = jsonEncode(plainBody);

      // debugPrint(jsonString);

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
      debugPrint(response.body);
      _handleErrors(response);

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final encryptedBody = responseBody['data'];
        debugPrint(encryptedBody);
        final responseHash = response.headers['x-data-hash'];
        debugPrint(responseHash);

        // 🔐 Step 6: Decrypt response
        final decrypted = EncryptionService.decryptData(
          encryptedBody,
          responseHash!,
        );
        final Map<String, dynamic> responseData = jsonDecode(decrypted!);

        // debugPrint(responseData);

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
        // debugPrint("👉1");

        final responseBody = jsonDecode(response.body);
        final encryptedBody = responseBody['data'];
        final responseHash = response.headers['x-data-hash'];

        // 🔐 Step 6: Decrypt response
        final decrypted = EncryptionService.decryptData(
          encryptedBody,
          responseHash!,
        );
        // debugPrint("$decrypted");
        final Map<String, dynamic> responseData = jsonDecode(decrypted!);
        // debugPrint("$responseData");

        return responseData;
      }
      return response;
    }
  }

  static void _handleErrors(http.Response response) {
    debugPrint('🔍 _handleErrors called');
    debugPrint('➡️ Status code: ${response.statusCode}');
    debugPrint('➡️ Headers: ${response.headers}');
    debugPrint('➡️ Raw body: ${response.body}');

    if (response.statusCode >= 400) {
      debugPrint('⚠️ Error response detected');

      try {
        debugPrint('🧩 Attempting JSON decode...');
        final body = jsonDecode(response.body);
        debugPrint('✅ JSON decoded: $body');

        if (body['data'] != null) {
          debugPrint('🔐 Encrypted data found');
          debugPrint('➡️ Encrypted payload: ${body['data']}');
          debugPrint(
            '➡️ x-data-hash header: ${response.headers['x-data-hash']}',
          );

          final decrypted = EncryptionService.decryptData(
            body['data'],
            response.headers['x-data-hash']!,
          );

          debugPrint('✅ Decrypted error message: $decrypted');

          throw Exception('HTTP ${response.statusCode}: $decrypted');
        } else {
          debugPrint('ℹ️ No "data" field in response body');
        }
      } catch (e, stack) {
        debugPrint('❌ Error while handling HTTP error');
        debugPrint('➡️ Exception: $e');
        debugPrint('➡️ StackTrace: $stack');

        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } else {
      debugPrint('✅ Response OK, no error handling needed');
    }
  }
}
