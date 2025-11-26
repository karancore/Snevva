
import 'package:snevva/services/encryption_service.dart';
import 'package:snevva/views/Sign%20Up/update_old_password.dart';
import '../../consts/consts.dart';
import '../../views/Sign Up/create_new_password.dart';

class OTPVerificationController extends GetxController {
  String responseOtp;
  final String emailOrPasswordText;
  final bool isForgotPasswordScreen;

  OTPVerificationController([this.responseOtp = '', this.emailOrPasswordText = '', this.isForgotPasswordScreen = false]);

  bool verifyOtp(String currentOtp) {

    if (currentOtp.isEmpty) {
      Get.snackbar(
        'Error',
        'OTP field cannot be empty.',
        snackPosition: SnackPosition.BOTTOM,
        margin: EdgeInsets.all(20),
      );
      return false;
    }
    if (responseOtp == currentOtp && isForgotPasswordScreen == false) {
      Get.snackbar(
        'Success',
        'Verification successful.',
        snackPosition: SnackPosition.BOTTOM,
        margin: EdgeInsets.all(20),
      );
      Get.to(
        CreateNewPassword(
          otpVerificationStatus: true,
          otp: responseOtp,
          emailOrPhoneText: emailOrPasswordText,
        ),
      );
      return true;
    }
    else if(responseOtp == currentOtp && isForgotPasswordScreen== true){
      Get.snackbar(
        'Success',
        'Verification successful.',
        snackPosition: SnackPosition.BOTTOM,
        margin: EdgeInsets.all(20),
      );
      Get.to(UpdateOldPasword(
        otpVerificationStatus: true,
        otp: responseOtp,
        emailOrPhoneText: emailOrPasswordText,));
      return true;
    }
    else {
      Get.snackbar(
        'Wrong OTP',
        'Verification failed.',
        snackPosition: SnackPosition.BOTTOM,
        margin: EdgeInsets.all(20),
      );
      return false;
    }
  }

  bool profileverifyOtp(String currentOtp, BuildContext ctx) {

    if (currentOtp.isEmpty) {
      Get.snackbar(
        'Error',
        'OTP field cannot be empty.',
        snackPosition: SnackPosition.BOTTOM,
        margin: EdgeInsets.all(20),
      );
      return false;
    }
    if (responseOtp == currentOtp && isForgotPasswordScreen == false) {
      Get.snackbar(
        'Success',
        'Verification successful.',
        snackPosition: SnackPosition.BOTTOM,
        margin: EdgeInsets.all(20),
      );
      // Navigator.pop(Get.context!);
      Navigator.of(ctx).pop();
      return true;
    }
    else {
      Get.snackbar(
        'Wrong OTP',
        'Verification failed.',
        snackPosition: SnackPosition.BOTTOM,
        margin: EdgeInsets.all(20),
      );
      return false;
    }
  }

}
