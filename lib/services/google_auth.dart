import 'package:flutter/material.dart';
import 'package:get/get_connect/http/src/response/response.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:snevva/services/api_service.dart';
import 'package:snevva/views/ProfileAndQuestionnaire/profile_setup_initial.dart';
import '../env/env.dart';

class GoogleAuthService {
  static Future<void> signInWithGoogle(BuildContext context) async {
    try {
      // Initialize Google Sign-In
      await GoogleSignIn.instance.initialize(
        serverClientId:
            '272153297465-t72f4dq6q5poav38044ljdv97h1k31mm.apps.googleusercontent.com',
      );

      // Optional: sign out before signing in
      await GoogleSignIn.instance.signOut();

      // Start interactive sign-in
      final user = await GoogleSignIn.instance.authenticate();

      print(user);

      // Get the ID token
      dynamic idToken = user.authentication.idToken;

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
