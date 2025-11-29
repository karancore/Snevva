
import 'package:snevva/views/Sign%20Up/verify_with_otp.dart';

import '../../Controllers/signupAndSignIn/forgot_password_controller.dart';
import '../../consts/consts.dart';


class ForgotPassword extends StatefulWidget {
  const ForgotPassword({super.key});

  @override
  State<ForgotPassword> createState() => _ForgotPasswordState();
}

final TextEditingController textFieldController = TextEditingController();

final  forgotPasswordController = Get.put(ForgotPasswordController());

class _ForgotPasswordState extends State<ForgotPassword> {
  @override
  void dispose() {
    super.dispose();
    forgotPasswordController.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final mediaQuery =  MediaQuery.of(context);
    final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;

    Future<void> onButtonClick() async {
      if (textFieldController.text.toString().contains('@')) {
      final result =  forgotPasswordController.resetPasswordUsingGmail(textFieldController.text.toString().trim());


        if (await result != false){
          Get.to(VerifyWithOtpScreen(emailOrPasswordText: textFieldController.text.toString().trim(),
            appBarText: AppLocalizations.of(context)!.verifyEmailAddress,
            responseOtp: await result,
            isForgotPasswordScreen: true,
          ));
          textFieldController.clear();
        }


      } else if (RegExp(r'^\d{10,}$').hasMatch(
          textFieldController.text.toString())) {
       final result = forgotPasswordController.resetPasswordUsingPhone(textFieldController.text.toString().trim());

       if (await result != false) {
         Get.to(VerifyWithOtpScreen(
           emailOrPasswordText: textFieldController.text.toString().trim(),
           appBarText: AppLocalizations.of(context)!.verifyPhoneNumber,
           responseOtp: await result,
           isForgotPasswordScreen: true,
         ));
         textFieldController.clear();
       }
      } else {
        Get.snackbar('Error', 'Please Provide Correct Email or Phone Number',
          snackPosition: SnackPosition.BOTTOM,
          margin: EdgeInsets.all(20),);
      }
    }

    return Scaffold(

      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.linkForgotPassword),
        centerTitle: true,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios),
          onPressed: () {
           Get.back();
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 10),
              Image.asset(
                forgotpass,
                height: 200,
                width: 200,
              ),
              SizedBox(height: 30),
              Text(
                AppLocalizations.of(context)!.forgetPasswordScreenText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 30),
              Form(
                  child: Material(
                    color: isDarkMode? AppColors.primaryColor.withValues(alpha: .02) : Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(4),
                    elevation: 1,
                    child: TextFormField(
                      controller: textFieldController,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.transparent,
                        prefixIcon: Icon(Icons.email,),
                        labelText: AppLocalizations.of(context)!.inputEmailOrMobile,
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
                  child: Text(AppLocalizations.of(context)!.sendCode),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
