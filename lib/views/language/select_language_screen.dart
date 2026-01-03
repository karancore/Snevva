import 'package:snevva/common/custom_snackbar.dart';
import 'package:snevva/views/SignUp/sign_in_screen.dart';
import '../../Controllers/language/language_controller.dart';
import '../../Widgets/CommonWidgets/custom_outlined_button.dart';
import '../../consts/consts.dart';

class SelectLanguageScreen extends StatelessWidget {
  SelectLanguageScreen({super.key});

  final LanguageController langController = Get.put(LanguageController());

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    //   final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    // ✅ Listens to the app's current theme command
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    InkWell languageContainer(String languageText) {
      return InkWell(
        onTap: () => langController.selectLanguage(languageText),
        borderRadius: BorderRadius.circular(20),
        child: Obx(() {
          final isSelected =
              langController.selectedLanguage.value == languageText;
          return Container(
            width: width / 2.8,
            padding: EdgeInsets.symmetric(horizontal: 0, vertical: 5),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryColor : null,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                width: 2.0,
                color: isSelected ? AppColors.primaryColor : grey,
              ),
            ),
            child: Center(
              child: Text(
                languageText,
                style: TextStyle(
                  fontSize: 16,
                  color:
                      isSelected
                          ? white
                          : isDarkMode
                          ? white
                          : black,
                ),
              ),
            ),
          );
        }),
      );
    }

    return Scaffold(
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: CustomOutlinedButton(
          buttonName: AppLocalizations.of(context)!.confirmLanguageButton,
          backgroundColor: AppColors.primaryColor,
          width: width,
          isDarkMode: isDarkMode,
          onTap: () {
            final selectedLang = langController.selectedLanguage.value;
            if (selectedLang.isNotEmpty) {
              Get.off(() => SignInScreen());
            } else {
              CustomSnackbar.showError(
                context: context,
                title: 'Oops',
                message: 'Please select a language first',
              );
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: width * 0.1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(mascot2, height: 200, width: 300),
              Transform.translate(
                offset: Offset(0, -20),
                child: Text(
                  AppLocalizations.of(context)!.chooseLanguageLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: defaultSize),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  languageContainer('English'),
                  languageContainer('हिंदी'),
                ],
              ),
              SizedBox(height: defaultSize - 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  languageContainer('ਪੰਜਾਬੀ'),
                  languageContainer('ગુજરાતી'),
                ],
              ),
              SizedBox(height: defaultSize - 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  languageContainer('मराठी'),
                  languageContainer('डोगरी'),
                ],
              ),
              SizedBox(height: defaultSize - 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  languageContainer('सिन्धी'),
                  languageContainer('বাংলা'),
                ],
              ),
              SizedBox(height: defaultSize - 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  languageContainer('മലയാളം'),
                  languageContainer('ಕನ್ನಡ'),
                ],
              ),
              SizedBox(height: defaultSize - 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  languageContainer('தமிழ்'),
                  languageContainer('తెలుగు'),
                ],
              ),
              SizedBox(height: defaultSize - 10),
            ],
          ),
        ),
      ),
    );
  }
}
