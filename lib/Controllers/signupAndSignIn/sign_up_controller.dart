import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:snevva/services/api_service.dart';
import '../../env/env.dart';
import '../../services/auth_header_helper.dart';
import '../../services/encryption_service.dart';

class SignUpController extends GetxController {
  var isLoading = false.obs;

  Future<dynamic> signUpUsingGmail(String email) async {
    if (email.isEmpty) {
      Get.snackbar(
        'Error',
        'Email cannot be empty',
        snackPosition: SnackPosition.BOTTOM,
        margin: EdgeInsets.all(20),
      );
      return;
    }
    final plainEmail = jsonEncode({'Gmail': email});

    try {
      isLoading.value = true;
      final uri = Uri.parse("$baseUrl$senOtpEmailEndpoint");
      final encryptedEmail = EncryptionService.encryptData(plainEmail);
      final headers = await AuthHeaderHelper.getHeaders(withAuth: false);

      headers['X-Data-Hash'] = encryptedEmail['hash']!;

      final encryptedBody = jsonEncode({
        'data': encryptedEmail['encryptedData'],
      });

      final response = await http.post(
        uri,
        headers: headers,
        body: encryptedBody,
      );
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        // print("response Body: $responseBody");

        final encryptedBody = responseBody['data'];
        // print("👉 Encrypted OTP response: $encryptedBody");
        
        final responseHash = response.headers['x-data-hash'];
        // print("👉 Response hash: $responseHash");
        
        final decrypted = EncryptionService.decryptData(
          encryptedBody,
          responseHash!,
        );
        // print("Decrypted OTP response: $decrypted");

        if (decrypted == null) {
          Get.snackbar(
            'Error',
            'Failed to decrypt response',
            snackPosition: SnackPosition.BOTTOM,
            margin: EdgeInsets.all(20),
          );
          return false;
        }

        final Map<String, dynamic> gettedData = jsonDecode(decrypted);

        final data = gettedData['data'];
        if (data == null || data['Otp'] == null) {
          Get.snackbar(
            'Error',
            'OTP not found in response',
            snackPosition: SnackPosition.BOTTOM,
            margin: EdgeInsets.all(20),
          );
          return false;
        }

        final otp = data['Otp'];

        Get.snackbar(
          'Success',
          'OTP Sent. $otp',
          snackPosition: SnackPosition.BOTTOM,
          margin: EdgeInsets.all(20),
        );

        return otp;
      } else {
        Get.snackbar(
          'Error',
          'Signup failed: ${response.body}',
          snackPosition: SnackPosition.BOTTOM,
          margin: EdgeInsets.all(20),
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Signup failed',
        snackPosition: SnackPosition.BOTTOM,
        margin: EdgeInsets.all(20),
      );
    } finally {
      isLoading.value = false;
    }
  }

Future<dynamic> gmailotp(String email) async {
    if (email.isEmpty) {
      Get.snackbar(
        'Error',
        'Email cannot be empty',
        snackPosition: SnackPosition.BOTTOM,
        margin: EdgeInsets.all(20),
      );
      return;
    }
    final plainEmail = jsonEncode({'Gmail': email});

    try {
      isLoading.value = true;
      final uri = Uri.parse("$baseUrl$updateEmailOtpEndpoint");
      final encryptedEmail = EncryptionService.encryptData(plainEmail);
      final headers = await AuthHeaderHelper.getHeaders(withAuth: true);

      headers['X-Data-Hash'] = encryptedEmail['hash']!;

      final encryptedBody = jsonEncode({
        'data': encryptedEmail['encryptedData'],
      });

      final response = await http.post(
        uri,
        headers: headers,
        body: encryptedBody,
      );
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        // print("response Body: $responseBody");

        final encryptedBody = responseBody['data'];
        // print("👉 Encrypted OTP response: $encryptedBody");

        final responseHash = response.headers['x-data-hash'];
        // print("👉 Response hash: $responseHash");

        final decrypted = EncryptionService.decryptData(
          encryptedBody,
          responseHash!,
        );
        // print("Decrypted OTP response: $decrypted");

        if (decrypted == null) {
          Get.snackbar(
            'Error',
            'Failed to decrypt response',
            snackPosition: SnackPosition.BOTTOM,
            margin: EdgeInsets.all(20),
          );
          return false;
        }

        final Map<String, dynamic> gettedData = jsonDecode(decrypted);

        final data = gettedData['data'];
        if (data == null || data['Otp'] == null) {
          Get.snackbar(
            'Error',
            'OTP not found in response',
            snackPosition: SnackPosition.BOTTOM,
            margin: EdgeInsets.all(20),
          );
          return false;
        }

        final otp = data['Otp'];

        Get.snackbar(
          'Success',
          'OTP Sent. $otp',
          snackPosition: SnackPosition.BOTTOM,
          margin: EdgeInsets.all(20),
        );

        return otp;
      } else {
        Get.snackbar(
          'Error',
          'Signup failed: ${response.body}',
          snackPosition: SnackPosition.BOTTOM,
          margin: EdgeInsets.all(20),
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Signup failed',
        snackPosition: SnackPosition.BOTTOM,
        margin: EdgeInsets.all(20),
      );
    } finally {
      isLoading.value = false;
    }
  }

Future<dynamic> updateGmail(String email) async {
    if (email.isEmpty) {
      Get.snackbar(
        'Error',
        'Email cannot be empty',
        snackPosition: SnackPosition.BOTTOM,
        margin: EdgeInsets.all(20),
      );
      return;
    }
    final plainEmail = {'Gmail': email};

    try{
       final response = await ApiService.post(
          updatePasswordUpdateUsingEmailEndpoint,
          plainEmail,
          withAuth: true,
          encryptionRequired: true,
        );

        if (response is http.Response) {
          Get.snackbar(
            'Error',
            'Failed to save',
            snackPosition: SnackPosition.BOTTOM,
            margin: EdgeInsets.all(20),
          );
          return;
        }
    } finally {
      isLoading.value = false;
    }
  }

Future<dynamic> phoneotp(String phone) async {
    if (phone.isEmpty) {
      Get.snackbar(
        'Error',
        'Number cannot be empty',
        snackPosition: SnackPosition.BOTTOM,
        margin: EdgeInsets.all(20),
      );
      return;
    }
    final plainphone = jsonEncode({'PhoneNumber': phone});

    try {
      isLoading.value = true;
      final uri = Uri.parse("$baseUrl$updatePhoneOtpEndpoint");
      final encryptedphone = EncryptionService.encryptData(plainphone);
      final headers = await AuthHeaderHelper.getHeaders(withAuth: true);

      headers['X-Data-Hash'] = encryptedphone['hash']!;

      final encryptedBody = jsonEncode({
        'data': encryptedphone['encryptedData'],
      });

      final response = await http.post(
        uri,
        headers: headers,
        body: encryptedBody,
      );
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        // print("response Body: $responseBody");

        final encryptedBody = responseBody['data'];
        // print("👉 Encrypted OTP response: $encryptedBody");

        final responseHash = response.headers['x-data-hash'];
        // print("👉 Response hash: $responseHash");

        final decrypted = EncryptionService.decryptData(
          encryptedBody,
          responseHash!,
        );
        // print("Decrypted OTP response: $decrypted");

        if (decrypted == null) {
          Get.snackbar(
            'Error',
            'Failed to decrypt response',
            snackPosition: SnackPosition.BOTTOM,
            margin: EdgeInsets.all(20),
          );
          return false;
        }

        final Map<String, dynamic> gettedData = jsonDecode(decrypted);

        final data = gettedData['data'];
        if (data == null || data['Otp'] == null) {
          Get.snackbar(
            'Error',
            'OTP not found in response',
            snackPosition: SnackPosition.BOTTOM,
            margin: EdgeInsets.all(20),
          );
          return false;
        }

        final otp = data['Otp'];

        Get.snackbar(
          'Success',
          'OTP Sent. $otp',
          snackPosition: SnackPosition.BOTTOM,
          margin: EdgeInsets.all(20),
        );

        return otp;
      } else {
        Get.snackbar(
          'Error',
          'Signup failed: ${response.body}',
          snackPosition: SnackPosition.BOTTOM,
          margin: EdgeInsets.all(20),
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Signup failed',
        snackPosition: SnackPosition.BOTTOM,
        margin: EdgeInsets.all(20),
      );
    } finally {
      isLoading.value = false;
    }
  }

Future<dynamic> updatePhone(String phoneNumber) async {
    if (phoneNumber.isEmpty) {
      Get.snackbar(
        'Error',
        'phoneNumber cannot be empty',
        snackPosition: SnackPosition.BOTTOM,
        margin: EdgeInsets.all(20),
      );
      return;
    }
    final plainphoneNumber = {'PhoneNumber': phoneNumber};

    try{
       final response = await ApiService.post(
          updatePasswordUpdateUsingPhoneEndpoint,
          plainphoneNumber,
          withAuth: true,
          encryptionRequired: true,
        );

        if (response is http.Response) {
          Get.snackbar(
            'Error',
            'Failed to save',
            snackPosition: SnackPosition.BOTTOM,
            margin: EdgeInsets.all(20),
          );
          return;
        }
    } finally {
      isLoading.value = false;
    }
  }

