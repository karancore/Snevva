import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'dart:math';
import 'consts/consts.dart';

Future<AccessCredentials> _getAccessToken() async {
  final serviceAccountPath = dotenv.env['PATH_TO_SECRET'];

  String serviceAccountJson = await rootBundle.loadString(serviceAccountPath!);

  // debugPrint("json: $serviceAccountJson");
  final serviceAccount = ServiceAccountCredentials.fromJson(serviceAccountJson);

  final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

  final client = await clientViaServiceAccount(serviceAccount, scopes);
  return client.credentials;
}

Future<bool> sendPushNotification({
  required String deviceToken,
  required String title,
  required String body,
  Map<String, dynamic>? data,
}) async {
  if (deviceToken.isEmpty) return false;

  final credentials = await _getAccessToken();
  final accessToken = credentials.accessToken.data;
  final projectId = dotenv.env['PROJECT_ID'];

  print("accessToken: $dotenv.env['PROJECT_ID']");

  final url = Uri.parse(
    'https://fcm.googleapis.com/v1/projects/$projectId/messages:send',
  );

  final message = {
    'message': {
      'token': deviceToken,
      'notification': {'title': title, 'body': body},
      'data': data ?? {},
    },
  };

  final response = await http.post(
    url,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    },
    body: jsonEncode(message),
  );

  if (response.statusCode == 200) {
    print('Notification sent successfully.');
    return true;
  } else {
    print('Failed to send notification: ${response.body}');
    return false;
  }
}

Future<void> logFcmToken() async {
  try {
    final fcmToken = await FirebaseMessaging.instance.getToken();
    debugPrint('🔥 FCM TOKEN: $fcmToken');

    // Listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      debugPrint('🔄 FCM TOKEN REFRESHED: $newToken');
    });
  } catch (e) {
    debugPrint('❌ Failed to get FCM token: $e');
  }
}
