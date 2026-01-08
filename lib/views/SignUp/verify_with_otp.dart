import 'package:smart_auth/smart_auth.dart';
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
import 'dart:io' show Platform;

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

class _VerifyWithOtpScreenState extends State<VerifyWithOtpScreen> {
  late OTPVerificationController otpVerificationController;
  late bool otpVerificationStatus;
  String? appSignature;
  final smartAuth = SmartAuth.instance;
  bool _isLoading = false;
  // late SmsUserConsent smsUserConsent;
  final localStorageManager = Get.put(LocalStorageManager());

  @override
  void initState() {
    super.initState();
    userConsent();

    if (Get.isRegistered<OTPVerificationController>()) {
      Get.delete<OTPVerificationController>();
    }

    //if (Platform.isAndroid) onSmsReceived();

    otpVerificationController = Get.put(
      OTPVerificationController(
        widget.responseOtp,
        widget.emailOrPasswordText,
        widget.isForgotPasswordScreen,
      ),
    );
  }
  // Future<void> onSmsReceived() async {
  //   smsUserConsent = SmsUserConsent(
  //       phoneNumberListener: () => setState(() {}),
  //       smsListener: () => setState(() {}));

  // }

  @override
  void dispose() {
    /// Removes the listeners if the SMS code is not received yet
    smartAuth.removeSmsRetrieverApiListener();

    /// Removes the listeners if the SMS code is not received yet
    smartAuth.removeUserConsentApiListener();

    if (Get.isRegistered<OTPVerificationController>()) {
      Get.delete<OTPVerificationController>();
    }
    super.dispose();
  }

  Future<void> getAppSignature() async {
    final res = await smartAuth.getAppSignature();
    setState(() => appSignature = res.data);
    debugPrint('Signature: $res');
  }

  Future<void> userConsent() async {
    final res = await smartAuth.getSmsWithUserConsentApi();
    if (res.hasData) {
      debugPrint('userConsent: $res');
      final code = res.requireData.code;

      /// The code can be null if the SMS was received but
      /// the code was not extracted from it
      if (code == null) return;
      otpVerificationController.pinController.text = code;
      if (otpVerificationController.pinController.text == widget.responseOtp) {
        otpVerificationController.verifyOtp(
          otpVerificationController.pinController.text,
          context,
        );
      }
      otpVerificationController
          .pinController
          .selection = TextSelection.fromPosition(
        TextPosition(
          offset: otpVerificationController.pinController.text.length,
        ),
      );
    } else if (res.isCanceled) {
      debugPrint('userConsent canceled');
    } else {
      debugPrint('userConsent failed: $res');
    }
  }

  Future<void> smsRetriever() async {
    final res = await smartAuth.getSmsWithRetrieverApi();
    if (res.hasData) {
      debugPrint('smsRetriever: $res');
      final code = res.requireData.code;

      /// The code can be null if the SMS was received but
      /// the code was not extracted from it
      if (code == null) return;
      otpVerificationController.pinController.text = code;
      otpVerificationController
          .pinController
          .selection = TextSelection.fromPosition(
        TextPosition(
          offset: otpVerificationController.pinController.text.length,
        ),
      );
    } else {
      debugPrint('smsRetriever failed: $res');
    }
  }

  Future<void> requestPhoneNumberHint() async {
    final res = await smartAuth.requestPhoneNumberHint();
    if (res.hasData) {
      // Use the phone number
    } else {
      // Handle error
    }
    debugPrint('requestHint: $res');
  }

  Future<void> onButtonClick() async {
    setState(() => _isLoading = true);

    // smsRetriever();
    // getAppSignature();

    final pin = otpVerificationController.pinController.text.trim();

    if (pin.length != 6) {
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Please enter valid 6 digit OTP',
      );
      setState(() => _isLoading = false);
      return;
    }

    final result = otpVerificationController.verifyOtp(pin, context);

    setState(() => _isLoading = false);

    if (!result) {
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'OTP Verification Failed',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Listens to the app's current theme command
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
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
    // if (Platform.isAndroid) {
    //   var receivedSms = smsUserConsent.receivedSms ?? '';
    //   var smsOTP = receivedSms.replaceAll(RegExp(r'[^0-9]'), '');
    //   if (smsOTP.isNotEmpty) {
    //     otpVerificationController.pinController.text = smsOTP;
    //   }
    // }

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

              PinFieldAutoFill(
                codeLength: 6,
                decoration: BoxLooseDecoration(
                  textStyle: TextStyle(
                    fontSize: 20,
                    color:
                        isDarkMode
                            ? Colors.white
                            : Colors.black, // text visible
                  ),
                  bgColorBuilder:
                      isDarkMode
                          ? FixedColorBuilder(Colors.black) // box background
                          : FixedColorBuilder(Colors.white),
                  strokeColorBuilder:
                      isDarkMode
                          ? FixedColorBuilder(Colors.grey) // border color
                          : FixedColorBuilder(Colors.grey[300]!),
                  radius: Radius.circular(8),
                  gapSpace: 10,
                ),

                controller: otpVerificationController.pinController,
                currentCode: otpVerificationController.messageOtpCode.value,
                textInputAction: TextInputAction.done,
                onCodeChanged: (code) {
                  if (code != null) {
                    otpVerificationController.messageOtpCode.value = code;
                    print(
                      'Code changed: ${otpVerificationController.messageOtpCode.value}',
                    );
                    // otpVerificationController
                    //     .tryVerify(code, context, widget.responseOtp);
                  }
                },
              ),

              SizedBox(height: 15),
              if (Platform.isAndroid) ...[
                SizedBox(height: 8),
                Text(
                  'You may be prompted to allow one-tap to paste the OTP from your SMS. Tap Allow to autofill.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: grey),
                ),
              ],
              InkWell(
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
}
