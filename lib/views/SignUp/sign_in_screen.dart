import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/Controllers/signupAndSignIn/sign_in_controller.dart';
import 'package:snevva/common/custom_snackbar.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/services/auth_service.dart';
import 'package:snevva/views/SignUp/forgot_password.dart';
import '../../widgets/SignInScreens/sign_in_footer_widget.dart';
import 'create_new_profile.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

final TextEditingController userEmailOrPhoneField = TextEditingController();
final TextEditingController userPasswordField = TextEditingController();
SignInController get signInController => Get.find<SignInController>();

class _SignInScreenState extends State<SignInScreen> {
  final authService = AuthService();
  late TextEditingController userEmailOrPhoneField;
  late TextEditingController userPasswordField;

  bool rememberMe = true;
  bool visible = true;
  bool isLoading = false;

  void showPassword() {
    setState(() {
      visible = !visible;
    });
  }

  void showCheckbox() {}

  @override
  void initState() {
    super.initState();
    userEmailOrPhoneField = TextEditingController();
    userPasswordField = TextEditingController();
  }

  @override
  void dispose() {
    userEmailOrPhoneField.dispose();
    userPasswordField.dispose();
    super.dispose();
  }

  // Handle sign-in error and show snackbar
  void _handleSignInError(String message) {
    CustomSnackbar.showError(context: context, title: "", message: message);
  }

  Future<void> onSignInButtonClick(BuildContext context) async {
    if (isLoading) return;

    setState(() => isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final input = userEmailOrPhoneField.text.trim();
    final password = userPasswordField.text.trim();

    final emailRegExp = RegExp(
      r'^[a-zA-Z0-9._%-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,6}$',
    );
    final phoneRegExp = RegExp(r'^\d{10,}$');

    bool isEmail = emailRegExp.hasMatch(input);
    bool isPhone = phoneRegExp.hasMatch(input);

    try {
      bool success = false;

      if (isEmail) {
        // 🔹 Email Login
        success = await signInController.signInUsingEmail(
          input,
          password,
          context,
        );
      } else if (isPhone) {
        // 🔹 Phone Login
        success = await signInController.signInUsingPhone(
          input,
          password,
          context,
        );
      } else {
        print("Invalid input format");
        // 🔹 Invalid input
        // _handleSignInError();
        return;
      }

      // 🔹 Handle result
      if (success) {
        await authService.handleSuccessfulSignIn(
          emailOrPhone: input,
          prefs: prefs,
          context: context,
          rememberMe: rememberMe,
        );
        print("Sign-in successful");
      } else {
        print("Sign-in failed");
        // _handleSignInError();
      }
    } catch (e) {
      print("Exception $e");
      _handleSignInError("We couldn’t sign you in. Please try again.");
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // final height = mediaQuery.size.height;
    // final width = mediaQuery.size.width;
    // ✅ Listens to the app's current theme command
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.only(
                  left: 20.0,
                  right: 20,
                  bottom: 20,
                  top: 100,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  // border: Border.all(color: Colors.grey.shade400, width: 1.2),
                ),
                child: Material(
                  color:
                      isDarkMode
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8.0),

                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: EdgeInsets.all(defaultSize - 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8.0),
                          color: Colors.transparent,
                          border:
                              isDarkMode
                                  ? null
                                  : Border.all(
                                    color: Colors.grey.shade400,
                                    width: 1.2,
                                  ),
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            Form(
                              child: Column(
                                children: [
                                  Material(
                                    color:
                                        isDarkMode
                                            ? AppColors.primaryColor.withValues(
                                              alpha: .02,
                                            )
                                            : Colors.white.withValues(
                                              alpha: 0.95,
                                            ),
                                    elevation: 1,
                                    borderRadius: BorderRadius.circular(4),
                                    child: TextFormField(
                                      controller: userEmailOrPhoneField,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Colors.transparent,
                                        prefixIcon: Icon(Icons.email_outlined),
                                        labelText:
                                            AppLocalizations.of(
                                              context,
                                            )!.inputEmailOrMobile,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  Material(
                                    elevation: 1,
                                    color:
                                        isDarkMode
                                            ? AppColors.primaryColor.withValues(
                                              alpha: .02,
                                            )
                                            : Colors.white.withValues(
                                              alpha: 0.95,
                                            ),
                                    borderRadius: BorderRadius.circular(4),
                                    child: TextFormField(
                                      obscureText: visible,
                                      controller: userPasswordField,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Colors.transparent,
                                        prefixIcon: Icon(Icons.lock_outline),
                                        suffixIcon: IconButton(
                                          onPressed: showPassword,
                                          icon: Icon(
                                            visible
                                                ? Icons.visibility
                                                : Icons.visibility_off,
                                          ),
                                          color:
                                              Theme.of(context)
                                                  .inputDecorationTheme
                                                  .suffixIconColor,
                                        ),
                                        labelText:
                                            AppLocalizations.of(
                                              context,
                                            )!.inputPassword,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Row(
                                //   children: [
                                //     Checkbox(
                                //       value: rememberMe,
                                //       activeColor: AppColors.primaryColor,
                                //       onChanged: (value) {
                                //         setState(() {
                                //           rememberMe = value!;
                                //         });
                                //       },
                                //     ),
                                //     Text(
                                //       AppLocalizations.of(
                                //         context,
                                //       )!.checkboxRememberMe,
                                //       style: TextStyle(fontSize: 14),
                                //     ),
                                //   ],
                                // ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ForgotPassword(),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    '''${AppLocalizations.of(context)!.linkForgotPassword}?''',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Sign in Button
                            Builder(
                              builder:
                                  (context) => Padding(
                                    padding: EdgeInsets.only(
                                      bottom:
                                          MediaQuery.of(
                                            context,
                                          ).viewInsets.bottom,
                                    ),
                                    child: SignInFooterWidget(
                                      buttonText:
                                          AppLocalizations.of(
                                            context,
                                          )!.signInButtonText,
                                      bottomText:
                                          AppLocalizations.of(
                                            context,
                                          )!.notMemberText,
                                      bottomText2:
                                          AppLocalizations.of(
                                            context,
                                          )!.createNewAccountText,
                                      googleText:
                                          AppLocalizations.of(
                                            context,
                                          )!.googleTextSignIn,
                                      onElevatedButtonPress:
                                          () => onSignInButtonClick(context),
                                      isLoading: isLoading,
                                      // Pass here
                                      onBottomTextPressed: () {
                                        Get.to(SignUpScreen());
                                      },
                                    ),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: -80,
                        left: 0,
                        right: 0,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Image.asset(elemascot),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
