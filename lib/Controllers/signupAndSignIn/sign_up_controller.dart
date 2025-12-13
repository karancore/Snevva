import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:snevva/services/api_service.dart';
import 'package:snevva/services/notification_service.dart';
import '../../common/custom_snackbar.dart';
import '../../env/env.dart';
import '../../services/auth_header_helper.dart';
import '../../services/encryption_service.dart';

class SignUpController extends GetxController {
  var isLoading = false.obs;

  final notify = Get.put(NotificationService());

  Future<dynamic> signUpUsingGmail(String email, BuildContext context) async {
    if (email.isEmpty) {
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Email cannot be empty',
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
          CustomSnackbar.showError(
            context: context,
            title: 'Error',
            message: 'Failed to decrypt response',
          );
          return false;
        }

        final Map<String, dynamic> gettedData = jsonDecode(decrypted);

        final data = gettedData['data'];
        if (data == null || data['Otp'] == null) {
          CustomSnackbar.showError(
            context: context,
            title: 'Error',
            message: 'OTP not found in response',
          );
          return false;
        }

        final otp = data['Otp'];

        await notify.showOtpNotification(otp);

        CustomSnackbar.showSuccess(
          context: context,
          title: 'Success',
          message: 'OTP Sent. $otp',
        );

        return otp;
      } else if (response.statusCode == 400) {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Email already registered',
        );
        return false;
      } else {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Signup failed',
        );
      }
    } catch (e) {
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Signup failed',
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<dynamic> gmailotp(String email, BuildContext context) async {
    if (email.isEmpty) {
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Email cannot be empty',
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
          CustomSnackbar.showError(
            context: context,
            title: 'Error',
            message: 'Failed to decrypt response',
          );
          return false;
        }

        final Map<String, dynamic> gettedData = jsonDecode(decrypted);

        final data = gettedData['data'];
        if (data == null || data['Otp'] == null) {
          CustomSnackbar.showError(
            context: context,
            title: 'Error',
            message: 'OTP not found in response',
          );
          return false;
        }

        final otp = data['Otp'];
        await notify.showOtpNotification(otp);

        CustomSnackbar.showSuccess(
          context: context,
          title: 'Success',
          message: 'OTP Sent. $otp',
        );

        return otp;
      } else {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Signup failed',
        );
      }
    } catch (e) {
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Signup failed',
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<dynamic> updateGmail(String email, BuildContext context) async {
    if (email.isEmpty) {
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Email cannot be empty',
      );
      return;
    }
    final plainEmail = {'Gmail': email};

    try {
      final response = await ApiService.post(
        updatePasswordUpdateUsingEmailEndpoint,
        plainEmail,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response) {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Failed to save',
        );
        return;
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<dynamic> phoneotp(String phone, BuildContext context) async {
    if (phone.isEmpty) {
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Number cannot be empty',
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
          CustomSnackbar.showError(
            context: context,
            title: 'Error',
            message: 'Failed to decrypt response',
          );
          return false;
        }

        final Map<String, dynamic> gettedData = jsonDecode(decrypted);

        final data = gettedData['data'];
        if (data == null || data['Otp'] == null) {
          CustomSnackbar.showError(
            context: context,
            title: 'Error',
            message: 'OTP not found in response',
          );
          return false;
        }

        final otp = data['Otp'];
        await notify.showOtpNotification(otp);

        CustomSnackbar.showSuccess(
          context: context,
          title: 'Success',
          message: 'OTP Sent. $otp',
        );

        return otp;
      } else {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Signup failed: ${response.body}',
        );
      }
    } catch (e) {
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Signup failed',
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<dynamic> updatePhone(String phoneNumber, BuildContext context) async {
    if (phoneNumber.isEmpty) {
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'phoneNumber cannot be empty',
      );
      return;
    }
    final plainphoneNumber = {'PhoneNumber': phoneNumber};

    try {
      final response = await ApiService.post(
        updatePasswordUpdateUsingPhoneEndpoint,
        plainphoneNumber,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response) {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Failed to save',
        );
        return;
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<dynamic> signUpUsingPhone(String phone, BuildContext context) async {
    if (phone.isEmpty) {
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Phone cannot be empty',
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

      print(response.statusCode);

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final encryptedBody = responseBody['data'];
        final responseHash = response.headers['x-data-hash'];
        final decrypted = EncryptionService.decryptData(
          encryptedBody,
          responseHash!,
        );

        print("Decrypted OTP response: $decrypted");

        if (decrypted == null) {
          return;
        }

        final Map<String, dynamic> responseData = jsonDecode(decrypted);
        print(responseData);

        final data = responseData['data'];
        final otp = data['Otp'];
        await notify.showOtpNotification(otp);

        CustomSnackbar.showSuccess(
          context: context,
          title: 'Success',
          message: 'OTP Sent. $otp',
        );
        return otp;
      } else if (response.statusCode == 400) {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Phone number already registered',
        );
        return false;
      } else {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Signup failed: ${response.body}',
        );
        return false;
      }
    } catch (e) {
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Signup failed',
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }
}
