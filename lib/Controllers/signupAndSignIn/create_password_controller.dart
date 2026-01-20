import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/Controllers/local_storage_manager.dart';
import 'package:snevva/common/custom_snackbar.dart';
import 'package:snevva/services/auth_header_helper.dart';
import 'package:snevva/services/encryption_service.dart';
import 'package:snevva/views/ProfileAndQuestionnaire/profile_setup_initial.dart';
import '../../../consts/consts.dart';
import '../../../env/env.dart';

class CreatePasswordController extends GetxController {
  var password = ''.obs;
  var confirmPassword = ''.obs;
  var isChecked = false.obs;

  bool get hasLetter => RegExp(r'[A-Za-z]').hasMatch(password.value);

  bool get hasNumberOrSymbol =>
      RegExp(r'[0-9!@#$&*~?]').hasMatch(password.value);

  bool get hasMinLength => password.value.length >= 10;

  var isLoading = false.obs;

  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  var obscurePassword = true.obs;
  var obscurePassword2 = true.obs;

  bool get isPasswordValid {
    final pwd = password.value;
    return pwd.length >= 10 &&
        RegExp(r'[A-Za-z]').hasMatch(pwd) &&
        RegExp(r'[0-9!@#$&*~?]').hasMatch(pwd);
  }

  bool get isConfirmPasswordValid =>
      password.value == confirmPassword.value &&
      confirmPassword.value.isNotEmpty;

  final localStorageManager = Get.find<LocalStorageManager>();

  @override
  void onInit() {
    isChecked.value = false;
    super.onInit();
  }

  @override
  void onClose() {
    passwordController.dispose();
    confirmPasswordController.dispose();
    isChecked.value = false;
    super.onClose();
  }

  Future<dynamic> createNewPasswordWithGmail(
    String email,
    String otp,
    bool verificationStatus,
    String password,
    BuildContext context,
    String? extraHeaders, 
  ) async {
    final newPlanePassword = jsonEncode({
      'Gmail': email,
      'Otp': otp,
      'IsVerified': verificationStatus,
      'Password': password,
    });

    try {
      final uri = Uri.parse("$baseUrl$createPswdEmailEndpoint");
      final encryptedPassword = EncryptionService.encryptData(newPlanePassword);
      final headers = await AuthHeaderHelper.getHeaders(withAuth: false);

      headers['X-Data-Hash'] = encryptedPassword['hash']!;

      if (extraHeaders != null) {
  headers['X-Device-Info'] = extraHeaders;
}

      final encryptedBody = jsonEncode({
        'data': encryptedPassword['encryptedData'],
      });

      final response = await http.post(
        uri,
        headers: headers,
        body: encryptedBody,
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        print("response Body: $responseBody");

        final encryptedBody = responseBody['data'];
        print("👉 Encrypted token response: $encryptedBody");

        final responseHash = response.headers['x-data-hash'];
        print("👉 Response hash: $responseHash");

        final decrypted = EncryptionService.decryptData(
          encryptedBody,
          responseHash!,
        );
        print("Decrypted token response: $decrypted");

        if (decrypted == null) {
          CustomSnackbar.showError(
            context: context,
            title: 'Error',
            message: 'Failed to decrypt response',
          );
          return false;
        }

        final Map<String, dynamic> responseData = jsonDecode(decrypted);

        final token = responseData['data'];
        print("👉 Token: $token");

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);

        confirmPasswordController.clear();
        passwordController.clear();
        isChecked.value = false;
        CustomSnackbar.showSuccess(
          context: context,
          title: 'Success',
          message: 'Password Created Successfully with gmail',
        );

        localStorageManager.registerDeviceFCMIfNeeded();

        Get.offAll(() => ProfileSetupInitial()); // 👈 clears previous stack
      }
    } catch (e) {
      CustomSnackbar.showError(
        context: context,
        title: 'Failed',
        message: 'Password Creation Failed',
      );
    }
  }

  Future<dynamic> createNewPasswordWithPhone(
    String phone,
    String otp,
    bool verificationStatus,
    String password,
    BuildContext context,
    String? extraHeaders, 
  ) async {
    final newPlanePassword = jsonEncode({
      'PhoneNumber': phone,
      'Otp': otp,
      'IsVerified': verificationStatus,
      'Password': password,
    });

    try {
      final uri = Uri.parse("$baseUrl$createPswdPhoneEndpoint");
      final encryptedPassword = EncryptionService.encryptData(newPlanePassword);
      final headers = await AuthHeaderHelper.getHeaders(withAuth: false);

      headers['X-Data-Hash'] = encryptedPassword['hash']!;

      if (extraHeaders != null) {
  headers['X-Device-Info'] = extraHeaders;
}

      final encryptedBody = jsonEncode({
        'data': encryptedPassword['encryptedData'],
      });

      final response = await http.post(
        uri,
        headers: headers,
        body: encryptedBody,
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        print("response Body: $responseBody");

        final encryptedBody = responseBody['data'];
        print("👉 Encrypted token response: $encryptedBody");

        final responseHash = response.headers['x-data-hash'];
        print("👉 Response hash: $responseHash");

        final decrypted = EncryptionService.decryptData(
          encryptedBody,
          responseHash!,
        );
        print("Decrypted token response: $decrypted");

        if (decrypted == null) {
          CustomSnackbar.showError(
            context: context,
            title: 'Error',
            message: 'Failed to decrypt response',
          );
          return false;
        }

        final Map<String, dynamic> responseData = jsonDecode(decrypted);

        final token = responseData['data'];
        print("👉 Token: $token");

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);

        confirmPasswordController.clear();
        passwordController.clear();
        isChecked.value = false;
        CustomSnackbar.showSuccess(
          context: context,
          title: 'Success',
          message: 'Password Created Successfully with gmail',
        );

        localStorageManager.registerDeviceFCMIfNeeded();

        Get.offAll(() => ProfileSetupInitial()); // 👈 clears previous stack
      } else {
        print('❌ HTTP Error: ${response.statusCode} - ${response.body}');
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Failed to create password. Please try again.',
        );
      }
    } catch (e) {
      CustomSnackbar.showError(
        context: context,
        title: 'Failed',
        message: 'Password Creation Failed',
      );
    }
  }
}
