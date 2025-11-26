import 'package:snevva/Widgets/SignInScreens/sign_in_footer_widget.dart';
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

  final SignUpController signupController = Get.put(SignUpController());

  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    Future<void> onButtonClick() async {
      if (isLoading) return;
      setState(() => isLoading = true);

      try {
        if (emailOrPasswordTextController.text.toString().contains('@')) {
          final result = await signupController.signUpUsingGmail(
            emailOrPasswordTextController.text.toString().trim(),
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
          Get.snackbar(
            'Error',
            'Please Provide Correct Email or Phone Number',
            snackPosition: SnackPosition.BOTTOM,
            margin: EdgeInsets.all(20),
          );
        }
      }catch(e){
        Get.snackbar(
          'Error',
          'Please Provide Correct Email or Phone Number',
          snackPosition: SnackPosition.BOTTOM,
          margin: EdgeInsets.all(20),
        );
      }finally{
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
              SignInFooterWidget(
                bottomText: AppLocalizations.of(context)!.alreadyHaveAccount,
                bottomText2: AppLocalizations.of(context)!.loginInText,
                buttonText: AppLocalizations.of(context)!.nextText,
                googleText: AppLocalizations.of(context)!.googleText,
                onElevatedButtonPress: onButtonClick,
                onBottomTextPressed: () {
                  Get.to(SignInScreen());
                },
                isLoading: isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
