import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/common/global_variables.dart';
import 'package:http/http.dart' as http;
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

  RxString googlePicUrl = ''.obs;
  // ---------------- INIT ----------------
  Future<void> init(BuildContext context) async {
    if (_initialized) {
      debugPrint("ℹ️ GoogleAuthService already initialized");
      return;
    }

    debugPrint("🔵 GoogleAuthService: init started");

    await _google.initialize(serverClientId: WEB);

    debugPrint("🟢 GoogleSignIn initialized with clientId: $WEB");

    // LISTEN AUTH EVENTS
    _authEventsSub = _google.authenticationEvents.listen(
      (event) async {
        debugPrint("📡 Authentication event received: ${event.runtimeType}");

        // SIGNED IN
        if (event is GoogleSignInAuthenticationEventSignIn) {
          final GoogleSignInAccount account = event.user;

          debugPrint("✅ User signed in");
          debugPrint("   Email: ${account.email}");
          debugPrint("   Display Name: ${account.displayName}");
          debugPrint("   ID: ${account.id}");

          user.value = account;
          googlePicUrl.value = account.photoUrl ?? '';

          await _handleBackendLogin(account, context, account.email);
        }
        // SIGNED OUT
        else if (event is GoogleSignInAuthenticationEventSignOut) {
          debugPrint("🚪 User signed out");
          user.value = null;
        }
      },
      onError: (error) {
        debugPrint("❌ authenticationEvents error triggered");
        _initialized = false; // Reset init state to allow re-init if needed
        if (error is GoogleSignInException) {
          debugPrint("   Error code: ${error.code}");
          debugPrint("   Error message: ${error.description}");
        } else {
          debugPrint("   Unknown error: $error");
        }

        // Ignore cancel (user just closed popup)
        if (error is GoogleSignInException &&
            error.code == GoogleSignInExceptionCode.canceled) {
          debugPrint("⚠️ User cancelled Google sign-in UI");
        }
      },
    );

    // Attempt auto login
    debugPrint("🔄 Attempting lightweight authentication...");
    _google.attemptLightweightAuthentication();
    _initialized = true;
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
      final token = result['data'];
      print("Received token from backend: $token");
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('auth_token', token);

      await authService.handleSuccessfulSignIn(
        emailOrPhone: account.email,
        prefs: await SharedPreferences.getInstance(),
        context: context,
        rememberMe: true,
      );

      _initialized = false; // Reset init state to allow re-init if needed

      debugPrint("📥 Backend response: $response");

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
