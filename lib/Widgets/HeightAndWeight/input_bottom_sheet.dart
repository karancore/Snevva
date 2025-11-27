import 'package:snevva/Controllers/LocalStorageManager.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_outlined_button.dart';
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
  final localStorageManager = Get.put(LocalStorageManager());

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _validateAndSave() {
    final heightText = _heightController.text.trim();
    final weightText = _weightController.text.trim();

    if (heightText.isEmpty || weightText.isEmpty) {
      Get.snackbar("Error", "Height and Weight cannot be empty",
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final height = double.tryParse(heightText);
    final weight = double.tryParse(weightText);

    if (height == null || weight == null) {
      Get.snackbar("Error", "Please enter valid numeric values",
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    if (height < 50 || height > 250) {
      Get.snackbar("Error", "Height must be between 50 cm and 250 cm",
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    if (weight < 20 || weight > 300) {
      Get.snackbar("Error", "Weight must be between 20 kg and 300 kg",
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    // ✅ Save into localStorageManager
    localStorageManager.userMap['Height']['Value'] = height;
    localStorageManager.userMap['Weight']['Value'] = weight;

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
                      controller: _heightController, // ADDED
                      width: width,
                      isDarkMode: isDarkMode,
                      unit: 'cm',
                      hintText: 'Height',
                    ),
                    HeightAndWeighField(
                      controller: _weightController, // ADDED
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
                    buttonName: "Save",
                    onTap: _validateAndSave,
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
