import 'dart:async';
import 'dart:io' show Platform;

import 'package:sms_autofill/sms_autofill.dart';

import '../../common/custom_snackbar.dart';
import '../../consts/consts.dart';
import '../../views/SignUp/create_new_password.dart';
import '../../views/SignUp/update_old_password.dart';

class OTPVerificationController extends GetxController with CodeAutoFill {
  String responseOtp;
  final pinController = TextEditingController();
  final String emailOrPasswordText;

  final bool isForgotPasswordScreen;

  var messageOtpCode = ''.obs;
  var isVerifying = false.obs;

  OTPVerificationController([
    this.responseOtp = '',
    this.emailOrPasswordText = '',
    this.isForgotPasswordScreen = false,
  ]);

  static const int otpLength = 6;

  void tryVerify(String code, BuildContext context, String responseOtp) {
    if (code.length == otpLength && !isVerifying.value && code == responseOtp) {
      isVerifying.value = true;
      verifyOtp(code, context);
    }
  }

  @override
  void onInit() {
    super.onInit();

    pinController.addListener(() {
      final text = pinController.text;
      if (Get.context != null) {
        tryVerify(text, Get.context!, pinController.text);
      }
    });

    // Start sms_autofill listener. For iOS this triggers the keyboard
    // one-time-code suggestion. On Android this will work only if your
    // backend includes the SMS retriever app hash; otherwise use the
    // User Consent API (requires a plugin or platform channel).
    _startSmsAutofill();
  }

  // Use a private helper that does not collide with CodeAutoFill.listenForCode
  void _startSmsAutofill() {
    try {
      SmsAutoFill().listenForCode();
    } catch (e) {
      debugPrint('sms_autofill listenForCode failed: $e');
    }
  }

  @override
  void codeUpdated() {
    if (code == null) return;

    messageOtpCode.value = code!;
    pinController.text = code!; // Update the text field visually

    if (code!.length == 6 && !isVerifying.value) {
      isVerifying.value = true;
      verifyOtp(code!, Get.context!);
    }
  }

  @override
  void onClose() {
    // Clean up sms_autofill listeners
    cancel();
    pinController.dispose();
    super.onClose();
  }

  bool verifyOtp(String currentOtp, BuildContext context) {
    if (responseOtp != currentOtp) {
      CustomSnackbar.showError(
        context: context,
        title: 'Wrong OTP',
        message: 'Verification failed.',
      );
      isVerifying.value = false;
      return false;
    }

    CustomSnackbar.showSuccess(
      context: context,
      title: 'Success',
      message: 'Verification successful.',
    );

    Get.to(
      isForgotPasswordScreen
          ? UpdateOldPasword(
            otpVerificationStatus: true,
            otp: responseOtp,
            emailOrPhoneText: emailOrPasswordText,
          )
          : CreateNewPassword(
            otpVerificationStatus: true,
            otp: responseOtp,
            emailOrPhoneText: emailOrPasswordText,
          ),
    );

    return true;
  }
}
