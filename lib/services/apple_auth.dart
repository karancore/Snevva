import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../consts/consts.dart';
import 'google_backend_auth_service.dart';

class AppleAuthService extends GetxService {
  RxBool isLoading = false.obs;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    _initialized = true;
  }

  Future<void> handleAppleSignIn() async {
    try {
      // 1. Trigger the native Apple Auth Event
      final AuthorizationCredentialAppleID credential =
          await SignInWithApple.getAppleIDCredential(
            scopes: [
              AppleIDAuthorizationScopes.email,
              AppleIDAuthorizationScopes.fullName,
            ],
          );

      // 2. Extract Auth Event Payload
      debugPrint('User ID: ${credential.userIdentifier}');
      debugPrint('Authorization Code: ${credential.authorizationCode}');
      debugPrint('Identity Token: ${credential.identityToken}');

      // NOTE: Name and email are ONLY sent during the very first authentication event
      debugPrint('Email: ${credential.email}');
      debugPrint('Given Name: ${credential.givenName}');

      await Get.find<BackendAuthService>().handleAppleBackendLogin(
        account: credential,
      );

      // 3. Send these details to your backend or Firebase Auth
      // ...
    } catch (error) {
      // Handle user cancellation or platform exceptions
      debugPrint('Authentication failed: $error');
    }
  }
}
