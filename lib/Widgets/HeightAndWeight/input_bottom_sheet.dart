import 'package:snevva/Widgets/CommonWidgets/custom_outlined_button.dart';

import '../../Controllers/ProfileSetupAndQuestionnare/height_and_weight_controller.dart';
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
  final controller = Get.put(HeightWeightController());

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _validateAndSave(BuildContext context) {
    debugPrint('🟢 InputBottomSheet: _validateAndSave CALLED');

    final heightText = _heightController.text.trim();
    final weightText = _weightController.text.trim();

    debugPrint('✏️ Raw Input → height="$heightText", weight="$weightText"');

    if (heightText.isEmpty || weightText.isEmpty) {
      debugPrint('❌ One or both fields empty');

      Get.snackbar(
        'Empty Values',
        'Height and Weight cannot be empty',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.primaryColor,
        colorText: Colors.white,
        duration: const Duration(seconds: 1),
      );
      return;
    }

    final height = double.tryParse(heightText);
    final weight = double.tryParse(weightText);

    debugPrint('🔢 Parsed → height=$height, weight=$weight');

    if (height == null || weight == null) {
      debugPrint('❌ Parsing failed');

      Get.snackbar(
        'Invalid Values',
        'Please enter valid numeric values',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.primaryColor,
        colorText: Colors.white,
        duration: const Duration(seconds: 1),
      );
      return;
    }

    if (height < 50 || height > 250) {
      debugPrint('❌ Height out of range: $height');
      Get.snackbar(
        'Invalid Height',
        'Height must be between 50 cm and 250 cm',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.primaryColor,
        colorText: Colors.white,
        duration: const Duration(seconds: 1),
      );
      return;
    }

    if (weight < 20 || weight > 300) {
      debugPrint('❌ Weight out of range: $weight');
      Get.snackbar(
        'Invalid Weight',
        'Weight must be between 20 kg and 300 kg',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.primaryColor,
        colorText: Colors.white,
        duration: const Duration(seconds: 1),
      );
      return;
    }

    /// -------------------------------
    /// LOCAL STORAGE DEBUG + FIX
    /// -------------------------------
    debugPrint('🗂 userMap BEFORE save: ${localStorageManager.userMap}');

    // Ensure maps exist
    localStorageManager.userMap.value ??= {};
    localStorageManager.userMap['Height'] ??= {};
    localStorageManager.userMap['Weight'] ??= {};

    debugPrint('✅ Maps initialized');

    // Save values
    controller.updateFromCm(height);
    controller.setWeight(weight);

    debugPrint('💾 Saved Height = $height');
    debugPrint('💾 Saved Weight = $weight');

    debugPrint('🗂 userMap AFTER save: ${localStorageManager.userMap}');

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width;
    // ✅ Listens to the app's current theme command
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
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
