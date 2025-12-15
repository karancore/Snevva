import 'dart:convert';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:snevva/views/Sign%20Up/sign_in_screen.dart';
import '../../common/custom_snackbar.dart';
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

  bool validateAndShowError(BuildContext context) {
    if (password.value.isEmpty || confirmPassword.value.isEmpty) {
      CustomSnackbar.showError(
        context: context,
        title: "Error",
        message: "Please fill in both password fields",
      );
      return false;
    }

    if (!isPasswordValid) {
      CustomSnackbar.showError(
        context: context,
        title: "Weak Password",
        message: "Your password doesn't meet the required strength",
      );
      return false;
    }

    if (!isConfirmPasswordValid) {
      CustomSnackbar.showError(
        context: context,
        title: "Mismatch",
        message: "Passwords do not match",
      );
      return false;
    }

    if (!isChecked.value) {
      CustomSnackbar.showError(
        context: context,
        title: "Agreement Required",
        message: "You must agree to the terms to proceed",
      );
      return false;
    }

    return true;
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
    BuildContext context,
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
        CustomSnackbar.showSuccess(
          context: context,
          title: 'Success',
          message: 'Password Updated Successfully with gmail',
        );

        resetState();
        Get.to(SignInScreen());
      }
    } catch (e) {
      CustomSnackbar.showError(
        context: context,
        title: 'Failed',
        message: 'Password Updation Failed.',
      );
    }
  }

  Future<void> updateOldPasswordWithPhone(
    String phone,
    String otp,
    bool verificationStatus,
    String password,
    BuildContext context,
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
        CustomSnackbar.showSuccess(
          context: context,
          title: 'Success',
          message: 'Password Updated Successfully with phone',
        );

        resetState();
        Get.to(SignInScreen());
      }
    } catch (e) {
      CustomSnackbar.showError(
        context: context,
        title: 'Failed',
        message: 'Password Updation Failed.',
      );
    }
  }
}
