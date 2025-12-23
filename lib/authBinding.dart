import 'package:snevva/Controllers/signupAndSignIn/sign_in_controller.dart';
import 'package:snevva/Controllers/signupAndSignIn/sign_up_controller.dart';
import 'package:snevva/consts/consts.dart';

class AuthBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(SignInController());
    Get.put(SignUpController());
  }
}
