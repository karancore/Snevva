import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:snevva/env/env.dart';

import 'google_backend_auth_service.dart';

class GoogleAuthService extends GetxService {
  final GoogleSignIn _google = GoogleSignIn.instance;
  Rxn<GoogleSignInAccount> user = Rxn();

  RxBool isLoading = false.obs;

  StreamSubscription<GoogleSignInAuthenticationEvent>? _authEventsSub;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    await _authEventsSub?.cancel();
    _authEventsSub = null;

    await _google.initialize(serverClientId: WEB);

    _authEventsSub = _google.authenticationEvents.listen(
          (event) async {
        if (event is GoogleSignInAuthenticationEventSignIn) {
          isLoading.value = true;
          user.value = event.user;

          // Precache handled by UI layer — not here
          await Get.find<BackendAuthService>()
              .handleGoogleBackendLogin(event.user);

          isLoading.value = false;
        } else if (event is GoogleSignInAuthenticationEventSignOut) {
          user.value = null;
          isLoading.value = false;
        }
      },
      onError: (error) {
        isLoading.value = false;
        if (error is GoogleSignInException &&
            error.code == GoogleSignInExceptionCode.canceled) return;
        _initialized = false;
        debugPrint("❌ Auth event error: $error");
      },
    );

    _initialized = true;
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
