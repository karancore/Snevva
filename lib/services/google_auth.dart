import 'package:flutter/material.dart';
import 'package:get/get_connect/http/src/response/response.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:snevva/services/api_service.dart';
import 'package:snevva/views/ProfileAndQuestionnaire/profile_setup_initial.dart';
import '../env/env.dart';

class GoogleAuthService {
  static Future<void> signInWithGoogle(BuildContext context) async {
    try {
      final scopes = ['email', 'profile'];
      // Initialize Google Sign-In
      await GoogleSignIn.instance.initialize(serverClientId: ANDROID_CLIENT_ID);

      // // Optional: sign out before signing in
      // await GoogleSignIn.instance.signOut();

      // Start interactive sign-in
      //final user = await GoogleSignIn.instance.authenticate();

      final googleUser =
          await GoogleSignIn.instance.attemptLightweightAuthentication();
      if (googleUser == null) {
        throw Exception('Failed to sign in with Google.');
      }

      final authorization =
          await googleUser.authorizationClient.authorizationForScopes(scopes) ??
          await googleUser.authorizationClient.authorizeScopes(scopes);
      final idToken = googleUser.authentication.idToken;
      if (idToken == null) {
        throw Exception('No ID Token found.');
      }

      print(googleUser);

      // Get the ID token
      //dynamic idToken = user.authentication.idToken;

      if (idToken == null) {
        throw Exception('Google ID token is null');
      }

      final payload = {'AuthToken': idToken};

      print(payload);

      final response = await ApiService.post(
        googleApi,
        payload,
        withAuth: true,
        encryptionRequired: false,
      );

      print('Backend response: $response');

      if (response is http.Response) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backend error: ${response.statusCode}')),
        );
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ProfileSetupInitial()),
      );
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Google Sign-In failed: $e')));
    }
  }
}

// import 'dart:async';
//
// import 'package:flutter/material.dart';
// import 'package:get/get_connect/http/src/response/response.dart' as http;
// import 'package:google_sign_in/google_sign_in.dart';
// import 'package:snevva/services/api_service.dart';
// import 'package:snevva/views/ProfileAndQuestionnaire/profile_setup_initial.dart';
// import '../common/global_variables.dart';
// import '../env/env.dart';
//
// class GoogleAuthService {
//   static Future<void> signInWithGoogle(BuildContext context) async {
//     try {
//       debugPrint("🔹 Starting Google Sign-In flow...");
//
//
//       // const webClientId =
//       //     "760082000923-v6lm2bqqroimspg8f1am01ntbio5mbn0.apps.googleusercontent.com";
//       //
//       const webClientId = "760082000923-v6lm2bqqroimspg8f1am01ntbio5mbn0.apps.googleusercontent.com";
//
//
//
//       final scopes = ['email', 'profile'];
//
//       final googleSignIn = GoogleSignIn.instance;
//
//       debugPrint("🔹 Initializing GoogleSignIn with Web client ID...");
//
//       await googleSignIn.initialize(serverClientId: webClientId);
//
//
//       debugPrint("✅ GoogleSignIn initialized successfully");
//
//       // Optional: sign out before signing in
//       // debugPrint("🔹 Signing out previous Google account...");
//       // await googleSignIn.signOut();
//       // debugPrint("✅ Signed out successfully");
//
//       debugPrint("🔹 Attempting lightweight authentication...");
//       final googleUser = await googleSignIn.authenticate();
//       debugPrint("🔹 Lightweight auth result: $googleUser");
//
//       if (googleUser == null) {
//         throw Exception('⚠️ Failed to sign in with Google (user null).');
//       }
//
//       debugPrint("🔹 Authorizing scopes: $scopes");
//       final authorization =
//           await googleUser.authorizationClient.authorizationForScopes(scopes) ??
//               await googleUser.authorizationClient.authorizeScopes(scopes);
//       debugPrint("✅ Authorization result: $authorization");
//
//       final idToken = googleUser.authentication.idToken;
//       debugPrint(
//         "🔹 Retrieved ID token: ${idToken != null ? 'SUCCESS' : 'NULL'}",
//       );
//
//       if (idToken == null) {
//         throw Exception('❌ Google ID token is null.');
//       }
//
//       logLong('🧾 ID TOKEN:', idToken);
//
//
//       debugPrint("🔹 Preparing payload for backend...");
//       final payload = {'AuthToken': idToken};
//       debugPrint("🔹 Payload: $payload");
//
//       debugPrint("🔹 Sending payload to backend...");
//       final response = await ApiService.post(
//         googleApi,
//         payload,
//         withAuth: true,
//         encryptionRequired: false,
//       );
//       logLong('🧾 BACKEND RESPONSE:', response.toString());
//
//
//       if (response is http.Response) {
//         debugPrint("⚠️ Backend HTTP status: ${response.statusCode}");
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Backend error: ${response.statusCode}')),
//         );
//       }
//
//       debugPrint("🔹 Navigating to ProfileSetupInitial...");
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(builder: (context) => const ProfileSetupInitial()),
//       );
//       debugPrint("✅ Navigation complete");
//     } catch (e, stack) {
//       debugPrint("❌ Google Sign-In error: $e");
//       debugPrint("Stack trace $stack");
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text('Google Sign-In failed: $e')));
//     }
//   }
// }
