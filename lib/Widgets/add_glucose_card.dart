import 'dart:ui';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:snevva/Controllers/Vitals/vitalsController.dart';
import 'package:snevva/models/glucose_status.dart';

import '../../consts/consts.dart';
import '../views/Vitals/glucose_screen.dart';

String formatDate(int day, int month, int year) {
  DateTime date = DateTime(year, month, day);
  return DateFormat('d MMMM, y').format(date);
}

const glucoseChipColor = Color(0xffEAD8FF);
const glucoseChipBorderColor = Color(0xffDDC0FF);
const borderChipUnitColor = Color(0xffB475FF);
const glucoseLabelContainerBorderColor = Color(0xffDAF8FF);
const glucoseLabelContainerColor = Color(0xffF5F9F9);
const smileyContainer = Color(0xffD4F0E1);
const cancelButtonColor = Color(0xffF3F2FB);
const smileyColor = Color(0xff2DBF5F);

class AddGlucoseCard extends StatefulWidget {
  const AddGlucoseCard({super.key});

  @override
  State<AddGlucoseCard> createState() => _AddGlucoseCardState();
}

class _AddGlucoseCardState extends State<AddGlucoseCard> {


  late VitalsController vitalsController;
  String _selectedType = 'Fasting';

  @override
  void initState() {
    vitalsController = Get.find<VitalsController>();
    super.initState();
  }


