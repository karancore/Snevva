import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../common/custom_snackbar.dart';
import '../../consts/consts.dart';
import '../../env/env.dart';
import '../../services/auth_header_helper.dart';
import '../../services/encryption_service.dart';

class ForgotPasswordController extends GetxController {
  var isLoading = false.obs;

  Future<dynamic> resetPasswordUsingGmail(
    String email,
    BuildContext context,
  ) async {
    if (email.isEmpty) {
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Email cannot be empty',
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
        final decrypted = EncryptionService.decryptData(
          encryptedBody,
          responseHash!,
        );

        if (decrypted == null) {
          return false;
        }

        final Map<String, dynamic> responseData = jsonDecode(decrypted);

        final data = responseData['data'];
        final otp = data['Otp'];

        // CustomSnackbar.showSuccess(
        //   context: context,
        //   title: 'Success',
        //   message: 'OTP Sent. $otp',
        // );
        return otp;
      } else {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Email Verification failed',
        );
        return false;
      }
    } catch (e) {
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Email Verification failed',
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<dynamic> resetPasswordUsingPhone(
    String phone,
    BuildContext context,
  ) async {
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
        final decrypted = EncryptionService.decryptData(
          encryptedBody,
          responseHash!,
        );

        if (decrypted == null) {
          return;
        }

        final Map<String, dynamic> responseData = jsonDecode(decrypted);
        print(responseData);

        final data = responseData['data'];
        final otp = data['Otp'];

        // CustomSnackbar.showSuccess(
        //   context: context,
        //   title: 'Success',
        //   message: 'OTP Sent. $otp',
        // );
        return otp;
      } else {
        print(response.body);
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Phone Number Verification failed',
        );
        return false;
      }
    } catch (e) {
      debugPrint(e.toString());
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Phone Number Verification failed',
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }
}
