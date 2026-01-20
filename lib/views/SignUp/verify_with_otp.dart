import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pinput/pinput.dart';
import 'package:smart_auth/smart_auth.dart';

import '../../Controllers/signupAndSignIn/otp_verification_controller.dart';
import '../../Controllers/signupAndSignIn/sign_up_controller.dart';
import '../../common/custom_snackbar.dart';
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

class _VerifyWithOtpScreenState extends State<VerifyWithOtpScreen> {
  late OTPVerificationController otpController;

  final smartAuth = SmartAuth.instance;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    otpController = Get.put(
      OTPVerificationController(
        widget.responseOtp,
        widget.emailOrPasswordText,
        widget.isForgotPasswordScreen,
      ),
    );

    _listenForSms();
  }

  Future<void> _listenForSms() async {
    final res = await smartAuth.getSmsWithUserConsentApi();

    if (!mounted || !res.hasData) return;

    final code = res.requireData.code;
    if (code == null) return;

    otpController.pinController.text = code;
    otpController.pinController.selection = TextSelection.fromPosition(
      TextPosition(offset: code.length),
    );

    if (!otpController.isVerifying.value &&
        code.trim() == widget.responseOtp.trim()) {
      otpController.verifyOtp(code, widget.responseOtp, context);
    }
  }

  @override
  void dispose() {
    smartAuth.removeSmsRetrieverApiListener();
    smartAuth.removeUserConsentApiListener();
    super.dispose();
  }

  Future<void> _onVerifyPressed() async {
    setState(() => _isLoading = true);

    final pin = otpController.pinController.text.trim();

    if (pin.length != 6) {
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Please enter valid 6 digit OTP',
      );
      setState(() => _isLoading = false);
      return;
    }

    final success = otpController.verifyOtp(pin, widget.responseOtp, context);

    setState(() => _isLoading = false);

    if (!success) {
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'OTP Verification Failed',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final defaultPinTheme = PinTheme(
      width: 60,
      height: 60,
      textStyle: TextStyle(
        fontSize: 24,
        color: isDarkMode ? white : black,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withOpacity(0.1) : white,
        borderRadius: BorderRadius.circular(8),
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
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios , size: 18,),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            Image.asset(veriemail, height: 200),
            const SizedBox(height: 30),
            Text(
              '${AppLocalizations.of(context)!.enter6DigitCodeText}\n${widget.emailOrPasswordText}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),

            Pinput(
              length: 6,
              controller: otpController.pinController,
              defaultPinTheme: defaultPinTheme,
              focusedPinTheme: focusedPinTheme,
              submittedPinTheme: submittedPinTheme,
              followingPinTheme: followingPinTheme,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onCompleted: (pin) {
                otpController.verifyOtp(pin, widget.responseOtp, context);
              },
            ),

            const SizedBox(height: 20),

            if (Platform.isAndroid)
              Text(
                'You may be prompted to allow one-tap OTP autofill.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: grey),
              ),

            const SizedBox(height: 20),

            InkWell(
              onTap: () async {
                final result = await SignUpController().signUpUsingGmail(
                  widget.emailOrPasswordText,
                  context,
                );

                if (result != null && result is String) {
                  otpController.responseOtp = result;
                }
              },
              child: Text(
                AppLocalizations.of(context)!.resendCode,
                style: TextStyle(
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.primaryColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  foreground:  Paint()
                    ..shader = AppColors.primaryGradient.createShader(
                      const Rect.fromLTWH(0, 0, 200, 20),
                    ),

                ),
              ),
            ),

            const SizedBox(height: 30),

            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ElevatedButton(
                onPressed:
                    otpController.isVerifying.value ? null : _onVerifyPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading ? const Loader() : const Text('Verify'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