  Future<dynamic> signUpUsingPhone(String phone) async {
    if (phone.isEmpty) {
      Get.snackbar(
        'Error',
        'Phone cannot be empty',
        snackPosition: SnackPosition.BOTTOM,
        margin: EdgeInsets.all(20),
      );
      return false;
    }
    final plainPhone = jsonEncode({'PhoneNumber': phone});

    isLoading.value = true;

    try {
      final uri = Uri.parse("$baseUrl$senOtpPhoneEndpoint");
      final encryptedPhone = EncryptionService.encryptData(plainPhone);
      final headers = await AuthHeaderHelper.getHeaders(withAuth: false);

      headers['X-Data-Hash'] = encryptedPhone['hash']!;

      final encryptedBody = jsonEncode({
        'data': encryptedPhone['encryptedData'],
      });

      final response = await http.post(
        uri,
        headers: headers,
        body: encryptedBody,
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final encryptedBody = responseBody['data'];
        final responseHash = response.headers['x-data-hash'];
        final decrypted = EncryptionService.decryptData(
          encryptedBody,
          responseHash!,
        );

        if (decrypted == null) {
          return;
        }

        final Map<String, dynamic> responseData = jsonDecode(decrypted);

        final data = responseData['data'];
        final otp = data['Otp'];

        Get.snackbar(
          'Success',
          'OTP Sent. $otp',
          snackPosition: SnackPosition.BOTTOM,
          margin: EdgeInsets.all(20),
        );
        return otp;
      } else {
        Get.snackbar(
          'Error',
          'Signup failed: Something Went Wrong!',
          snackPosition: SnackPosition.BOTTOM,
          margin: EdgeInsets.all(20),
        );
        return false;
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Signup failed',
        snackPosition: SnackPosition.BOTTOM,
        margin: EdgeInsets.all(20),
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }
}
