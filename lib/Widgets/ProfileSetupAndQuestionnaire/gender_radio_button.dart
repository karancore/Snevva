import '../../Controllers/ProfileSetupAndQuestionnare/profile_setup_controller.dart';
import '../../Controllers/local_storage_manager.dart';
import '../../consts/consts.dart';
import '../../views/ProfileAndQuestionnaire/profile_setup_initial.dart';

class GenderRadioButton extends StatelessWidget {
  const GenderRadioButton({super.key});

  @override
  Widget build(BuildContext context) {
    final initialProfileController = Get.put(ProfileSetupController());

    return RadioTheme(
      data: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return Colors.white;
          }
          return Colors.white.withOpacity(0.5);
        }),
      ),
      child: Obx(
        () => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RadioMenuButton<String>(
                    value: 'Male',
                    groupValue: initialProfileController.userGenderValue.value,
                    style: ButtonStyle(
                      overlayColor: MaterialStateProperty.all(
                        Colors.transparent,
                      ),
                      foregroundColor: MaterialStateProperty.all(Colors.white),
                    ),
                    onChanged: (value) {
                      if (value != null) {
                        initialProfileController.setGender(value);
                        final localStorageManager =
                            Get.find<LocalStorageManager>();
                        localStorageManager.userMap['Gender'] = value;
                      }
                    },

                    child: AutoSizeText(
                      AppLocalizations.of(context)!.male,
                      minFontSize: 10,
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  RadioMenuButton<String>(
                    value: 'Female',
                    style: ButtonStyle(
                      overlayColor: MaterialStateProperty.all(
                        Colors.transparent,
                      ),

                      foregroundColor: MaterialStateProperty.all(Colors.white),
                    ),
                    groupValue: initialProfileController.userGenderValue.value,
                    onChanged: (value) {
                      if (value != null) {
                        initialProfileController.setGender(value);
                        final localStorageManager =
                            Get.find<LocalStorageManager>();
                        localStorageManager.userMap['Gender'] = value;
                      }
                    },

                    child: AutoSizeText(
                      AppLocalizations.of(context)!.female,
                      minFontSize: 10,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RadioMenuButton<String>(
                    value: 'Other',
                    style: ButtonStyle(
                      overlayColor: MaterialStateProperty.all(
                        Colors.transparent,
                      ),

                      foregroundColor: MaterialStateProperty.all(Colors.white),
                    ),
                    groupValue: initialProfileController.userGenderValue.value,
                    onChanged: (value) {
                      if (value != null) {
                        initialProfileController.setGender(value);
                        final localStorageManager =
                            Get.find<LocalStorageManager>();
                        localStorageManager.userMap['Gender'] = value;
                      }
                    },

                    child: AutoSizeText(
                      AppLocalizations.of(context)!.other,
                      minFontSize: 10,
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  RadioMenuButton<String>(
                    value: 'PreferNotToSay',
                    style: ButtonStyle(
                      overlayColor: MaterialStateProperty.all(
                        Colors.transparent,
                      ),

                      foregroundColor: MaterialStateProperty.all(Colors.white),
                    ),
                    groupValue: initialProfileController.userGenderValue.value,
                    onChanged: (value) {
                      if (value != null) {
                        initialProfileController.setGender(value);
                        final localStorageManager =
                            Get.find<LocalStorageManager>();
                        localStorageManager.userMap['Gender'] = value;
                      }
                    },
                    child: AutoSizeText(
                      AppLocalizations.of(context)!.preferNotToSay,
                      minFontSize: 10,
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
