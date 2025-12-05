import 'package:snevva/Widgets/SignInScreens/sign_in_footer_widget.dart';
import 'package:snevva/common/custom_snackbar.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/views/Sign%20Up/sign_in_screen.dart';
import 'package:snevva/views/Sign%20Up/verify_with_otp.dart';
import '../../Controllers/signupAndSignIn/sign_up_controller.dart';
import '../../Widgets/SignInScreens/create_profile_header_widget.dart';

class CreateNewProfile extends StatefulWidget {
  const CreateNewProfile({super.key});

  @override
  State<CreateNewProfile> createState() => _CreateNewProfileState();
}

final TextEditingController emailOrPasswordTextController =
    TextEditingController();

class _CreateNewProfileState extends State<CreateNewProfile> {
  bool agreedToTerms = false;
  DateTime? selectedDate;

  @override
  void dispose() {
    super.dispose();
  }

  final signupController = Get.find<SignUpController>();

  bool isLoading = false;
  bool isSigningIn = false;

  @override
  Widget build(BuildContext context) {
    Future<void> onButtonClick() async {
      if (isLoading) return;
      setState(() => isLoading = true);

      try {
        if (emailOrPasswordTextController.text.toString().contains('@')) {
          final result = await signupController.signUpUsingGmail(
            emailOrPasswordTextController.text.toString().trim(),
            context
          );

          if (result != false && result != null) {
            Get.to(
              VerifyWithOtpScreen(
                emailOrPasswordText:
                    emailOrPasswordTextController.text.toString().trim(),
                appBarText: AppLocalizations.of(context)!.verifyEmailAddress,
                responseOtp: result,
                isForgotPasswordScreen: false,
              ),
            );
            emailOrPasswordTextController.clear();
          }
        } else if (RegExp(
          r'^\d{10,}$',
        ).hasMatch(emailOrPasswordTextController.text.toString())) {
          final result = await signupController.signUpUsingPhone(
            emailOrPasswordTextController.text.toString().trim(),
            context
          );

          if (result != false && result != null) {
            Get.to(
              VerifyWithOtpScreen(
                emailOrPasswordText:
                    emailOrPasswordTextController.text.toString().trim(),
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
      } catch (e) {
        CustomSnackbar.showError(
          title: 'Error',
          message: 'Please Provide Correct Email or Phone Number',
          context: context,
        );
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    }

    return Scaffold(
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
                  onPressed: isLoading ? null : onButtonClick,
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

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AutoSizeText(
                    AppLocalizations.of(context)!.alreadyHaveAccount,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Get.offAll(SignInScreen());
                    },
                    child: Text(
                      AppLocalizations.of(context)!.loginInText,
                      style: const TextStyle(
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.primaryColor,
                        color: AppColors.primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
