import 'dart:convert';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:snevva/views/Sign%20Up/sign_in_screen.dart';
import '../../env/env.dart';
import '../../services/auth_header_helper.dart';
import '../../services/encryption_service.dart';

class UpdateOldPasswordController extends GetxController {
  var obscurePassword = true.obs;
  var obscurePassword2 = true.obs;

  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  var password = ''.obs;
  var confirmPassword = ''.obs;
  var isChecked = false.obs;

  bool get hasLetter => RegExp(r'[A-Za-z]').hasMatch(password.value);
  bool get hasNumberOrSymbol => RegExp(r'[\d!@#$&*~]').hasMatch(password.value);
  bool get hasMinLength => password.value.length >= 10;

  bool get isPasswordValid => hasLetter && hasNumberOrSymbol && hasMinLength;

  bool get isConfirmPasswordValid {
    if (password.value.isEmpty || confirmPassword.value.isEmpty) {
      return false;
    }
    return password.value == confirmPassword.value;
  }


  bool validateAndShowError() {
    if (password.value.isEmpty || confirmPassword.value.isEmpty) {
      _showSnackbar("Error", "Please fill in both password fields", Colors.red);
      return false;
    }

    if (!isPasswordValid) {
      _showSnackbar("Weak Password", "Your password doesn't meet the required strength", Colors.orange);
      return false;
    }

    if (!isConfirmPasswordValid) {
      _showSnackbar("Mismatch", "Passwords do not match", Colors.orange);
      return false;
    }

    if (!isChecked.value) {
      _showSnackbar("Agreement Required", "You must agree to the terms to proceed", Colors.red);
      return false;
    }

    return true;
  }

  void _showSnackbar(String title, String message, Color backgroundColor) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(20),
      backgroundColor: backgroundColor,
      colorText: Colors.white,
    );
  }

  void resetState() {
    password.value = '';
    confirmPassword.value = '';
    passwordController.clear();
    confirmPasswordController.clear();
    isChecked.value = false;
  }

  Future<void> updateOldPasswordWithGmail(
      String email,
      String otp,
      bool verificationStatus,
      String password,
      ) async {
    final newPlanePassword = jsonEncode({
      'Gmail': email,
      'Otp': otp,
      'IsVerified': verificationStatus,
      'Password': password,
    });

    try {
      final uri = Uri.parse("$baseUrl$forgotPasswordUpdateUsingEmailEndpoint");
      final encryptedPassword = EncryptionService.encryptData(newPlanePassword);
      final headers = await AuthHeaderHelper.getHeaders(withAuth: false);

      headers['X-Data-Hash'] = encryptedPassword['hash']!;

      final encryptedBody = jsonEncode({
        'data': encryptedPassword['encryptedData'],
      });

      final response = await http.post(
        uri,
        headers: headers,
        body: encryptedBody,
      );

      if (response.statusCode == 200) {
        // Get.snackbar(
        //   'Success',
        //   'Password Updated Successfully with gmail',
        //   snackPosition: SnackPosition.BOTTOM,
        //   margin: EdgeInsets.all(20),
        // );

        resetState();
        Get.to(SignInScreen());
      }
    } catch (e) {
      Get.snackbar(
        'Failed',
        'Password Updation Failed.',
        snackPosition: SnackPosition.BOTTOM,
        margin: EdgeInsets.all(20),
      );
    }
  }

  Future<void> updateOldPasswordWithPhone(
      String phone,
      String otp,
      bool verificationStatus,
      String password,
      ) async {
    final newPlanePassword = jsonEncode({
      'PhoneNumber': phone,
      'Otp': otp,
      'IsVerified': verificationStatus,
      'Password': password,
    });

    try {
      final uri = Uri.parse("$baseUrl$forgotPasswordUpdateUsingPhoneEndpoint");
      final encryptedPassword = EncryptionService.encryptData(newPlanePassword);
      final headers = await AuthHeaderHelper.getHeaders(withAuth: false);

      headers['X-Data-Hash'] = encryptedPassword['hash']!;

      final encryptedBody = jsonEncode({
        'data': encryptedPassword['encryptedData'],
      });

      final response = await http.post(
        uri,
        headers: headers,
        body: encryptedBody,
      );

      if (response.statusCode == 200) {
        // Get.snackbar(
        //   'Success',
        //   'Password Updated Successfully with phone',
        //   snackPosition: SnackPosition.BOTTOM,
        //   margin: EdgeInsets.all(20),
        // );

        resetState();
        Get.to(SignInScreen());
      }
    } catch (e) {
      Get.snackbar(
        'Failed',
        'Password Updation Failed.',
        snackPosition: SnackPosition.BOTTOM,
        margin: EdgeInsets.all(20),
      );
    }
  }

}
