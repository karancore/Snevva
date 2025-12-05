import 'package:snevva/services/encryption_service.dart';
import 'package:snevva/views/Sign%20Up/update_old_password.dart';
import '../../common/custom_snackbar.dart';
import '../../consts/consts.dart';
import '../../views/Sign Up/create_new_password.dart';

class OTPVerificationController extends GetxController {
  String responseOtp;
  final String emailOrPasswordText;
  final bool isForgotPasswordScreen;

  OTPVerificationController([
    this.responseOtp = '',
    this.emailOrPasswordText = '',
    this.isForgotPasswordScreen = false,
  ]);

  bool verifyOtp(String currentOtp, BuildContext context) {
    if (currentOtp.isEmpty) {
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'OTP field cannot be empty.',
      );
      return false;
    }
    if (responseOtp == currentOtp && isForgotPasswordScreen == false) {
      CustomSnackbar.showSuccess(
        context: context,
        title: 'Success',
        message: 'Verification successful.',
      );
      Get.to(
        CreateNewPassword(
          otpVerificationStatus: true,
          otp: responseOtp,
          emailOrPhoneText: emailOrPasswordText,
        ),
      );
      return true;
    } else if (responseOtp == currentOtp && isForgotPasswordScreen == true) {
      CustomSnackbar.showSuccess(
        context: context,
        title: 'Success',
        message: 'Verification successful.',
      );
      Get.to(
        UpdateOldPasword(
          otpVerificationStatus: true,
          otp: responseOtp,
          emailOrPhoneText: emailOrPasswordText,
        ),
      );
      return true;
    } else {
      CustomSnackbar.showError(
        context: context,
        title: 'Wrong OTP',
        message: 'Verification failed.',
      );
      return false;
    }
  }

  bool profileverifyOtp(String currentOtp, BuildContext context) {
    if (currentOtp.isEmpty) {
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'OTP field cannot be empty.',
      );
      return false;
    }
    if (responseOtp == currentOtp && isForgotPasswordScreen == false) {
      CustomSnackbar.showError(
        context: context,
        title: 'Success',
        message: 'Verification successful.',
      );
      // Navigator.pop(Get.context!);
      Navigator.of(context).pop();
      return true;
    } else {
      CustomSnackbar.showError(
        context: context,
        title: 'Wrong OTP',
        message: 'Verification failed.',
      );
      return false;
    }
  }
}
