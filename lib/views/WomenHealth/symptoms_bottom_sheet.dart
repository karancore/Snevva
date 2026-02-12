import 'package:snevva/Controllers/WomenHealth/bottom_sheet_controller.dart';
import 'package:snevva/models/period_symptom_model.dart';

import '../../consts/consts.dart';

class SymptomsBottomSheet extends StatelessWidget {
  SymptomsBottomSheet({super.key});

  final List<SymptomOptions> symptomsList = [
    SymptomOptions(heading: 'Clotting', icon: clottingIcon),
    SymptomOptions(heading: 'Bloating', icon: bloatingIcon),
    SymptomOptions(heading: 'Headache', icon: headacheIcon),
    SymptomOptions(heading: 'Cramps', icon: crampsIcon),
    SymptomOptions(heading: 'Dizziness', icon: dizzinessIcon),
    SymptomOptions(heading: 'Cravings', icon: cravingsIcon),
    SymptomOptions(heading: 'Back Pain', icon: backPainIcon),
    SymptomOptions(heading: 'Mood Swings', icon: moodSwingsIcon),
    SymptomOptions(heading: 'Nausea', icon: nauseaIcon),
    SymptomOptions(heading: 'Diarrhea', icon: diarrheaIcon),
    SymptomOptions(heading: 'Constipation', icon: constipationIcon),
    SymptomOptions(heading: 'Stress', icon: stressIcon),
    SymptomOptions(heading: 'Fever', icon: feverIcon),
    SymptomOptions(heading: 'Joint Pain', icon: jointPainIcon),
    SymptomOptions(heading: 'Muscle Pain', icon: musclePainIcon),
    SymptomOptions(heading: 'Acne', icon: acneIcon),
    SymptomOptions(heading: 'Fatigue', icon: fatigueIcon),
    SymptomOptions(heading: 'Flow', icon: flowIcon),
    SymptomOptions(heading: 'Spotting', icon: spottingIcon),
  ];
  final BottomSheetController bottomSheetController = Get.put(
    BottomSheetController(),
  );

  final TextEditingController noteController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    //   final height = mediaQuery.size.height;

    // final width = mediaQuery.size.width;
    // ✅ Listens to the app's current theme command
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: mediaQuery.viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Select Symptoms",
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 20),
              ),
              SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children:
                    symptomsList.map((symptomOptions) {
                      return getSymptoms(
                        symptomOptions.heading,
                        symptomOptions.icon,
                        () => bottomSheetController.toggleSymptom(
                          symptomOptions.heading,
                        ),
                        isDarkMode,
                      );
                    }).toList(),
              ),
              SizedBox(height: 20),
              // Obx(() {
              //   final selected = bottomSheetController.selectedSymptoms;
              //   final selectedSymptom =
              //       selected.isNotEmpty ? selected.last : "a Symptom";

              //   return Text(
              //     "Select $selectedSymptom Level",
              //     style: TextStyle(fontWeight: FontWeight.w500, fontSize: 20),
              //   );
              // }),
              // SizedBox(height: 10),
              // Row(
              //   children: [
              //     getSymptoms(
              //       "Mild",
              //       level3,
              //       () => bottomSheetController.toggleSymptomLevel("Mild"),
              //       isDarkMode,
              //       isLevel: true,
              //     ),

              //     SizedBox(width: 10),
              //     getSymptoms(
              //       "Moderate",
              //       level1,
              //       () => bottomSheetController.toggleSymptomLevel("Moderate"),
              //       isDarkMode,
              //       isLevel: true,
              //     ),
              //     SizedBox(width: 10),
              //     getSymptoms(
              //       "Severe",
              //       level2,
              //       () => bottomSheetController.toggleSymptomLevel("Severe"),
              //       isDarkMode,
              //       isLevel: true,
              //     ),
              //   ],
              // ),

              // SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    "Notes",
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 20),
                  ),
                  Text(
                    "(optional)",
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 20,
                      color: mediumGrey,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Material(
                elevation: 1,
                borderRadius: BorderRadius.circular(4),
                color: isDarkMode ? scaffoldColorDark : scaffoldColorLight,
                clipBehavior: Clip.antiAlias,
                child: TextFormField(
                  controller: noteController,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isDarkMode ? darkGray : white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    hintText: 'Write Something',
                    hintStyle: const TextStyle(color: mediumGrey),
                  ),
                ),
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () {
                      // Clear selected symptoms and note on Cancel
                      bottomSheetController.selectedSymptoms.clear();
                      noteController.clear();

                      Get.back();
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: isDarkMode ? darkGray : white,
                    ),
                    child: Text(
                      "Cancel",
                      style: TextStyle(color: isDarkMode ? white : black),
                    ),
                  ),
                  const Spacer(),
                  SafeArea(
                    child: OutlinedButton(
                      onPressed: () {
                        // Save API
                        bottomSheetController.addsymptoAPI(
                          bottomSheetController.selectedSymptoms.toList(),
                          noteController.text.trim(),
                        );

                        // Clear selected symptoms and note after Save
                        bottomSheetController.selectedSymptoms.clear();
                        noteController.clear();

                        Get.back();
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        side: BorderSide.none,
                      ),
                      child: Text("Save", style: TextStyle(color: white)),
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

  Widget getSymptoms(
    String heading,
    String icon,
    VoidCallback onTap,
    bool isDarkMode, {
    bool isLevel = false,
  }) {
    return Obx(() {
      final isSelected = bottomSheetController.selectedSymptoms.contains(
        heading,
      );
      return InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(width: border04px, color: Colors.grey),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image(image: AssetImage(icon), height: 12, width: 12),
              const SizedBox(width: 5),
              Text(
                heading,
                style: TextStyle(
                  fontSize: 10,
                  color:
                      isSelected
                          ? white
                          : isDarkMode
                          ? white
                          : black,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

void showSymptomsBottomSheet(
  BuildContext context,
  bool isDarkMode,
  double height,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: isDarkMode ? darkGray : scaffoldColorLight,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => SymptomsBottomSheet(),
  ).then((selectedTime) {
    if (selectedTime != null) {
      //  print("Selected time: $selectedTime");
    }
  });
}
