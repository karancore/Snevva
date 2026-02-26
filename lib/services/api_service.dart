import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:snevva/common/debug_logger.dart';
import 'package:snevva/common/global_variables.dart';
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
    final headers = await AuthHeaderHelper.getHeaders(withAuth: withAuth);
    final uri = Uri.parse("$_baseUrl$endpoint");
    print("🔗 API Request: POST $uri");

    if (encryptionRequired && plainBody != null) {
      final jsonString = jsonEncode(plainBody);
      final encrypted = EncryptionService.encryptData(jsonString);

      headers['x-data-hash'] = encrypted['Hash'] ?? '';

      final deviceInfoHeader =
          await DeviceTokenService().buildDeviceInfoHeader();
      headers['X-Device-Info'] = deviceInfoHeader;
      debugPrint("headers ${headers.toString()}");

      final encryptedRequestBody = jsonEncode({
        'data': encrypted['encryptedData'],
      });
      debugPrint("encryptedRequestBody, $encryptedRequestBody");

      final response = await http.post(
        uri,
        headers: headers,
        body: encryptedRequestBody,
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final encryptedBody = responseBody['data'];

        final responseHash = response.headers['x-data-hash'];
        if (responseHash == null) {
          throw Exception('Missing x-data-hash header');
        }

        final decrypted = EncryptionService.decryptData(
          encryptedBody,
          responseHash,
        );
        logLong("Decrypted", decrypted ?? '');

        if (decrypted == null) {
          throw Exception('Failed to decrypt response');
        }

        return jsonDecode(decrypted);
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await AuthService.forceLogout();
        throw Exception('Unauthorized');
      } else {
        _handleErrors(response, endpoint);
        return response;
      }
    } else {
      String? bodyPayload;
      if (plainBody != null) bodyPayload = jsonEncode(plainBody);

      print("bodyPayload $bodyPayload");

      final deviceInfoHeader =
          await DeviceTokenService().buildDeviceInfoHeader();
      headers['X-Device-Info'] = deviceInfoHeader;

      print("headers ${headers.toString()}");

      final response = await http.post(
        uri,
        headers: headers,
        body: bodyPayload,
      );
      _handleErrors(response, endpoint);

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final encryptedBody = responseBody['data'];

        final responseHash = response.headers['x-data-hash'];
        if (responseHash == null) {
          throw Exception('Missing x-data-hash header');
        }

        final decrypted = EncryptionService.decryptData(
          encryptedBody,
          responseHash,
        );

        logLong("Decrypted", decrypted ?? '');

        return jsonDecode(decrypted!);
      }
      return response;
    }
  }

  static void _handleErrors(http.Response response, String endpoint) {
    if (response.statusCode >= 400) {
      try {
        final body = jsonDecode(response.body);

        if (body['data'] != null) {
          final responseHash = response.headers['x-data-hash'];
          final decrypted = EncryptionService.decryptData(
            body['data'],
            responseHash ?? '',
          );

          DebugLogger().log('❌ API ERROR [$endpoint]: $decrypted', type: 'API');

          throw Exception('HTTP ${response.statusCode}: $decrypted');
        }
      } catch (e) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    }
  }
}
