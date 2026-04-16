import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/common/global_variables.dart';
import 'package:snevva/services/auth_service.dart';

import '../common/custom_snackbar.dart';
import '../env/env.dart';
import 'api_service.dart';

class GoogleAuthService extends GetxService {
  final GoogleSignIn _google = GoogleSignIn.instance;
  final authService = AuthService();
  Rxn<GoogleSignInAccount> user = Rxn();
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authEventsSub;
  bool _initialized = false;

  // ---------------- INIT ----------------
  Future<bool> init(BuildContext context) async {
    if (_initialized) {
      debugPrint("ℹ️ Already initialized → retrying lightweight auth");

      try {
        await _google.attemptLightweightAuthentication();
      } catch (_) {}

      return user.value != null;
    }

    debugPrint("🔵 GoogleAuthService: init started");

    try {
      await _google.initialize(serverClientId: WEB);

      final completer = Completer<bool>();

      _authEventsSub = _google.authenticationEvents.listen(
            (event) async {
          if (event is GoogleSignInAuthenticationEventSignIn) {
            final account = event.user;

            user.value = account;

            await precacheImage(
              CachedNetworkImageProvider(account.photoUrl ?? ''),
              context,
            );

            await _handleBackendLogin(account, context, account.email);

            if (!completer.isCompleted) {
              completer.complete(true);
            }
          } else if (event is GoogleSignInAuthenticationEventSignOut) {
            user.value = null;
          }
        },
        onError: (_) {
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        },
      );

      await _google.attemptLightweightAuthentication();

      _initialized = true;

      return await completer.future
          .timeout(const Duration(seconds: 2), onTimeout: () => false);

    } catch (e) {
      debugPrint("❌ Init failed: $e");
      _initialized = false;
      return false;
    }
  }

  // ---------------- BUTTON LOGIN ----------------
  Future<void> signIn() async {
    if (user.value != null) {
      debugPrint("✅ Already signed in");
      return;
    }

    if (!_google.supportsAuthenticate()) return;

    try {
      await _google.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return;
      rethrow;
    }
  }

  // ---------------- BACKEND LOGIN ----------------
  Future<void> _handleBackendLogin(
    GoogleSignInAccount account,
    BuildContext context,
    String email,
  ) async {
    try {
      debugPrint("🔐 Fetching Google authentication tokens...");

      final GoogleSignInAuthentication auth = account.authentication;

      final String? idToken = auth.idToken;

      debugPrint("ID Token present: ${idToken != null}");

      logLong("ID Token ", idToken ?? '');

      if (idToken == null) {
        debugPrint("❌ ID Token is null — login cannot continue");
        return;
      }

      /// THIS is what backend needs
      final payload = {'AuthToken': idToken};

      debugPrint("📤 Sending ID token to backend...");

      final response = await ApiService.post(
        googleApi,
        payload,
        withAuth: false,
        encryptionRequired: true,
      );

      if (response is http.Response) {
        debugPrint("❌ HTTP error: ${response.statusCode}");
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Failed to sign in with google: ${response.statusCode}',
        );
        return;
      }

      final result = jsonDecode(jsonEncode(response));
      debugPrint("📥 Backend response decoded: $result");

      final token = result['data'];
      debugPrint("🔑 Extracted token: $token");

      if (token == null || token.toString().trim().isEmpty) {
        debugPrint("❌ Token is null/empty — aborting login to prevent forced logout cascade");
        CustomSnackbar.showError(
          context: context,
          title: 'Login Failed',
          message: 'Could not retrieve session token from server. Please try again.',
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      prefs.setString('auth_token', token.toString());
      debugPrint("✅ Auth token saved to prefs");

      await authService.handleSuccessfulSignIn(
        emailOrPhone: account.email,
        prefs: await SharedPreferences.getInstance(),
        context: context,
        rememberMe: true,
      );

      _initialized = false; // Reset init state to allow re-init if needed

      debugPrint("🎉 Backend login completed");
    } catch (e, stack) {
      debugPrint("🔥 Backend login failed: $e");
      debugPrint("$stack");
    }
  }

  @override
  void onClose() {
    _authEventsSub?.cancel();
    super.onClose();
  }
}
