import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:snevva/Controllers/local_storage_manager.dart';
import 'package:snevva/Controllers/signupAndSignIn/sign_in_controller.dart';
import 'package:snevva/services/auth_service.dart';

import '../env/env.dart';
import 'api_service.dart';

class BackendAuthService extends GetxService {
  final AuthService _authService = AuthService();

  Future<void> handleGoogleBackendLogin(GoogleSignInAccount account) async {
    try {
      final GoogleSignInAuthentication auth = account.authentication;
      final String? idToken = auth.idToken;

      if (idToken == null) {
        debugPrint("❌ ID Token null");
        return;
      }

      final response = await ApiService.post(
        googleApi,
        {'AuthToken': idToken},
        withAuth: false,
        encryptionRequired: true,
      );

      if (response is http.Response) {
        Get.snackbar(
          'Sign-in Error',
          'Failed (${response.statusCode}). Please try again.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final result = jsonDecode(jsonEncode(response));
      final token = result['data'];

      if (token == null || token.toString().trim().isEmpty) {
        Get.snackbar(
          'Login Failed',
          'Could not retrieve session token.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      prefs.setString('auth_token', token.toString());

      final signInController = Get.find<SignInController>();
      await signInController.userInfo();

      await _authService.handleSuccessfulSignIn(
        emailOrPhone: account.email,
        prefs: await SharedPreferences.getInstance(),
        context: Get.context!,
        rememberMe: true,
      );

      // If the server returned no profile picture, use the Google account photo.
      // This runs after handleSuccessfulSignIn so userMap is fully populated.
      final photoUrl = account.photoUrl;
      if (photoUrl != null && photoUrl.isNotEmpty) {
        final localStorageManager = Get.find<LocalStorageManager>();
        final cdnUrl =
            localStorageManager.userMap['ProfilePicture']?['CdnUrl']
                ?.toString()
                .trim() ??
            '';
        if (cdnUrl.isEmpty) {
          final existing = Map<String, dynamic>.from(
            localStorageManager.userMap['ProfilePicture'] as Map? ?? {},
          );
          existing['CdnUrl'] = photoUrl;
          localStorageManager.userMap['ProfilePicture'] = existing;
          await localStorageManager.saveUserMap();
        }
      }
    } catch (e, stack) {
      debugPrint("🔥 Backend login failed: $e\n$stack");
    }
  }

  Future<void> handleAppleBackendLogin({
    required AuthorizationCredentialAppleID account,
  }) async {
    try {
      debugPrint("🍎 ===== Apple Backend Login Started =====");

      debugPrint("👤 User Identifier: ${account.userIdentifier}");
      debugPrint("📧 Email: ${account.email}");
      debugPrint("👤 Given Name: ${account.givenName}");
      debugPrint("👤 Family Name: ${account.familyName}");

      final String? idToken = account.identityToken;

      debugPrint("🎫 Identity Token Present: ${idToken != null}");
      if (idToken != null) {
        debugPrint(
          "🎫 Identity Token (first 50 chars): "
              "${idToken.substring(
              0, idToken.length > 50 ? 50 : idToken.length)}...",
        );
      }

      if (idToken == null || idToken.isEmpty) {
        debugPrint("❌ Apple Identity Token is null or empty");
        return;
      }

      debugPrint("📡 Calling backend API...");

      final response = await ApiService.post(
        googleApi,
        {
          'AuthToken': idToken,
        },
        withAuth: false,
        encryptionRequired: true,
      );

      debugPrint("📥 Backend response received.");

      if (response is http.Response) {
        debugPrint("❌ HTTP Error: ${response.statusCode}");
        debugPrint("Response Body: ${response.body}");

        Get.snackbar(
          'Sign-in Error',
          'Failed (${response.statusCode}). Please try again.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      debugPrint("✅ Raw Response: $response");

      final result = jsonDecode(jsonEncode(response));

      debugPrint("✅ Decoded Response: $result");

      final token = result['data'];

      debugPrint("🔑 Session Token: $token");

      if (token == null || token
          .toString()
          .trim()
          .isEmpty) {
        debugPrint("❌ Session token missing.");

        Get.snackbar(
          'Login Failed',
          'Could not retrieve session token.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('auth_token', token.toString());

      debugPrint("💾 Auth token saved to SharedPreferences.");

      final signInController = Get.find<SignInController>();

      debugPrint("👤 Fetching user info...");

      await signInController.userInfo();

      debugPrint("✅ User info fetched.");

      debugPrint("🚀 Calling handleSuccessfulSignIn...");

      await _authService.handleSuccessfulSignIn(
        emailOrPhone: account.email ?? '',
        prefs: prefs,
        context: Get.context!,
        rememberMe: true,
      );

      debugPrint("🎉 Apple Backend Login Completed Successfully.");
      debugPrint("🍎 ===== Apple Backend Login Finished =====");
    } catch (e, stack) {
      debugPrint("🔥 Apple Backend Login Exception: $e");
      debugPrint("📍 StackTrace:\n$stack");
    }
  }

}
