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

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width;
    final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom,),
      child: Container(

        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          color: isDarkMode? scaffoldColorDark : scaffoldColorLight,

        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    HeightAndWeighField(
                      width: width,
                      isDarkMode: isDarkMode,
                      unit: 'cm',
                      hintText: 'Height',
                    ),
                    HeightAndWeighField(
                      width: width,
                      isDarkMode: isDarkMode,
                      unit: 'Kg',
                      hintText: 'Weight',
                    ),
                  ],
                ),
                const SizedBox(height: defaultSize),

               SafeArea(child: CustomOutlinedButton(width: width, isDarkMode: isDarkMode, buttonName: "Save", onTap: (){})),

              ],
            ),
          ),
        ),
      ),
    );
  }
}
