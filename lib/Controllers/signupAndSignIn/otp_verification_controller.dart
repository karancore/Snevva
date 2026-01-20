

import 'package:sms_autofill/sms_autofill.dart';

import '../../common/custom_snackbar.dart';
import '../../consts/consts.dart';
import '../../views/SignUp/create_new_password.dart';
import '../../views/SignUp/update_old_password.dart';

class OTPVerificationController extends GetxController {
  String responseOtp;
  final pinController = TextEditingController();
  final String emailOrPasswordText;
  final bool isForgotPasswordScreen;

  var isVerifying = false.obs;

  OTPVerificationController(
      [this.responseOtp = '',
        this.emailOrPasswordText = '',
        this.isForgotPasswordScreen = false,]
      );

  @override
  void onInit() {
    super.onInit();
    _startSmsAutofill();
  }

  void _startSmsAutofill() {
    try {
      SmsAutoFill().listenForCode();
    } catch (e) {
      debugPrint('sms_autofill error: $e');
    }
  }

  bool verifyOtp(String enteredOtp, String responseOtpp, BuildContext context) {
    final normalizedEnteredOtp = enteredOtp.trim();
    final normalizedResponseOtp = responseOtpp.trim();

    if (isVerifying.value) return false;
    isVerifying.value = true;

    debugPrint('🧪 Entered OTP: $normalizedEnteredOtp');
    debugPrint('🧪 Response OTP: $normalizedResponseOtp');

    if (normalizedEnteredOtp != normalizedResponseOtp) {
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

    Get.to(() => isForgotPasswordScreen
        ? UpdateOldPasword(
      otpVerificationStatus: true,
      otp: normalizedResponseOtp,
      emailOrPhoneText: emailOrPasswordText,
    )
        : CreateNewPassword(
      otpVerificationStatus: true,
      otp: normalizedResponseOtp,
      emailOrPhoneText: emailOrPasswordText,
    ));

    return true;
  }


}
