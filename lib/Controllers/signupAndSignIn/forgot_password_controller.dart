import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:snevva/services/device_token_service.dart';
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
    debugPrint('📩 [ForgotPassword][GMAIL] Email received: $email');

    if (email.isEmpty) {
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Email cannot be empty',
      );
      return false;
    }

    final plainEmail = jsonEncode({'Gmail': email});
    debugPrint('📝 Plain Email Payload: $plainEmail');

    isLoading.value = true;

    try {
      final uri = Uri.parse("$baseUrl$forgotEmailOtpEndpoint");
      debugPrint('🌐 API URL: $uri');

      final encryptedEmail = EncryptionService.encryptData(plainEmail);
      debugPrint('🔐 Encrypted Email Hash: ${encryptedEmail['Hash']}');
      debugPrint(
        '🔐 Encrypted Email Data Length: ${encryptedEmail['encryptedData']?.length}',
      );

      final headers = await AuthHeaderHelper.getHeaders(withAuth: false);
      headers['x-data-hash'] = encryptedEmail['Hash']!;
      debugPrint('📦 Request Headers: $headers');

      final deviceInfoHeader =
          await DeviceTokenService().buildDeviceInfoHeader();
      
      headers['X-Device-Info'] = deviceInfoHeader;

      final encryptedBody = jsonEncode({
        'data': encryptedEmail['encryptedData'],
      });
      debugPrint('📤 Encrypted Request Body Length: ${encryptedBody.length}');

      final response = await http.post(
        uri,
        headers: headers,
        body: encryptedBody,
      );

      debugPrint('📥 Response Status Code: ${response.statusCode}');
      debugPrint('📥 Raw Response Body: ${response.body}');
      debugPrint('📥 Response Headers: ${response.headers}');

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final encryptedBody = responseBody['data'];
        final responseHash = response.headers['x-data-hash'];

        debugPrint(
          '🔓 Encrypted Response Data Length: ${encryptedBody?.length}',
        );
        debugPrint('🔓 Response Hash: $responseHash');

        final decrypted = EncryptionService.decryptData(
          encryptedBody,
          responseHash!,
        );

        debugPrint('✅ Decrypted Response: $decrypted');

        if (decrypted == null) {
          debugPrint('❌ Decryption failed');
          return false;
        }

        final Map<String, dynamic> responseData = jsonDecode(decrypted);
        debugPrint('📊 Parsed Response JSON: $responseData');

        final data = responseData['data'];
        final otp = data['Otp'];

        debugPrint('🔢 OTP Received: $otp');

        return otp;
      } else {
        debugPrint('❌ Email verification failed');
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Email Verification failed',
        );
        return false;
      }
    } catch (e, stack) {
      debugPrint('🔥 Exception occurred: $e');
      debugPrint('📍 Stacktrace: $stack');

      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Email Verification failed',
      );
      return false;
    } finally {
      isLoading.value = false;
      debugPrint('⏹️ Loading stopped (Gmail)');
    }
  }

  Future<dynamic> resetPasswordUsingPhone(
    String phone,
    BuildContext context,
  ) async {
    debugPrint('📞 [ForgotPassword][PHONE] Phone received: $phone');

    if (phone.isEmpty) {
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Phone cannot be empty',
      );
      return false;
    }

    final plainPhone = jsonEncode({'PhoneNumber': phone});
    debugPrint('📝 Plain Phone Payload: $plainPhone');

    isLoading.value = true;

    try {
      final uri = Uri.parse("$baseUrl$forgotPhoneOtpEndpoint");
      debugPrint('🌐 API URL: $uri');

      final encryptedPhone = EncryptionService.encryptData(plainPhone);
      debugPrint('🔐 Encrypted Phone Hash: ${encryptedPhone['Hash']}');
      debugPrint(
        '🔐 Encrypted Phone Data Length: ${encryptedPhone['encryptedData']?.length}',
      );

      final headers = await AuthHeaderHelper.getHeaders(withAuth: false);
      headers['x-data-hash'] = encryptedPhone['Hash']!;
      debugPrint('📦 Request Headers: $headers');

      final deviceInfoHeader =
          await DeviceTokenService().buildDeviceInfoHeader();
      
      headers['X-Device-Info'] = deviceInfoHeader;

      final encryptedBody = jsonEncode({
        'data': encryptedPhone['encryptedData'],
      });
      debugPrint('📤 Encrypted Request Body Length: ${encryptedBody.length}');

      final response = await http.post(
        uri,
        headers: headers,
        body: encryptedBody,
      );

      debugPrint('📥 Response Status Code: ${response.statusCode}');
      debugPrint('📥 Raw Response Body: ${response.body}');
      debugPrint('📥 Response Headers: ${response.headers}');

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final encryptedBody = responseBody['data'];
        final responseHash = response.headers['x-data-hash'];

        debugPrint(
          '🔓 Encrypted Response Data Length: ${encryptedBody?.length}',
        );
        debugPrint('🔓 Response Hash: $responseHash');

        final decrypted = EncryptionService.decryptData(
          encryptedBody,
          responseHash!,
        );

        debugPrint('✅ Decrypted Response: $decrypted');

        if (decrypted == null) {
          debugPrint('❌ Decryption failed');
          return false;
        }

        final Map<String, dynamic> responseData = jsonDecode(decrypted);
        debugPrint('📊 Parsed Response JSON: $responseData');

        final data = responseData['data'];
        final otp = data['Otp'];

        debugPrint('🔢 OTP Received: $otp');

        return otp;
      } else {
        debugPrint('❌ Phone verification failed');
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Phone Number Verification failed',
        );
        return false;
      }
    } catch (e, stack) {
      debugPrint('🔥 Exception occurred: $e');
      debugPrint('📍 Stacktrace: $stack');

      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Phone Number Verification failed',
      );
      return false;
    } finally {
      isLoading.value = false;
      debugPrint('⏹️ Loading stopped (Phone)');
    }
  }
}
