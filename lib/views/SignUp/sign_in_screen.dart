import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/Controllers/Hydration/hydration_stat_controller.dart';
import 'package:snevva/Controllers/MoodTracker/mood_controller.dart';
import 'package:snevva/Controllers/Reminder/reminder_controller.dart';
import 'package:snevva/Controllers/SleepScreen/sleep_controller.dart';
import 'package:snevva/Controllers/StepCounter/step_counter_controller.dart';
import 'package:snevva/Controllers/Vitals/vitalsController.dart';
import 'package:snevva/Controllers/WomenHealth/bottom_sheet_controller.dart';
import 'package:snevva/Controllers/WomenHealth/women_health_controller.dart';
import 'package:snevva/Controllers/local_storage_manager.dart';
import 'package:snevva/Controllers/signupAndSignIn/sign_in_controller.dart';
import 'package:snevva/common/custom_snackbar.dart';
import 'package:snevva/common/global_variables.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/bindings/initial_bindings.dart';
import 'package:snevva/services/app_initializer.dart';
import 'package:snevva/services/auth_service.dart';
import 'package:snevva/services/device_token_service.dart';
import 'package:snevva/views/ProfileAndQuestionnaire/height_and_weight_screen.dart';
import 'package:snevva/views/ProfileAndQuestionnaire/profile_setup_initial.dart';
import 'package:snevva/views/ProfileAndQuestionnaire/questionnaire_screen.dart';
import 'package:snevva/views/SignUp/forgot_password.dart';
import 'package:snevva/widgets/home_wrapper.dart';
import 'package:snevva/common/agent_debug_logger.dart';

import '../../Controllers/BMI/bmi_controller.dart';
import '../../Controllers/DietPlan/diet_plan_controller.dart';
import '../../Controllers/HealthTips/healthtips_controller.dart';
import '../../Controllers/MentalWellness/mental_wellness_controller.dart';
import '../../Controllers/MoodTracker/mood_questions_controller.dart';
import '../../Controllers/ProfileSetupAndQuestionnare/editprofile_controller.dart';
import '../../Controllers/ProfileSetupAndQuestionnare/profile_setup_controller.dart';
import '../../Controllers/alerts/alerts_controller.dart';
import '../../Controllers/signupAndSignIn/forgot_password_controller.dart';
import '../../Controllers/signupAndSignIn/update_old_password_controller.dart';
import '../../widgets/SignInScreens/sign_in_footer_widget.dart';
import 'create_new_profile.dart';

import 'package:snevva/Controllers/local_storage_manager.dart';
import 'package:snevva/Controllers/signupAndSignIn/create_password_controller.dart';
import 'package:snevva/Controllers/signupAndSignIn/otp_verification_controller.dart';
import 'package:snevva/Controllers/signupAndSignIn/sign_up_controller.dart';
import 'package:snevva/utils/theme_controller.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

final TextEditingController userEmailOrPhoneField = TextEditingController();
final TextEditingController userPasswordField = TextEditingController();
final signInController = Get.find<SignInController>();
final stepController = Get.put(StepCounterController());
final sleepController = Get.put(SleepController());
final waterController = Get.put(HydrationStatController());
final vitalsController = Get.put(VitalsController());
final localStorageManager = Get.put(LocalStorageManager());
final womenhealthController = Get.put(WomenHealthController());
final moodcontroller = Get.put(MoodController());
final bottomsheetcontroller = Get.put(BottomSheetController());
final reminderController = Get.put(ReminderController());

class _SignInScreenState extends State<SignInScreen> {
  final authService = AuthService();
  late TextEditingController userEmailOrPhoneField;
  late TextEditingController userPasswordField;
  final controller = Get.put(SignInController());

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      initialiseControllers();
    });
  }

  void initialiseControllers() {
    Get.put(LocalStorageManager(), permanent: true);

    if (!Get.isRegistered<AlertsController>()) {
      Get.put(AlertsController(), permanent: true);
    }

    // Auth
    if (!Get.isRegistered<SignInController>()) {
      Get.lazyPut(() => SignInController(), fenix: true);
    }
    if (!Get.isRegistered<SignUpController>()) {
      Get.lazyPut(() => SignUpController(), fenix: true);
    }
    if (!Get.isRegistered<OTPVerificationController>()) {
      Get.lazyPut(() => OTPVerificationController(), fenix: true);
    }
    if (!Get.isRegistered<UpdateOldPasswordController>()) {
      Get.lazyPut(() => UpdateOldPasswordController(), fenix: true);
    }
    if (!Get.isRegistered<CreatePasswordController>()) {
      Get.lazyPut(() => CreatePasswordController(), fenix: true);
    }
    if (!Get.isRegistered<ForgotPasswordController>()) {
      Get.lazyPut(() => ForgotPasswordController(), fenix: true);
    }
    if (!Get.isRegistered<ProfileSetupController>()) {
      Get.lazyPut(() => ProfileSetupController(), fenix: true);
    }

    if (!Get.isRegistered<WomenHealthController>()) {
      Get.lazyPut(() => WomenHealthController(), fenix: true);
    }

    Get.put(VitalsController(), permanent: true);
    Get.put(HydrationStatController(), permanent: true);
    Get.put(MoodController(), permanent: true);
    Get.put(EditprofileController(), permanent: true);

    if (!Get.isRegistered<StepCounterController>()) {
      Get.put(StepCounterController(), permanent: true);
    }

    // Feature
    if (!Get.isRegistered<BmiController>()) {
      Get.lazyPut(() => BmiController(), fenix: true);
    }
    if (!Get.isRegistered<DietPlanController>()) {
      Get.lazyPut(() => DietPlanController(), fenix: true);
    }
    if (!Get.isRegistered<HealthTipsController>()) {
      Get.lazyPut(() => HealthTipsController(), fenix: true);
    }

    if (!Get.isRegistered<MentalWellnessController>()) {
      Get.lazyPut(() => MentalWellnessController(), fenix: true);
    }

    Get.lazyPut(() => MoodQuestionController(), fenix: true);

    // UI
    //WOmen
    if (!Get.isRegistered<BottomSheetController>()) {
      Get.lazyPut(() => BottomSheetController(), fenix: true);
    }
    if (!Get.isRegistered<ThemeController>()) {
      Get.lazyPut(() => ThemeController(), fenix: true);
    }
    if (!Get.isRegistered<ReminderController>()) {
      Get.lazyPut(() => ReminderController(), fenix: true);
    }
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
      print("Exception during sign-in: $e");
      _handleSignInError("Exception during sign-in");
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
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
