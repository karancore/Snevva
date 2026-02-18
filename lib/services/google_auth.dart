import 'package:flutter/material.dart';
import 'package:get/get_connect/http/src/response/response.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:snevva/services/api_service.dart';
import 'package:snevva/views/ProfileAndQuestionnaire/profile_setup_initial.dart';
import '../env/env.dart';

const String WEB_CLIENT_ID =
    "760082000923-v6lm2bqqroimspg8f1am01ntbio5mbn0.apps.googleusercontent.com";
const String ANDROID_CLIENT_ID =
    "760082000923-26b0b7kqucl8fgefjl5r58bo6df32mpa.apps.googleusercontent.com";

class GoogleAuthService {
  static Future<void> signInWithGoogle(BuildContext context) async {
    try {
      final scopes = ['email'];
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
