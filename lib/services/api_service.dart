import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:snevva/common/debug_logger.dart';
import 'package:snevva/common/global_variables.dart';
import 'package:snevva/services/auth_service.dart';
import 'package:snevva/services/device_token_service.dart';
import 'package:snevva/services/encryption_service.dart';

import '../env/env.dart';
import 'auth_header_helper.dart';

class ApiException implements Exception {
  final int statusCode;
  final String endpoint;
  final String? decryptedBody;
  final String rawBody;
  final String? message;

  const ApiException({
    required this.statusCode,
    required this.endpoint,
    required this.rawBody,
    this.decryptedBody,
    this.message,
  });

  @override
  String toString() {
    final detail = message ?? decryptedBody ?? rawBody;
    return 'HTTP $statusCode ($endpoint): $detail';
  }
}

class ApiService {
  static const String _baseUrl = baseUrl;

  static dynamic _normalizePayloadForApi(dynamic value, {String? parentKey}) {
    if (value is List) {
      return value
          .map((item) => _normalizePayloadForApi(item, parentKey: parentKey))
          .toList();
    }

    if (value is Map) {
      final normalized = <String, dynamic>{};
      value.forEach((key, item) {
        final keyString = key.toString();
        final normalizedItem = _normalizePayloadForApi(
          item,
          parentKey: keyString,
        );

        if (parentKey != null &&
            parentKey.toLowerCase() == 'timesperday' &&
            keyString.toLowerCase() == 'count' &&
            normalizedItem != null) {
          normalized[keyString] = normalizedItem.toString();
        } else {
          normalized[keyString] = normalizedItem;
        }
      });
      return normalized;
    }

    return value;
  }

  static Future<Object> post(
    String endpoint,
    Map<String, dynamic>? plainBody, {
    bool withAuth = false,
    bool encryptionRequired = true,
  }) async {
    final headers = await AuthHeaderHelper.getHeaders(withAuth: withAuth);
    final uri = Uri.parse("$_baseUrl$endpoint");
    if (kDebugMode) {
      debugPrint("🔗 API Request: POST $uri");
    }

    if (encryptionRequired && plainBody != null) {
      final normalizedBody =
          _normalizePayloadForApi(plainBody) as Map<String, dynamic>;
      final jsonString = jsonEncode(normalizedBody);
      final encrypted = EncryptionService.encryptData(jsonString);

      headers['x-data-hash'] = encrypted['Hash'] ?? '';

      final deviceInfoHeader =
          await DeviceTokenService().buildDeviceInfoHeader();
      headers['X-Device-Info'] = deviceInfoHeader;
      if (kDebugMode) {
        logLong("headers", headers.toString());
      }

      final encryptedRequestBody = jsonEncode({
        'data': encrypted['encryptedData'],
      });
      if (kDebugMode) {
        debugPrint("encryptedRequestBody, $encryptedRequestBody");
      }

      final response = await http.post(
        uri,
        headers: headers,
        body: encryptedRequestBody,
      );

      if (response.statusCode == 401 || response.statusCode == 403) {
        await AuthService.forceLogout();
        throw ApiException(
          statusCode: response.statusCode,
          endpoint: endpoint,
          rawBody: response.body,
          message: 'Unauthorized',
        );
      }

      if (response.statusCode >= 400) {
        _handleErrors(response, endpoint);
      }

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final encryptedBody = responseBody['data'];

        final responseHash = response.headers['x-data-hash'];
        if (responseHash == null) {
          throw ApiException(
            statusCode: response.statusCode,
            endpoint: endpoint,
            rawBody: response.body,
            message: 'Missing x-data-hash header',
          );
        }

        final decrypted = EncryptionService.decryptData(
          encryptedBody,
          responseHash,
        );
        if (kDebugMode) {
          logLong("Decrypted", decrypted ?? '');
        }

        if (decrypted == null) {
          throw ApiException(
            statusCode: response.statusCode,
            endpoint: endpoint,
            rawBody: response.body,
            message: 'Failed to decrypt response',
          );
        }

        return jsonDecode(decrypted);
      }

      return response;
    } else {
      String? bodyPayload;
      if (plainBody != null) {
        final normalizedBody =
            _normalizePayloadForApi(plainBody) as Map<String, dynamic>;
        bodyPayload = jsonEncode(normalizedBody);
      }

      if (kDebugMode) {
        debugPrint("bodyPayload $bodyPayload");
      }

      final deviceInfoHeader =
          await DeviceTokenService().buildDeviceInfoHeader();
      headers['X-Device-Info'] = deviceInfoHeader;

      if (kDebugMode) {
        debugPrint("headers ${headers.toString()}");
      }

      final response = await http.post(
        uri,
        headers: headers,
        body: bodyPayload,
      );
      if (response.statusCode == 401 || response.statusCode == 403) {
        await AuthService.forceLogout();
        throw ApiException(
          statusCode: response.statusCode,
          endpoint: endpoint,
          rawBody: response.body,
          message: 'Unauthorized',
        );
      }

      if (response.statusCode >= 400) {
        _handleErrors(response, endpoint);
      }

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final encryptedBody = responseBody['data'];

        final responseHash = response.headers['x-data-hash'];
        if (responseHash == null) {
          throw ApiException(
            statusCode: response.statusCode,
            endpoint: endpoint,
            rawBody: response.body,
            message: 'Missing x-data-hash header',
          );
        }

        final decrypted = EncryptionService.decryptData(
          encryptedBody,
          responseHash,
        );

        if (kDebugMode) {
          logLong("Decrypted", decrypted ?? '');
        }

        if (decrypted == null) {
          throw ApiException(
            statusCode: response.statusCode,
            endpoint: endpoint,
            rawBody: response.body,
            message: 'Failed to decrypt response',
          );
        }

        return jsonDecode(decrypted);
      }
      return response;
    }
  }

  static void _handleErrors(http.Response response, String endpoint) {
    if (response.statusCode >= 400) {
      String? decrypted;
      String? message;
      try {
        final decoded = jsonDecode(response.body);

        if (decoded is Map && decoded['data'] != null) {
          final responseHash = response.headers['x-data-hash'];
          final dataValue = decoded['data'];
          if (responseHash != null && responseHash.isNotEmpty) {
            decrypted = EncryptionService.decryptData(dataValue, responseHash);
            message = decrypted;
          } else {
            // Some endpoints return a plaintext `data` field on errors.
            message = dataValue?.toString();
          }
        } else if (decoded is Map) {
          final candidate = decoded['message'] ?? decoded['error'];
          if (candidate != null) {
            message = candidate.toString();
          }
        }
      } catch (_) {
        // ignore JSON parse failures; fall back to raw body
      }

      DebugLogger().log(
        '❌ API ERROR [$endpoint]: ${message ?? decrypted ?? response.body}',
        type: 'API',
      );

      throw ApiException(
        statusCode: response.statusCode,
        endpoint: endpoint,
        rawBody: response.body,
        decryptedBody: decrypted,
        message: message,
      );
    }
  }
}
