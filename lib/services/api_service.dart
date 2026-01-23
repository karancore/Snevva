import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:snevva/common/debug_logger.dart';
import 'package:snevva/services/auth_service.dart';
import 'package:snevva/services/device_token_service.dart';
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
    // Get base headers
    final headers = await AuthHeaderHelper.getHeaders(withAuth: withAuth);

    final uri = Uri.parse("$_baseUrl$endpoint");

    if (encryptionRequired && plainBody != null) {
      final jsonString = jsonEncode(plainBody);
      final encrypted = EncryptionService.encryptData(jsonString);

      headers['X-Data-Hash'] = encrypted['hash']!;
      final encryptedBody = jsonEncode({'data': encrypted['encryptedData']});

      final extraHeaders = await DeviceTokenService().buildDeviceInfoHeader();

      print("APIService Header $extraHeaders");

      headers['X-Device-Info'] = extraHeaders;
    
      final response = await http.post(
        uri,
        headers: headers,
        body: encryptedBody,
      );

      // _handleErrors(response);

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final encryptedBody = responseBody['data'];
        final responseHash = response.headers['x-data-hash']!;

        final decrypted = EncryptionService.decryptData(
          encryptedBody,
          responseHash,
        );
        final Map<String, dynamic> responseData = jsonDecode(decrypted!);

        // DebugLogger().log(
        //   "⬅️ API RESPONSE [$endpoint]: $responseData",
        //   type: "API",
        // );

        return responseData;
      }
      // else if (response.statusCode == 401 || response.statusCode == 403) {
      //   // Handle unauthorized access
      //   await AuthService.forceLogout();
      //   throw Exception("Unauthorized");
      // }

      else {
        _handleErrors(response, endpoint);
        return response;
      }
    } else {
      String? bodyPayload;
      if (plainBody != null) bodyPayload = jsonEncode(plainBody);

      final response = await http.post(
        uri,
        headers: headers,
        body: bodyPayload,
      );

      _handleErrors(response, endpoint);

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final encryptedBody = responseBody['data'];
        final responseHash = response.headers['x-data-hash']!;

        final decrypted = EncryptionService.decryptData(
          encryptedBody,
          responseHash,
        );
        final Map<String, dynamic> responseData = jsonDecode(decrypted!);
        // DebugLogger().log(
        //   "⬅️ API RESPONSE [$endpoint]: $responseData",
        //   type: "API",
        // );

        return responseData;
      }
      return response;
    }
  }

  static void _handleErrors(http.Response response, String endpoint) {
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

          DebugLogger().log("🔐 Error response [$endpoint]: $decrypted", type: "API");

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
