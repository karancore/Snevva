import 'package:snevva/Widgets/CommonWidgets/custom_outlined_button.dart';
import 'package:snevva/common/custom_snackbar.dart';
import '../../Controllers/local_storage_manager.dart';
import '../../consts/consts.dart';
import '../ProfileSetupAndQuestionnaire/height_and_weight_field.dart';

class InputBottomSheet extends StatefulWidget {
  const InputBottomSheet({super.key});

  @override
  State<InputBottomSheet> createState() => _InputBottomSheetState();
}

class _InputBottomSheetState extends State<InputBottomSheet> {
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final localStorageManager = Get.find<LocalStorageManager>();

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _validateAndSave(BuildContext context) {
    final heightText = _heightController.text.trim();
    final weightText = _weightController.text.trim();

    if (heightText.isEmpty || weightText.isEmpty) {
      CustomSnackbar.showError(
        context: context,
        title: "title",
        message: "message",
      );
      return;
    }

    final height = double.tryParse(heightText);
    final weight = double.tryParse(weightText);

    if (height == null || weight == null) {
      CustomSnackbar.showError(
        context: context,
        title: "Error",
        message: "Please enter valid numeric values",
      );

      return;
    }

    if (height < 50 || height > 250) {
      CustomSnackbar.showError(
        context: context,
        title: "Error",
        message: "Height must be between 50 cm and 250 cm",
      );
      return;
    }

    if (weight < 20 || weight > 300) {
      CustomSnackbar.showError(
        context: context,
        title: "Error",
        message: "Weight must be between 20 kg and 300 kg",
      );
      return;
    }

    // ✅ Save into localStorageManager
    localStorageManager.userMap['Height']['Value'] = height;
    localStorageManager.userMap['Weight']['Value'] = weight;
    print("Input Bottom Sheet : $height");
    print("Input Bottom Sheet : $weight");


    print("Updated Height/Weight → ${localStorageManager.userMap}");

    Navigator.pop(context); // close bottom sheet
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width;
    final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          color: isDarkMode ? scaffoldColorDark : scaffoldColorLight,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),

                /// 🟦 HEIGHT & WEIGHT FIELDS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    HeightAndWeighField(
                      controller: _heightController,
                      // ADDED
                      width: width,
                      isDarkMode: isDarkMode,
                      unit: 'cm',
                      hintText: 'Height',
                    ),
                    HeightAndWeighField(
                      controller: _weightController,
                      // ADDED
                      width: width,
                      isDarkMode: isDarkMode,
                      unit: 'Kg',
                      hintText: 'Weight',
                    ),
                  ],
                ),

                const SizedBox(height: defaultSize),

                /// 🟩 SAVE BUTTON WITH VALIDATION
                SafeArea(
                  child: CustomOutlinedButton(
                    width: width,
                    isDarkMode: isDarkMode,
                    backgroundColor: AppColors.primaryColor,
                    buttonName: "Save",
                    onTap: () => _validateAndSave(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
