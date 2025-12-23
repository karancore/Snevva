import 'package:sms_autofill/sms_autofill.dart';
import 'package:snevva/Controllers/local_storage_manager.dart';
import 'package:snevva/Controllers/signupAndSignIn/sign_up_controller.dart';
import 'package:snevva/common/custom_snackbar.dart';
import 'package:snevva/views/SignUp/create_new_password.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';
import 'package:snevva/views/SignUp/update_old_password.dart';
import '../../Controllers/signupAndSignIn/otp_verification_controller.dart';
import '../../common/loader.dart';
import '../../consts/consts.dart';

class VerifyWithOtpScreen extends StatefulWidget {
  final String emailOrPasswordText;
  final String appBarText;
  final String responseOtp;
  final bool isForgotPasswordScreen;

  const VerifyWithOtpScreen({
    super.key,
    required this.emailOrPasswordText,
    required this.appBarText,
    required this.responseOtp,
    required this.isForgotPasswordScreen,
  });

  @override
  State<VerifyWithOtpScreen> createState() => _VerifyWithOtpScreenState();
}

class _VerifyWithOtpScreenState extends State<VerifyWithOtpScreen>
    with CodeAutoFill {
  final pinController = TextEditingController();
  late OTPVerificationController otpVerificationController;
  late bool otpVerificationStatus;
  bool _isLoading = false;
  final localStorageManager = Get.put(LocalStorageManager());

  @override
  void initState() {
    super.initState();
    listenForCode();

    if (Get.isRegistered<OTPVerificationController>()) {
      Get.delete<OTPVerificationController>();
    }

    otpVerificationController = Get.put(
      OTPVerificationController(
        widget.responseOtp,
        widget.emailOrPasswordText,
        widget.isForgotPasswordScreen,
      ),
    );
  }

  @override
  void dispose() {
    pinController.dispose();
    if (Get.isRegistered<OTPVerificationController>()) {
      Get.delete<OTPVerificationController>();
    }
    super.dispose();
  }

  void onButtonClick() {
    setState(() {
      _isLoading = true;
    });
    final pin = pinController.text.trim();

    if (pin.isEmpty) {
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'OTP field cannot be empty.',
      );
      return;
    }
    if (otpVerificationStatus == true &&
        widget.isForgotPasswordScreen == false) {
      // Store email in userMap
      localStorageManager.userMap['Email'] = widget.emailOrPasswordText;
      localStorageManager.userMap['PhoneNumber'] = widget.emailOrPasswordText;

      print("dfdfdfdfdfdfdfdfdfdfdfdfdfdfd${localStorageManager.userMap}");

      setState(() {
        _isLoading = false;
      });

      Get.to(
        CreateNewPassword(
          otpVerificationStatus: otpVerificationStatus,
          otp: widget.responseOtp,
          emailOrPhoneText: widget.emailOrPasswordText,
        ),
      );
    } else if (otpVerificationStatus == true &&
        widget.isForgotPasswordScreen == true) {
      // Store email in userMap
      localStorageManager.userMap['Email'] = widget.emailOrPasswordText;
      localStorageManager.userMap['PhoneNumber'] = widget.emailOrPasswordText;

      setState(() {
        _isLoading = false;
      });

      Get.to(
        UpdateOldPasword(
          otpVerificationStatus: true,
          otp: widget.responseOtp,
          emailOrPhoneText: widget.emailOrPasswordText,
        ),
      );
    } else {
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'OTP Verification Failed',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;

    debugPrint('Response otp is ${widget.responseOtp}');
    final defaultPinTheme = PinTheme(
      width: 60,
      height: 60,
      textStyle: TextStyle(
        fontSize: 24,
        color: isDarkMode ? white : black,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.transparent),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: grey, width: 2),
      ),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: grey),
      ),
    );

    final followingPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.appBarText),
        centerTitle: true,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 10),
              Image.asset(veriemail, height: 200, width: 200),
              SizedBox(height: 30),
              Text(
                '${AppLocalizations.of(context)!.enter6DigitCodeText}\n${widget.emailOrPasswordText}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 30),

              Pinput(
                length: 6,
                controller: pinController,
                defaultPinTheme: defaultPinTheme,
                focusedPinTheme: focusedPinTheme,

                submittedPinTheme: submittedPinTheme,
                followingPinTheme: followingPinTheme,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onCompleted:
                    (pin) =>
                        otpVerificationStatus = otpVerificationController
                            .verifyOtp(pin, context),
              ),

              SizedBox(height: 15),
              GestureDetector(
                onTap: () async {
                  final result = await SignUpController().signUpUsingGmail(
                    widget.emailOrPasswordText,
                    context,
                  );

                  if (result != false) {
                    // 🔹 Update the OTP in controller
                    otpVerificationController.responseOtp = result;
                  }
                },
                child: ShaderMask(
                  shaderCallback:
                      (bounds) => AppColors.primaryGradient.createShader(
                        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                      ),
                  child: Text(
                    AppLocalizations.of(context)!.resendCode,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: Colors.white,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.primaryColor,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 30),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ElevatedButton(
                  onPressed: onButtonClick,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child:
                      _isLoading
                          ? const Loader()
                          : Text(AppLocalizations.of(context)!.verify),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void codeUpdated() {
    // TODO: implement codeUpdated
  }
}
