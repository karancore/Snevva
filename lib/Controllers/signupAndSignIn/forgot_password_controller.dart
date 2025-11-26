import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../consts/consts.dart';
import '../../env/env.dart';
import '../../services/auth_header_helper.dart';
import '../../services/encryption_service.dart';

class ForgotPasswordController extends GetxController{

  var isLoading = false.obs;


  Future<dynamic> resetPasswordUsingGmail(String email) async {

    if (email.isEmpty) {
      Get.snackbar(
        'Error',
        'Email cannot be empty',
        snackPosition: SnackPosition.BOTTOM,
        margin: EdgeInsets.all(20),
      );
      return false;
    }
    final plainEmail = jsonEncode({'Gmail': email});

    isLoading.value = true;

    try {
      final uri = Uri.parse("$baseUrl$forgotEmailOtpEndpoint");
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
        final encryptedBody = responseBody['data'];
        final responseHash = response.headers['x-data-hash'];
        final decrypted = EncryptionService.decryptData(encryptedBody, responseHash!);

        if (decrypted == null) {
          return false;
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
          'Email Verification failed: ${response.body}',
          snackPosition: SnackPosition.BOTTOM,
          margin: EdgeInsets.all(20),
        );
        return false;
      }
    } catch (e) {
      Get.snackbar('Error', 'Email Verification failed',   snackPosition: SnackPosition.BOTTOM,
        margin: EdgeInsets.all(20),);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<dynamic> resetPasswordUsingPhone(String phone) async {
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
      final uri = Uri.parse("$baseUrl$forgotPhoneOtpEndpoint");
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
        final decrypted = EncryptionService.decryptData(encryptedBody, responseHash!);

        if (decrypted == null) {
          return ;
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
          'Phone Number Verification failed: ${response.body}',
          snackPosition: SnackPosition.BOTTOM,
          margin: EdgeInsets.all(20),
        );
        return false;
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Phone Number Verification failed',
        snackPosition: SnackPosition.BOTTOM,
        margin: EdgeInsets.all(20),
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }
}