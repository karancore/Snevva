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

import '../env/env.dart';
import 'api_service.dart';

class GoogleAuthService extends GetxService {
  final GoogleSignIn _google = GoogleSignIn.instance;
  final authService = AuthService();
  Rxn<GoogleSignInAccount> user = Rxn();
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authEventsSub;
  bool _initialized = false;

  // ---------------- INIT ----------------
  Future<void> init() async {
    if (_initialized) {
      debugPrint("ℹ️ GoogleAuthService already initialized");
      return;
    }

    await _authEventsSub?.cancel();
    _authEventsSub = null;

    debugPrint("🔵 GoogleAuthService: init started");

    await _google.initialize(serverClientId: WEB);

    debugPrint("🟢 GoogleSignIn initialized with clientId: $WEB");

    _authEventsSub = _google.authenticationEvents.listen(
          (event) async {
        debugPrint("📡 Authentication event received: ${event.runtimeType}");

        if (event is GoogleSignInAuthenticationEventSignIn) {
          final GoogleSignInAccount account = event.user;

          debugPrint("✅ User signed in");
          debugPrint("   Email: ${account.email}");
          debugPrint("   Display Name: ${account.displayName}");
          debugPrint("   ID: ${account.id}");

          user.value = account;

          // Non-critical — silently skip if URL absent or network fails
          final photoUrl = account.photoUrl;
          if (photoUrl != null && photoUrl.isNotEmpty) {
            final ctx = Get.context;
            if (ctx != null) {
              try {
                await precacheImage(CachedNetworkImageProvider(photoUrl), ctx);
              } catch (_) {
                debugPrint(
                    "⚠️ precacheImage failed (non-critical), continuing login");
              }
            }
          }

          debugPrint("Account photo $photoUrl");

          await _handleBackendLogin(account);
        } else if (event is GoogleSignInAuthenticationEventSignOut) {
          debugPrint("🚪 User signed out");
          user.value = null;
        }
      },
      onError: (error) {
        debugPrint("❌ authenticationEvents error triggered");

        if (error is GoogleSignInException) {
          debugPrint("   Error code: ${error.code}");
          debugPrint("   Error message: ${error.description}");

          if (error.code == GoogleSignInExceptionCode.canceled) {
            debugPrint("⚠️ User cancelled Google sign-in UI");
            return;
          }
        } else {
          debugPrint("   Unknown error: $error");
        }

        _initialized = false;
      },
    );

    _initialized = true;

    debugPrint("🔄 Attempting lightweight authentication...");
    try {
      await _google.attemptLightweightAuthentication();
    } catch (e) {
      debugPrint("❌ Lightweight auth failed: $e");
      // Silent — user hasn't attempted login yet, no snackbar needed
    }
  }

  // ---------------- BUTTON LOGIN ----------------
  Future<void> signIn() async {
    debugPrint("👆 Login button pressed");

    final supports = _google.supportsAuthenticate();
    debugPrint("Supports authenticate: $supports");

    if (supports) {
      debugPrint("🚀 Starting Google authenticate()");
      try {
        await _google.authenticate();
      } on GoogleSignInException catch (e) {
        if (e.code == GoogleSignInExceptionCode.canceled) {
          debugPrint("⚠️ User cancelled Google sign-in UI");
          return;
        }
        rethrow;
      }
    } else {
      debugPrint("⚠️ authenticate() not supported on this platform");
    }
  }

  // ---------------- BACKEND LOGIN ----------------
  // No BuildContext — all UI feedback via Get.snackbar
  Future<void> _handleBackendLogin(GoogleSignInAccount account) async {
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

      debugPrint("📤 Sending ID token to backend...");

      final response = await ApiService.post(
        googleApi,
        {'AuthToken': idToken},
        withAuth: false,
        encryptionRequired: true,
      );

      if (response is http.Response) {
        debugPrint("❌ HTTP error: ${response.statusCode}");
        Get.snackbar(
          'Sign-in Error',
          'Failed to sign in with Google (${response
              .statusCode}). Please try again.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final result = jsonDecode(jsonEncode(response));
      debugPrint("📥 Backend response decoded: $result");

      final token = result['data'];
      debugPrint("🔑 Extracted token: $token");

      if (token == null || token.toString().trim().isEmpty) {
        debugPrint("❌ Token is null/empty — aborting login");
        Get.snackbar(
          'Login Failed',
          'Could not retrieve session token from server. Please try again.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      prefs.setString('auth_token', token.toString());
      debugPrint("✅ Auth token saved to prefs");

      await authService.handleSuccessfulSignIn(
        emailOrPhone: account.email,
        prefs: await SharedPreferences.getInstance(),
        context: Get.context!,
        rememberMe: true,
      );

      debugPrint("📥 Backend response: $response");
      debugPrint("🎉 Backend login completed");
    } catch (e, stack) {
      debugPrint("🔥 Backend login failed: $e");
      debugPrint("$stack");
    }
  }

  // ---------------- RESET (called on logout) ----------------
  void reset() {
    _authEventsSub?.cancel();
    _authEventsSub = null;
    _initialized = false;
    user.value = null;
    debugPrint("🔄 GoogleAuthService reset");
  }

  @override
  void onClose() {
    _authEventsSub?.cancel();
    super.onClose();
  }
}