  Future<void> _saveReading() async {
    final text = vitalsController.glucoseController.text.trim();
    if (text.isEmpty || double.tryParse(text) == null) {
      Get.snackbar(
        'Invalid Input',
        'Please enter a valid glucose value.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    await vitalsController.addGlucoseReading(text, _selectedType);
    vitalsController.glucoseController.clear();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double scale = screenWidth / 360;
    final bool isDarkMode = Theme
        .of(context)
        .brightness == Brightness.dark;

    return Stack(

      children: [
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(color: Colors.black.withOpacity(0)),
        ),

        Center(
          child: Material(

            color: Colors.transparent,
            child: Container(
              width: 360 * scale,
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: isDarkMode ? darkGray : white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),

              child: Stack(
                children: [

                  /// Purple BG — Positioned, does NOT affect card height
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: ClipPath(
                      clipper: BottomEllipseClipper(),
                      child: Container(
                        height: 340 * scale,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          color: const Color(0xffB475FF),
                        ),
                      ),
                    ),
                  ),

                  /// Single Column — drives card height
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── PURPLE ZONE ──────────────────────────────

                      /// Close Button
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      /// Glucose Drop Image
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.35),
                        ),
                        child: Image.asset(
                          glucoseDrop,
                          width: 120 * scale,
                          height: 120 * scale,
                        ),
                      ),

                      SizedBox(height: scale * 8),

                      /// Title
                      const Text(
                        'Blood Glucose',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          height: 1,
                        ),
                      ),

                      SizedBox(height: scale * 5),

                      /// Subtitle
                      const Text(
                        'Track your blood glucose level and \nstay in control of your health.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w400,
                          height: 1,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      // ── WHITE ZONE ───────────────────────────────
                      SizedBox(height: 30 * scale),

                      /// Input Chip — value + unit
                      Container(
                        width: 92 * scale,
                        height: 32 * scale,
                        decoration: BoxDecoration(
                          color: glucoseChipColor,
                          border: Border.all(
                            color: glucoseChipBorderColor,
                            width: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 55 * scale,
                                child: TextFormField(
                                  controller: vitalsController
                                      .glucoseController,
                                  keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isDarkMode ? white : black,
                                    fontSize: 18,
                                    height: 1,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  autofocus: true,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    disabledBorder: InputBorder.none,
                                    errorBorder: InputBorder.none,
                                    focusedErrorBorder: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                    hintText: '',
                                  ),
                                ),
                              ),
                              SizedBox(width: 4 * scale),
                              const Text(
                                "mmol/L",
                                style: TextStyle(
                                  color: borderChipUnitColor,
                                  fontSize: 7,
                                  height: 1,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 15 * scale),

                      /// Fasting / Post Meal / Custom
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _glucoseType(
                              icon: FontAwesomeIcons.utensils,
                              label: "Fasting",
                              scale: scale,
                              isDarkMode: isDarkMode,
                            ),
                            _glucoseType(
                              icon: FontAwesomeIcons.bowlFood,
                              label: "Post Meal",
                              scale: scale,
                              isDarkMode: isDarkMode,
                            ),
                            _glucoseType(
                              icon: FontAwesomeIcons.droplet,
                              label: "Random",
                              scale: scale,
                              isDarkMode: isDarkMode,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 15 * scale),

                      /// Status Container — reactive to input
                      /// Status Container — reactive to input
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: ValueListenableBuilder(
                          valueListenable: vitalsController.glucoseController,
                          builder: (context, value, child) {
                            final text = vitalsController.glucoseController.text
                                .trim();
                            final isEmpty = text.isEmpty;
                            final status = getGlucoseStatus(
                                double.tryParse(text) ?? 0.0);

                            // ✅ Hide entire container when field is empty
                            if (isEmpty) return const SizedBox.shrink();

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14, horizontal: 14),
                              decoration: BoxDecoration(
                                color: status.containerBg,
                                border: Border.all(
                                    color: status.containerBorder),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    height: 40,
                                    width: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: status.statusColor.withOpacity(
                                          0.2),
                                    ),
                                    child: Center(
                                      child: Icon(status.statusIcon,
                                          color: status.statusColor, size: 28),
                                    ),
                                  ),
                                  SizedBox(width: 5 * scale),
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment
                                          .start,
                                      children: [
                                        Text(
                                          "Your reading is",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 10,
                                            color: isDarkMode ? white : black,
                                          ),
                                        ),
                                        SizedBox(height: 4 * scale),
                                        Text(
                                          status.statusLabel,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                            color: status.statusColor,
                                          ),
                                        ),
                                        SizedBox(height: 4 * scale),
                                        Text(
                                          status.description,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w400,
                                            fontSize: 10,
                                            color: isDarkMode ? white : black,
                                          ),
                                          softWrap: true,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      SizedBox(height: 15 * scale),

                      Text(
                        "Note : To convert in mg/dL , Multiply the value by 18",
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 10,
                          color: darkGray,
                        ),
                      ),

                      SizedBox(height: 8 * scale),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _cancelOrSave(
                            label: "Save Readings",
                            color: AppColors.primaryColor,
                            borderColor: AppColors.primaryColor,
                            textColor: isDarkMode ? white : black,
                            scale: scale,
                            isDarkMode: isDarkMode,
                          ),
                          _cancelOrSave(
                            label: "Cancel",
                            color: cancelButtonColor,
                            borderColor: cancelButtonColor,
                            textColor: isDarkMode ? black : white,
                            scale: scale,
                            isDarkMode: isDarkMode,
                          ),
                        ],
                      ),

                      SizedBox(height: 15 * scale),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Widget _glucoseType({
  //   required IconData icon,
  //   required String label,
  //   required double scale,
  //   required bool isDarkMode,
  // }) {
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
  //     child: Container(
  //       height: 32 * scale,
  //       width: 98 * scale,
  //       padding: EdgeInsets.symmetric(
  //         horizontal: 12 * scale,
  //         vertical: 4 * scale,
  //       ),
  //       decoration: BoxDecoration(
  //         color: glucoseChipColor,
  //         borderRadius: BorderRadius.circular(3),
  //         border: Border.all(color: glucoseChipBorderColor, width: 0.5),
  //       ),
  //       child: Row(
  //         children: [
  //           Icon(icon, size: 12 * scale, color: borderChipUnitColor),
  //           SizedBox(width: 4 * scale),
  //           Expanded(
  //             child: Text(
  //               label,
  //               maxLines: 1,
  //               overflow: TextOverflow.ellipsis,
  //               style: TextStyle(
  //                 color: isDarkMode ? white : black,
  //                 fontSize: 11 * scale,
  //                 fontWeight: FontWeight.w600,
  //               ),
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }
  //
  // Widget _cancelOrSave({
  //   required String label,
  //   required Color color,
  //   required Color borderColor,
  //   required Color textColor,
  //   required double scale,
  //   required bool isDarkMode,
  // }) {
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
  //     child: Container(
  //       height: 32 * scale,
  //       width: 125 * scale,
  //       padding: EdgeInsets.symmetric(
  //         horizontal: 12 * scale,
  //         vertical: 4 * scale,
  //       ),
  //       decoration: BoxDecoration(
  //         color: color,
  //         borderRadius: BorderRadius.circular(12),
  //         border: Border.all(color: borderColor, width: 0.5),
  //       ),
  //       child: Center(
  //         child: Text(
  //           label,
  //           style: TextStyle(
  //             color: textColor,
  //             fontSize: 8 * scale,
  //             fontWeight: FontWeight.w600,
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  Widget _glucoseType({
    required IconData icon,
    required String label,
    required double scale,
    required bool isDarkMode,
  }) {
    final bool isSelected = _selectedType == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = label),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
        child: Container(
          height: 32 * scale,
          width: 98 * scale,
          padding: EdgeInsets.symmetric(
            horizontal: 12 * scale,
            vertical: 4 * scale,
          ),
          decoration: BoxDecoration(
            // ✅ Highlight selected type
            color: isSelected
                ? const Color(0xffB475FF)
                : glucoseChipColor,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: isSelected
                  ? const Color(0xffB475FF)
                  : glucoseChipBorderColor,
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 12 * scale,
                color: isSelected ? white : borderChipUnitColor,
              ),
              SizedBox(width: 4 * scale),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected
                        ? white
                        : (isDarkMode ? white : black),
                    fontSize: 11 * scale,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Replace the "Save Readings" InkWell / GestureDetector to call _saveReading:
  Widget _cancelOrSave({
    required String label,
    required Color color,
    required Color borderColor,
    required Color textColor,
    required double scale,
    required bool isDarkMode,
  }) {
    return GestureDetector(
      onTap: label == 'Save Readings' ? _saveReading : () =>
          Navigator.pop(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
        child: Container(
          height: 32 * scale,
          width: 125 * scale,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 0.5),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 8 * scale,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

}