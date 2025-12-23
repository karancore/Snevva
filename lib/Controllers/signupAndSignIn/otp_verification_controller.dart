/*


class OTPVerificationController extends GetxController {
  String responseOtp;
  final String emailOrPasswordText;
  final bool isForgotPasswordScreen;
  var messageOtpCode = ''.obs;

  @override
  void onInit() {
    super.onInit();
    SmsAutoFill().getAppSignature.then((signature) {
      print(signature);
    });

    listenForCode();
  }

  Future<void> listenForCode() async {
    await SmsAutoFill().listenForCode();
  }

  @override
  void onClose() {
    super.onClose();
    SmsAutoFill().unregisterListener();
  }

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
*/
import 'package:sms_autofill/sms_autofill.dart';
import 'package:snevva/services/encryption_service.dart';
import 'package:snevva/views/SignUp/update_old_password.dart';
import '../../common/custom_snackbar.dart';
import '../../consts/consts.dart';
import '../../views/SignUp/create_new_password.dart';
class OTPVerificationController extends GetxController
    with CodeAutoFill {

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

  @override
  void onInit() {
    super.onInit();
    SmsAutoFill().getAppSignature.then((signature){
      print("App Signature is $signature");
    });
    listenForCode();
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

