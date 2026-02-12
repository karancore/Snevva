import 'package:flutter/gestures.dart';
import 'package:snevva/Widgets/SignInScreens/sign_in_footer_widget.dart';
import 'package:snevva/common/custom_snackbar.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/views/SignUp/sign_in_screen.dart';
import 'package:snevva/views/SignUp/verify_with_otp.dart';
import '../../Controllers/signupAndSignIn/otp_verification_controller.dart';
import '../../Controllers/signupAndSignIn/sign_up_controller.dart';
import '../../Widgets/SignInScreens/create_profile_header_widget.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  bool agreedToTerms = false;
  DateTime? selectedDate;

  final otpController = Get.find<OTPVerificationController>();

  final TextEditingController emailOrPasswordTextController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    otpController.isForgotPasswordScreen.value = false;
  }

  @override
  void dispose() {
    emailOrPasswordTextController.dispose();
    super.dispose();
  }

  final signupController = Get.put(SignUpController());

  bool isLoading = false;
  bool isSigningIn = false;

  Future<void> onButtonClick(String input) async {
    final emailRegex = RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[a-zA-Z]{2,4}$');
    final phoneRegex = RegExp(r'^[6-9]\d{9}$');

    try {
      if (emailRegex.hasMatch(input)) {
        final result = await signupController.signUpUsingGmail(input, context);

        if (result != null && result != false) {
          Get.to(
            VerifyWithOtpScreen(
              emailOrPasswordText: input,
              appBarText: AppLocalizations.of(context)!.verifyEmailAddress,
              responseOtp: result,
              isForgotPasswordScreen: false,
            ),
          );
          emailOrPasswordTextController.clear();
        }
      } else if (phoneRegex.hasMatch(input)) {
        final result = await signupController.signUpUsingPhone(input, context);
        print("result ${result.toString()}");

        if (result != null && result != false) {
          Get.to(
            VerifyWithOtpScreen(
              emailOrPasswordText: input,
              appBarText: AppLocalizations.of(context)!.verifyPhoneNumber,
              responseOtp: result,
              isForgotPasswordScreen: false,
            ),
          );
          emailOrPasswordTextController.clear();
        }
      } else {
        CustomSnackbar.showError(
          title: 'Error',
          message: 'Please Provide Correct Email or Phone Number',
          context: context,
        );
      }
    } catch (e, s) {
      print("❌ Caught error: $e");
      print("📌 Stack: $s");
      CustomSnackbar.showError(
        title: 'Error',
        message: 'Failed to create profile $e',
        context: context,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18, color: black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CreateProfileHeaderWidget(
                icon: Icon(Icons.email_outlined),
                textController: emailOrPasswordTextController,
              ),
              SizedBox(height: 30),
              Container(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ElevatedButton(
                  onPressed:
                      isLoading
                          ? null
                          : () async {
                            final input =
                                emailOrPasswordTextController.text.trim();
                            setState(() {
                              isLoading = true;
                            });
                            print("ElevatedButton $input");
                            await onButtonClick(input);
                            setState(() {
                              isLoading = false;
                            });
                          },
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
                      isLoading
                          ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : Text(AppLocalizations.of(context)!.nextText),
                ),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  const Expanded(child: Divider(thickness: 0.6)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(AppLocalizations.of(context)!.socialSignIn),
                  ),
                  const Expanded(
                    child: SizedBox(
                      width: double.infinity,
                      child: Divider(thickness: 0.6),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Google icon (always shown)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: () async {
                        setState(() {
                          isSigningIn = true; // Start the sign-in process
                        });
                        //await GoogleAuthService.signInWithGoogle(context);
                        setState(() {
                          isSigningIn =
                              false; // Sign-in complete, stop the loading indicator
                        });
                      },
                      icon: Image.asset(google, height: 28, width: 28),
                      padding: const EdgeInsets.all(12),
                      splashRadius: 28,
                    ),
                  ),

                  // // Facebook icon (conditionally shown)
                  // if (widget.facebookText != null)
                  //   IconButton(
                  //     onPressed: () {
                  //       // TODO: Handle Facebook login
                  //     },
                  //     icon: Image.asset(facebook, height: 32, width: 32),
                  //   ),
                  //
                  // // Apple icon (conditionally shown)
                  // if (widget.appleText != null)
                  //   IconButton(
                  //     onPressed: () {
                  //       // TODO: Handle Apple login
                  //     },
                  //     icon: Image.asset(apple, height: 32, width: 32),
                  //   ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(thickness: 1),
              const SizedBox(height: 12),

              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: AppLocalizations.of(context)!.alreadyHaveAccount,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                    TextSpan(text: " "),
                    TextSpan(
                      text: AppLocalizations.of(context)!.loginInText,

                      style: TextStyle(
                        color: AppColors.primaryColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                        decorationColor: AppColors.primaryColor,

                        decoration: TextDecoration.underline,
                      ),
                      recognizer:
                          TapGestureRecognizer()
                            ..onTap = () {
                              Get.offAll(SignInScreen());
                            },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
