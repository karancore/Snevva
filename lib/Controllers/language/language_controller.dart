import 'package:get/get.dart';

class LanguageController extends GetxController {

  var selectedLanguage = ''.obs;

  void selectLanguage(String lang) {
    selectedLanguage.value = lang;
  }
}
