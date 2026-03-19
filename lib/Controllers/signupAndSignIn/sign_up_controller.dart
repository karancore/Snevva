import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:snevva/services/api_service.dart';
import 'package:snevva/services/device_token_service.dart';
import 'package:snevva/services/notification_service.dart';
import '../../common/custom_snackbar.dart';
import '../../env/env.dart';
import '../../services/auth_header_helper.dart';
import '../../services/encryption_service.dart';

class SignUpController extends GetxService {
  var isLoading = false.obs;

  Future<dynamic> signUpUsingGmail(String email, BuildContext context) async {
    debugPrint("⏳ signUpUsingGmail() called with email: $email");

    if (email.isEmpty) {
      debugPrint("❌ Email empty");
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Email cannot be empty',
      );
      return;
    }

    final plainEmail = jsonEncode({'Gmail': email});
    debugPrint("📨 Plain Email JSON: $plainEmail");

    try {
      isLoading.value = true;
      debugPrint("⏳ Sending OTP request…");

      final uri = Uri.parse("$baseUrl$senOtpEmailEndpoint");
      debugPrint("🌐 URL: $uri");

      final encryptedEmail = EncryptionService.encryptData(plainEmail);
      debugPrint("🔐 Encrypted Email: ${encryptedEmail['encryptedData']}");
      debugPrint("🔑 Hash: ${encryptedEmail['Hash']}");

      final headers = await AuthHeaderHelper.getHeaders(withAuth: false);
      headers['x-data-hash'] = encryptedEmail['Hash']!;

      debugPrint("📌 Final Request Headers: $headers");

      final deviceInfoHeader =
          await DeviceTokenService().buildDeviceInfoHeader();

      headers['X-Device-Info'] = deviceInfoHeader;

      final encryptedBody = jsonEncode({
        'data': encryptedEmail['encryptedData'],
      });

      debugPrint("📦 Request Body: $encryptedBody");

      final response = await http.post(
        uri,
        headers: headers,
        body: encryptedBody,
      );

      debugPrint("📥 Response Status: ${response.statusCode}");
      debugPrint("📥 Raw Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        debugPrint("📥 Decoded Response Body: $responseBody");

        final encryptedBody = responseBody['data'];
        debugPrint("🔐 Encrypted Response Data: $encryptedBody");

        // final debugPrintedHash = response.headers;
        // debugPrint("📋 prinyted: $debugPrintedHash");
        final responseHash = response.headers['x-data-hash'];
        debugPrint("🔑 Response Hash: $responseHash");

        final decrypted = EncryptionService.decryptData(
          encryptedBody,
          responseHash!,
        );

        debugPrint("🔓 Decrypted Response: $decrypted");

        if (decrypted == null) {
          debugPrint("❌ Decryption returned null");
          CustomSnackbar.showError(
            context: context,
            title: 'Error',
            message: 'Failed to decrypt response',
          );
          return false;
        }

        final Map<String, dynamic> gettedData = jsonDecode(decrypted);
        debugPrint("📄 Decoded Decrypted Data: $gettedData");

        final data = gettedData['data'];
        debugPrint("📌 'data' field: $data");

        if (data == null || data['Otp'] == null) {
          debugPrint("❌ OTP field missing inside response");
          CustomSnackbar.showError(
            context: context,
            title: 'Error',
            message: 'OTP not found in response',
          );
          return false;
        }

        final otp = data['Otp'];
        debugPrint("📲 Extracted OTP: $otp");

        // await notify.showOtpNotification(otp);
        debugPrint("🔔 Local Notification Sent");

        CustomSnackbar.showSuccess(
          context: context,
          title: 'Success',
          message: 'OTP Sent. $otp',
        );

        return otp;
      }
      // 400 error
      else if (response.statusCode == 400) {
        debugPrint("❌ Email already registered");
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Email already registered',
        );
        return false;
      }
      // Other errors
      else {
        debugPrint("❌ Unexpected Error: ${response.body}");
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
      debugPrint("🔚 signUpUsingGmail() FINALLY — isLoading set to false");
      isLoading.value = false;
    }
  }

  Future<dynamic> gmailOtp(String email, BuildContext context) async {
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

      headers['x-data-hash'] = encryptedEmail['Hash']!;

      final deviceInfoHeader =
          await DeviceTokenService().buildDeviceInfoHeader();

      headers['X-Device-Info'] = deviceInfoHeader;

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
        // debugPrint("response Body: $responseBody");

        final encryptedBody = responseBody['data'];
        // debugPrint("👉 Encrypted OTP response: $encryptedBody");

        final responseHash = response.headers['x-data-hash'];
        // debugPrint("👉 Response Hash: $responseHash");

        final decrypted = EncryptionService.decryptData(
          encryptedBody,
          responseHash!,
        );
        // debugPrint("Decrypted OTP response: $decrypted");

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
        // await notify.showOtpNotification(otp);

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

      headers['x-data-hash'] = encryptedphone['Hash']!;

      final deviceInfoHeader =
          await DeviceTokenService().buildDeviceInfoHeader();

      headers['X-Device-Info'] = deviceInfoHeader;

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
        // debugPrint("response Body: $responseBody");

        final encryptedBody = responseBody['data'];
        // debugPrint("👉 Encrypted OTP response: $encryptedBody");

        final responseHash = response.headers['x-data-hash'];
        // debugPrint("👉 Response Hash: $responseHash");

        final decrypted = EncryptionService.decryptData(
          encryptedBody,
          responseHash!,
        );
        // debugPrint("Decrypted OTP response: $decrypted");

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
        // await notify.showOtpNotification(otp);

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
    } catch (e, s) {
      debugPrint("🚨 Caught Exception in signUpUsingGmail:");
      debugPrint("❗ Error: $e");
      debugPrint("📌 Stack Trace: $s");

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

      headers['x-data-hash'] = encryptedPhone['Hash']!;

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
        final responseHash = response.headers['x-data-hash']!;

        debugPrint("👉 Encrypted OTP response: $encryptedBody");
        debugPrint("👉 Response Hash: $responseHash");
        final decrypted = EncryptionService.decryptData(
          encryptedBody,
          responseHash,
        );

        debugPrint("Decrypted OTP response: $decrypted");

        if (decrypted == null) {
          throw Exception("Failed to decrypt response data");
        }

        final Map<String, dynamic> responseData = jsonDecode(decrypted);
        debugPrint(responseData.toString());

        final data = responseData['data'];
        final otp = data['Otp'];
        // await notify.showOtpNotification(otp);

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
