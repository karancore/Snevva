import 'package:flutter/gestures.dart';
import 'package:snevva/services/device_token_service.dart';
import 'package:snevva/views/SignUp/sign_in_screen.dart';
import '../../Controllers/signupAndSignIn/create_password_controller.dart';
import '../../common/custom_snackbar.dart';
import '../../consts/consts.dart';

class CreateNewPassword extends StatefulWidget {
  final bool otpVerificationStatus;
  final String otp;
  final String emailOrPhoneText;

  const CreateNewPassword({
    super.key,
    required this.otpVerificationStatus,
    required this.otp,
    required this.emailOrPhoneText,
  });

  @override
  State<CreateNewPassword> createState() => _CreateNewPasswordState();
}

class _CreateNewPasswordState extends State<CreateNewPassword> {
  final controller = Get.put(CreatePasswordController());

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    // ✅ Listens to the app's current theme command
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    
    void onCreatePasswordButtonClick() async{
      if (controller.password.value.isEmpty ||
          controller.confirmPassword.value.isEmpty) {
        CustomSnackbar.showError(
          title: "Error",
          message: "Please fill in both password fields",
          context: context,
        );
        return;
      }

      if (!controller.isPasswordValid) {
        CustomSnackbar.showError(
          title: "Weak Password",
          message: "Your password doesn't meet the criteria",
          context: context,
        );
        return;
      }

      if (!controller.isConfirmPasswordValid) {
        CustomSnackbar.showError(
          title: "Mismatch",
          message: "Passwords do not match",
          context: context,
        );

        return;
      }

      if (!controller.isChecked.value) {
        CustomSnackbar.showError(
          title: "Agreement Required",
          message: "You must agree to the terms",
          context: context,
        );

        return;
      }
      if (widget.emailOrPhoneText.contains('@')) {
        localStorageManager.userMap['Email'] = widget.emailOrPhoneText.trim();
        controller.createNewPasswordWithGmail(
          widget.emailOrPhoneText.trim(),
          widget.otp,
          widget.otpVerificationStatus,
          controller.confirmPasswordController.text.trim(),
          context,
        );
      } else if (RegExp(r'^\d{10,}$').hasMatch(widget.emailOrPhoneText)) {
        localStorageManager.userMap['PhoneNumber'] =
            widget.emailOrPhoneText.trim();
        controller.createNewPasswordWithPhone(
          widget.emailOrPhoneText.trim(),
          widget.otp,
          widget.otpVerificationStatus,
          controller.confirmPasswordController.text.trim(),
          context,
        );
      } else {
        CustomSnackbar.showError(
          title: "Error",
          message: "Failed To Create New Password.",
          context: context,
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 18,),
          onPressed: () => Get.to(SignInScreen()),
        ),
        centerTitle: true,
        title: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            AppLocalizations.of(context)!.createPassword,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              SizedBox(height: 16),
              Image.asset(mascot2, height: 100),
              SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.createAccount,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Text(
                AppLocalizations.of(context)!.enterPassword,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              SizedBox(height: 30),

              Material(
                elevation: 1,
                color:
                    isDarkMode
                        ? AppColors.primaryColor.withValues(alpha: .02)
                        : Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(4),
                child: Obx(
                  () => TextFormField(
                    controller: controller.passwordController,
                    obscureText: controller.obscurePassword.value,
                    onChanged: (val) => controller.password.value = val,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.transparent,
                      prefixIcon: Icon(Icons.lock_outline),
                      labelText: AppLocalizations.of(context)!.inputPassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          controller.obscurePassword.value
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          controller.obscurePassword.value =
                              !controller.obscurePassword.value;
                        },
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 6),
              Obx(
                () => Row(
                  children: [
                    Icon(
                      controller.isPasswordValid
                          ? Icons.check_circle
                          : Icons.error_outline,
                      color:
                          controller.isPasswordValid
                              ? Colors.green
                              : Colors.grey,
                      size: 18,
                    ),
                    SizedBox(width: 6),
                    Text(
                      controller.isPasswordValid
                          ? AppLocalizations.of(context)!.passwordStrengthStrong
                          : AppLocalizations.of(context)!.passwordStrengthWeak,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            controller.isPasswordValid
                                ? Colors.green
                                : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 10),

              // Confirm Password Field
              Material(
                elevation: 1,
                color:
                    isDarkMode
                        ? AppColors.primaryColor.withValues(alpha: .02)
                        : Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(4),
                child: Obx(
                  () => TextFormField(
                    controller: controller.confirmPasswordController,
                    obscureText: controller.obscurePassword2.value,
                    onChanged: (val) => controller.confirmPassword.value = val,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.transparent,
                      prefixIcon: Icon(Icons.lock_outline),
                      labelText: AppLocalizations.of(context)!.confirmPassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          controller.obscurePassword2.value
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          controller.obscurePassword2.value =
                              !controller.obscurePassword2.value;
                        },
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 6),
              Obx(
                () => Row(
                  children: [
                    Icon(
                      controller.isConfirmPasswordValid
                          ? Icons.check_circle
                          : Icons.error_outline,
                      color:
                          controller.isConfirmPasswordValid
                              ? Colors.green
                              : Colors.orangeAccent,
                      size: 18,
                    ),
                    SizedBox(width: 6),
                    Text(
                      controller.isConfirmPasswordValid
                          ? AppLocalizations.of(context)!.passwordsMatch
                          : AppLocalizations.of(context)!.passwordsDoNotMatch,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            controller.isConfirmPasswordValid
                                ? Colors.green
                                : Colors.orangeAccent,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.passwordMustContain,
                    style: TextStyle(fontSize: 12),
                  ),
                  SizedBox(height: 10),
                  Obx(
                    () => Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color:
                              controller.hasLetter
                                  ? AppColors.primaryColor
                                  : Colors.grey,
                        ),
                        SizedBox(width: 5),
                        Text(
                          AppLocalizations.of(
                            context,
                          )!.passwordLetterRequirement,
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 10),

                  Obx(
                    () => Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color:
                              controller.hasNumberOrSymbol
                                  ? AppColors.primaryColor
                                  : Colors.grey,
                        ),
                        SizedBox(width: 5),
                        Text(
                          AppLocalizations.of(context)!.passwordSpecialChar,
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 10),

                  Obx(
                    () => Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color:
                              controller.hasMinLength
                                  ? AppColors.primaryColor
                                  : Colors.grey,
                        ),
                        SizedBox(width: 5),
                        Text(
                          AppLocalizations.of(context)!.passwordMinLength,
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 30),
              Obx(
                () => Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Checkbox(
                      visualDensity: VisualDensity(
                        horizontal: -4,
                        vertical: -4,
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      value: controller.isChecked.value,
                      onChanged: (value) => controller.isChecked.value = value!,
                    ),
                    SizedBox(width: 5),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(fontSize: 12),
                          children: [
                            TextSpan(
                              text: AppLocalizations.of(context)!.agreeToTerms,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            TextSpan(
                              text:
                                  AppLocalizations.of(
                                    context,
                                  )!.agreeToConditions,
                              style: TextStyle(
                                color: AppColors.primaryColor,
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()..onTap = () {},
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 30),
              Container(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ElevatedButton(
                  onPressed: onCreatePasswordButtonClick,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(AppLocalizations.of(context)!.nextText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
