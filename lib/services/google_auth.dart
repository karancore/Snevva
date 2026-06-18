import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:snevva/env/env.dart';

import 'google_backend_auth_service.dart';

class GoogleAuthService extends GetxService {
  final GoogleSignIn _google = GoogleSignIn.instance;
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

          await precacheImage(
            CachedNetworkImageProvider(account.photoUrl ?? ''),
            context,
          );

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
    try {
      await _google.attemptLightweightAuthentication();
    } catch (e) {
      debugPrint("❌ Lightweight auth failed: $e");

      CustomSnackbar.showError(
        context: context,
        title: 'Sign-in Issue',
        message: 'Google auto sign-in failed. Please try manually.',
      );
      _initialized = true;
    }
  }

  Future<void> signIn() async {
    if (!_google.supportsAuthenticate()) return;
    try {
      await _google.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return;
      rethrow;
    }
  }

  void reset() {
    _authEventsSub?.cancel();
    _authEventsSub = null;
    _initialized = false;
    user.value = null;
    isLoading.value = false;
  }

  @override
  void onClose() {
    _authEventsSub?.cancel();
    super.onClose();
  }
}