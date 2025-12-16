import 'package:flutter/gestures.dart';
import 'package:snevva/Controllers/signupAndSignIn/update_old_password_controller.dart';
import 'package:snevva/common/custom_snackbar.dart';
import '../../consts/consts.dart';

class UpdateOldPasword extends StatefulWidget {
  final bool otpVerificationStatus;
  final String otp;
  final String emailOrPhoneText;

  const UpdateOldPasword({
    super.key,
    required this.otpVerificationStatus,
    required this.otp,
    required this.emailOrPhoneText,
  });

  @override
  State<UpdateOldPasword> createState() => _UpdateOldPaswordState();
}

final updatePasswordController = Get.put(UpdateOldPasswordController());
final _formKey = GlobalKey<FormState>();

class _UpdateOldPaswordState extends State<UpdateOldPasword> {
  @override
  void initState() {
    super.initState();

    updatePasswordController.passwordController.addListener(() {
      updatePasswordController.password.value =
          updatePasswordController.passwordController.text;
    });

    updatePasswordController.confirmPasswordController.addListener(() {
      updatePasswordController.confirmPassword.value =
          updatePasswordController.confirmPasswordController.text;
    });
  }

  void onUpdateButtonPress() {
    if (updatePasswordController.validateAndShowError(context)) {
      final input = widget.emailOrPhoneText.trim();
      final controller = updatePasswordController;

      if (input.contains('@')) {
        controller.updateOldPasswordWithGmail(
          input,
          widget.otp,
          widget.otpVerificationStatus,
          controller.confirmPasswordController.text.trim(),
          context,
        );
      } else if (RegExp(r'^\d{10,}$').hasMatch(input)) {
        controller.updateOldPasswordWithPhone(
          input,
          widget.otp,
          widget.otpVerificationStatus,
          controller.confirmPasswordController.text.trim(),
          context,
        );
      } else {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Failed To Update old Password.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.updatePassword),
        centerTitle: true,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              Image.asset(newPass, height: 200, width: 200),
              const SizedBox(height: 30),
              Text(
                AppLocalizations.of(context)!.newPasswordInstruction,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 30),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    Obx(
                      () => Material(
                        color:
                            isDarkMode
                                ? AppColors.primaryColor.withOpacity(0.02)
                                : Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(4),
                        elevation: 1,
                        child: TextFormField(
                          obscureText:
                              updatePasswordController.obscurePassword.value,
                          controller:
                              updatePasswordController.passwordController,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.transparent,
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () {
                                updatePasswordController.obscurePassword.value =
                                    !updatePasswordController
                                        .obscurePassword
                                        .value;
                              },
                              icon: Icon(
                                updatePasswordController.obscurePassword.value
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                            ),
                            labelText:
                                AppLocalizations.of(context)!.newPassword,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Obx(
                      () => Row(
                        children: [
                          Icon(
                            updatePasswordController.isPasswordValid
                                ? Icons.check_circle
                                : Icons.error_outline,
                            color:
                                updatePasswordController.isPasswordValid
                                    ? Colors.green
                                    : Colors.grey,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            updatePasswordController.isPasswordValid
                                ? AppLocalizations.of(
                                  context,
                                )!.passwordStrengthStrong
                                : AppLocalizations.of(
                                  context,
                                )!.passwordStrengthWeak,
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  updatePasswordController.isPasswordValid
                                      ? Colors.green
                                      : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Obx(
                      () => Material(
                        color:
                            isDarkMode
                                ? AppColors.primaryColor.withOpacity(0.02)
                                : Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(4),
                        elevation: 1,
                        child: TextFormField(
                          controller:
                              updatePasswordController
                                  .confirmPasswordController,
                          obscureText:
                              updatePasswordController.obscurePassword2.value,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.transparent,
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () {
                                updatePasswordController
                                    .obscurePassword2
                                    .value = !updatePasswordController
                                        .obscurePassword2
                                        .value;
                              },
                              icon: Icon(
                                updatePasswordController.obscurePassword2.value
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                            ),
                            labelText:
                                AppLocalizations.of(context)!.confirmPassword,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Obx(
                      () => Row(
                        children: [
                          Icon(
                            updatePasswordController.isConfirmPasswordValid
                                ? Icons.check_circle
                                : Icons.error_outline,
                            color:
                                updatePasswordController.isConfirmPasswordValid
                                    ? Colors.green
                                    : Colors.orangeAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            updatePasswordController.isConfirmPasswordValid
                                ? AppLocalizations.of(context)!.passwordsMatch
                                : AppLocalizations.of(
                                  context,
                                )!.passwordsDoNotMatch,
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  updatePasswordController
                                          .isConfirmPasswordValid
                                      ? Colors.green
                                      : Colors.orangeAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Obx(
                          () => Checkbox(
                            value: updatePasswordController.isChecked.value,
                            onChanged: (val) {
                              updatePasswordController.isChecked.value =
                                  val ?? false;
                            },
                            activeColor: AppColors.primaryColor,
                            visualDensity: const VisualDensity(
                              horizontal: -4,
                              vertical: -4,
                            ),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(fontSize: 12),
                              children: [
                                TextSpan(
                                  text:
                                      AppLocalizations.of(
                                        context,
                                      )!.agreeToTerms,
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
                                  recognizer:
                                      TapGestureRecognizer()..onTap = () {},
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
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
                  onPressed: onUpdateButtonPress,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(AppLocalizations.of(context)!.update),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
