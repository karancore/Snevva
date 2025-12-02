import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/Controllers/localStorageManager.dart';
import 'package:snevva/Controllers/signupAndSignIn/sign_in_controller.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/views/ProfileAndQuestionnaire/height_and_weight.dart';
import 'package:snevva/views/ProfileAndQuestionnaire/profile_setup_initial.dart';
import 'package:snevva/views/ProfileAndQuestionnaire/questionnaire_screen.dart';
import 'package:snevva/views/Sign%20Up/forgot_password.dart';
import 'package:timezone/timezone.dart';
import '../../Widgets/SignInScreens/sign_in_footer_widget.dart';
import '../../Widgets/home_wrapper.dart';
import 'create_new_profile.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

final TextEditingController userEmailOrPhoneField = TextEditingController();
final TextEditingController userPasswordField = TextEditingController();
final signInController = Get.put(SignInController());
final localStorageManager = Get.put(LocalStorageManager());

class _SignInScreenState extends State<SignInScreen> {
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

  Future<void> _handleSuccessfulSignIn(
    String emailOrPhone,
    SharedPreferences prefs,
  ) async {
    if (rememberMe) {
      prefs.setBool('remember_me', true);
      prefs.setString('user_credential', emailOrPhone);
    }

    final userInfo = signInController.userProfData;
    final userData = userInfo['data'];
    print(userData);
    await prefs.setString('userdata', jsonEncode(userData));
    localStorageManager.userMap.value = userData ?? {};

    final nameValid = userData['Name']?.toString().trim().isNotEmpty ?? false;
    final genderValid =
        userData['Gender']?.toString().trim().isNotEmpty ?? false;
    final occupationValid = userData['OccupationData'] != null;

    if (nameValid && genderValid && occupationValid) {
      final userActiveDataResponse = signInController.userGoalData;
      final userActiveData = userActiveDataResponse['data'];
      print(userActiveData);

      localStorageManager.userGoalDataMap.value = userActiveData ?? {};
      prefs.setString('userGoalDataMap', jsonEncode(userActiveData));

      if (userActiveData != null && userActiveData is Map) {
        await prefs.setString('useractivedata', jsonEncode(userActiveData));

        // 🚀 Final check 1 → All goals set → go home
        if (userActiveData['ActivityLevel'] != null &&
            userActiveData['HealthGoal'] != null) {
          Get.offAll(() => HomeWrapper());
          return; // <<< CRITICAL
        }

        // 🚀 Final check 2 → Ask only remaining questions
        if (userActiveData['HeightData'] != null &&
            userActiveData['WeightData'] != null) {
          Get.offAll(() => QuestionnaireScreen());
          return; // <<< CRITICAL
        }

        // 🚀 Missing height/weight
        final gender = userData['Gender']?.toString() ?? 'Unknown';
        Get.offAll(() => HeightAndWeight(gender: gender));
        return; // <<< CRITICAL
      }

      // If userActiveData invalid
      Get.offAll(() => HomeWrapper());
      return;
    }

    // Missing basic profile info
    Get.offAll(() => ProfileSetupInitial());
    return;
  }

  // Handle sign-in error and show snackbar
  void _handleSignInError() {
    signInController.showSnackbar('Error', 'Incorrect Credential.');
  }

  Future<void> onSignInButtonClick() async {
    if (isLoading) return; // Prevent multiple taps
    setState(() {
      isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();

    final emailOrPhone = userEmailOrPhoneField.text.trim();
    print(emailOrPhone);
    final password = userPasswordField.text.trim();
    print(password);
    final emailRegExp = RegExp(r'^[a-zA-Z0-9._%-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,6}$');
    bool isValid = emailRegExp.hasMatch(emailOrPhone);
    print(isValid);




    try {
      // Checking if it's an email or phone number
      if (isValid) {
        // Sign in using email
        await signInController.signInUsingEmail(emailOrPhone, password).then((
          success,
        ) async {
          if (success) {
            print("Sign-in successful with email.");
            await _handleSuccessfulSignIn(emailOrPhone, prefs);
          } else {
            print("Sign-in failed with email.");
            // Get.snackbar('error', 'Wrong Credentails');

            _handleSignInError();
          }
        });
      } else if (RegExp(r'^\d{10,}$').hasMatch(emailOrPhone)) {
        // Sign in using phone number
        await signInController.signInUsingPhone(emailOrPhone, password).then((
          success,
        ) async {
          if (success) {
            print("Sign-in successful with phone.");
            await _handleSuccessfulSignIn(emailOrPhone, prefs);
          } else {
            print("Sign-in failed with phone.");
            _handleSignInError();
          }
        });
      } else {
        // Invalid email or phone format
        _handleSignInError();
      }
    } catch (e) {
      _handleSignInError();
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    // final height = mediaQuery.size.height;
    // final width = mediaQuery.size.width;
    final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;

    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: 20.0,
              right: 20,
              bottom: 20,
              top: 100,
            ),
            child: Material(
              color:
                  isDarkMode
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.white,
              elevation: 5.0,
              borderRadius: BorderRadius.circular(8.0),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: EdgeInsets.all(defaultSize - 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8.0),
                      color: Colors.transparent,
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
                                        : Colors.white.withValues(alpha: 0.95),
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
                                        : Colors.white.withValues(alpha: 0.95),
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
                            //       style: TextStyle(fontSize: 12),
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

                        const SizedBox(height: 20),

                        // Sign in Button
                        SignInFooterWidget(
                          buttonText:
                              AppLocalizations.of(context)!.signInButtonText,
                          bottomText:
                              AppLocalizations.of(context)!.notMemberText,
                          bottomText2:
                              AppLocalizations.of(
                                context,
                              )!.createNewAccountText,
                          googleText:
                              AppLocalizations.of(context)!.googleTextSignIn,
                          onElevatedButtonPress: onSignInButtonClick,
                          isLoading: isLoading,
                          // Pass here
                          onBottomTextPressed: () {
                            Get.to(CreateNewProfile());
                          },
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
    );
  }
}
