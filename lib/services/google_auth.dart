import 'package:flutter/foundation.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_disposable.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/Controllers/signupAndSignIn/sign_in_controller.dart';
import 'package:snevva/common/global_variables.dart';
import 'package:http/http.dart' as http;
import 'package:snevva/services/auth_service.dart';
import 'package:snevva/views/SignUp/sign_in_screen.dart';
import '../common/custom_snackbar.dart';
import '../consts/consts.dart';
import '../env/env.dart';
import '../views/ProfileAndQuestionnaire/profile_setup_initial.dart';
import 'api_service.dart';

class GoogleAuthService extends GetxService {
  final GoogleSignIn _google = GoogleSignIn.instance;
  final authService = AuthService();
  Rxn<GoogleSignInAccount> user = Rxn();

  // ---------------- INIT ----------------
  Future<void> init(BuildContext context) async {
    debugPrint("🔵 GoogleAuthService: init started");

    await _google.initialize(serverClientId: WEB);

    debugPrint("🟢 GoogleSignIn initialized with clientId: $WEB");

    // LISTEN AUTH EVENTS
    _google.authenticationEvents.listen(
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
  }

  // ---------------- BUTTON LOGIN ----------------
  Future<void> signIn() async {
    debugPrint("👆 Login button pressed");

    final supports = _google.supportsAuthenticate();
    debugPrint("Supports authenticate: $supports");

    if (supports) {
      debugPrint("🚀 Starting Google authenticate()");
      await _google.authenticate();
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

      final GoogleSignInAuthentication auth = await account.authentication;

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
          context: Get.context!,
          title: 'Error',
          message: 'Failed to sign in with google: ${response.statusCode}',
        );
        return;
      }

      await authService.handleSuccessfulSignIn(
        emailOrPhone: account.email,
        prefs: await SharedPreferences.getInstance(),
        context: context,
        rememberMe: true,
      );

      debugPrint("📥 Backend response: $response");

      debugPrint("🎉 Backend login completed");
    } catch (e, stack) {
      debugPrint("🔥 Backend login failed: $e");
      debugPrint("$stack");
    }
  }
}
