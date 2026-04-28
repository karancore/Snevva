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
  void onClose() {
    pinController.dispose();
    isVerifying = false.obs;

    super.onClose();
  }

  // void _startSmsAutofill() {
  //   try {
  //     SmsAutoFill().listenForCode();
  //   } catch (e) {
  //     debugPrint('sms_autofill error: $e');
  //   }
  // }

  bool verifyOtp(String enteredOtp,
      String responseOtpp,

    BuildContext context, {
    bool? isEditPassword,
  }) {
    debugPrint('🔐 [verifyOtp] CALLED');

    final normalizedEnteredOtp = enteredOtp.trim();
    final normalizedResponseOtp = responseOtpp.trim();

    if (isVerifying.value) {
      debugPrint('⏳ OTP verification already in progress — skipping');
      return false;
    }

    isVerifying.value = true;

    try {
      if (normalizedEnteredOtp != normalizedResponseOtp) {
        debugPrint('❌ OTP MISMATCH');

        CustomSnackbar.showError(
          context: context,
          title: 'Wrong OTP',
          message: 'Verification failed.',
        );

        return false;
      }

      debugPrint('✅ OTP MATCHED — verification successful');

      CustomSnackbar.showSuccess(
        context: context,
        title: 'Success',
        message: 'Verification successful.',
      );

      if (isEditPassword == true) {
        return true;
      }

      Get.to(
            () =>
        isForgotPasswordScreen.value
            ? UpdateOldPassword(
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

      return true;
    } finally {
      // ✅ ALWAYS RESET (this is the key fix)
      isVerifying.value = false;
      debugPrint('🔄 isVerifying reset to FALSE');
    }
  }
}
