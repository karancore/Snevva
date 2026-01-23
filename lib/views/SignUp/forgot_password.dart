import 'package:snevva/common/custom_snackbar.dart';
import 'package:snevva/views/SignUp/verify_with_otp.dart';

import '../../Controllers/signupAndSignIn/forgot_password_controller.dart';
import '../../consts/consts.dart';
import '../../services/notification_service.dart';

class ForgotPassword extends StatefulWidget {
  const ForgotPassword({super.key});

  @override
  State<ForgotPassword> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPassword> {
  final TextEditingController textFieldController = TextEditingController();
  final forgotPasswordController = Get.put(ForgotPasswordController());
  final notify = NotificationService();

  bool isLoading = false;

  @override
  void dispose() {
    textFieldController.dispose();
    forgotPasswordController.dispose();
    super.dispose();
  }

  Future<void> onButtonClick(String input) async {
    print("onButtonClick $input");
    if (textFieldController.text.isEmpty) {
      CustomSnackbar.showError(
        context: context,
        title: 'Please provide Email or Phone',
        message: '',
      );
      return;
    }

    setState(() => isLoading = true);

    dynamic result;

    try {
      if (input.contains('@')) {
        /// Email case
        result = await forgotPasswordController.resetPasswordUsingGmail(
          input,
          context,
        );
      } else if (RegExp(r'^\d{10,}$').hasMatch(input)) {
        /// Phone case
        result = await forgotPasswordController.resetPasswordUsingPhone(
          input,
          context,
        );
      } else {
        CustomSnackbar.showError(
          context: context,
          title: 'Invalid Email or Phone Number',
          message: '',
        );
        setState(() => isLoading = false);
        return;
      }

      if (result != false) {
        // notify.showOtpNotification(result);
        Get.to(
          VerifyWithOtpScreen(
            emailOrPasswordText: input,
            appBarText: AppLocalizations.of(context)!.verifyEmailAddress,
            responseOtp: result,
            isForgotPasswordScreen: true,
          ),
        );
        textFieldController.clear();
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.linkForgotPassword),
        centerTitle: true,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios , size: 18,),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Image.asset(forgotpass, height: 200, width: 200),
              const SizedBox(height: 30),
              Text(
                AppLocalizations.of(context)!.forgetPasswordScreenText,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 30),

              /// Text Field
              Material(
                color:
                    isDarkMode
                        ? AppColors.primaryColor.withOpacity(.02)
                        : Colors.white.withOpacity(.95),
                borderRadius: BorderRadius.circular(4),
                elevation: 1,
                child: TextFormField(
                  controller: textFieldController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.email),
                    labelText: AppLocalizations.of(context)!.inputEmailOrMobile,
                  ),
                ),
              ),

              const SizedBox(height: 30),

              /// Button with loader
              Container(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ElevatedButton(
                  onPressed: isLoading ? null : () => onButtonClick(textFieldController.text.trim()),
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
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : Text(AppLocalizations.of(context)!.sendCode),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
