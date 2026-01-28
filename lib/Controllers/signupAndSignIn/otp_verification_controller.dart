import 'package:sms_autofill/sms_autofill.dart';

import '../../common/custom_snackbar.dart';
import '../../consts/consts.dart';
import '../../views/SignUp/create_new_password.dart';
import '../../views/SignUp/update_old_password.dart';

class OTPVerificationController extends GetxService {
  RxString responseOtp = ''.obs;
  final pinController = TextEditingController();
  RxString emailOrPasswordText = ''.obs;
  RxBool isForgotPasswordScreen = false.obs;

  var isVerifying = false.obs;

  OTPVerificationController({bool isForgotPasswordScreen = false}) {
    this.isForgotPasswordScreen.value = isForgotPasswordScreen;
  }

  // @override
  // void onInit() {
  //   super.onInit();
  //   _startSmsAutofill();
  // }
  @override
  void onReady() {
    super.onReady();
    _startSmsAutofill();
  }


  @override
  void onClose() {
    pinController.dispose();
    isVerifying = false.obs;

    super.onClose();
  }

  void _startSmsAutofill() {
    try {
      SmsAutoFill().listenForCode();
    } catch (e) {
      debugPrint('sms_autofill error: $e');
    }
  }

  bool verifyOtp(String enteredOtp, String responseOtpp, BuildContext context) {
    debugPrint('🔐 [verifyOtp] CALLED');

    final normalizedEnteredOtp = enteredOtp.trim();
    final normalizedResponseOtp = responseOtpp.trim();

    debugPrint('🧪 Entered OTP (raw): "$enteredOtp"');
    debugPrint('🧪 Entered OTP (normalized): "$normalizedEnteredOtp"');
    debugPrint('🧪 Response OTP (raw): "$responseOtpp"');
    debugPrint('🧪 Response OTP (normalized): "$normalizedResponseOtp"');

    if (isVerifying.value) {
      debugPrint('⏳ OTP verification already in progress — skipping');
      return false;
    }

    isVerifying.value = true;
    debugPrint('🔄 isVerifying set to TRUE');

    if (normalizedEnteredOtp != normalizedResponseOtp) {
      debugPrint('❌ OTP MISMATCH');

      CustomSnackbar.showError(
        context: context,
        title: 'Wrong OTP',
        message: 'Verification failed.',
      );

      isVerifying.value = false;
      debugPrint('🔄 isVerifying reset to FALSE');

      return false;
    }

    debugPrint('✅ OTP MATCHED — verification successful');

    CustomSnackbar.showSuccess(
      context: context,
      title: 'Success',
      message: 'Verification successful.',
    );

    debugPrint(
      '➡️ Navigating to ${isForgotPasswordScreen.value ? "UpdateOldPassword" : "CreateNewPassword"}',
    );

    print("$emailOrPasswordText");
    print("isForgotPasswordScreen.value ${isForgotPasswordScreen.value}");

    Get.to(
      () =>
          isForgotPasswordScreen.value
              ? UpdateOldPasword(
                otpVerificationStatus: true,
                otp: normalizedResponseOtp,
                emailOrPhoneText: emailOrPasswordText.value,
              )
              : CreateNewPassword(
                otpVerificationStatus: true,
                otp: normalizedResponseOtp,
                emailOrPhoneText: emailOrPasswordText.value,
              ),
    );

    debugPrint('🏁 [verifyOtp] COMPLETED SUCCESSFULLY');
    return true;
  }
}
