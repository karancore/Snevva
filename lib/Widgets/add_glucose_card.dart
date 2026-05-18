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

  @override
  void dispose() {
    // ✅ Fix 3: Clear input field when card is dismissed
    vitalsController.glucoseController.clear();
    super.dispose();
  }


  Future<void> _saveReading() async {
    final text = vitalsController.glucoseController.text.trim();

    if (text.isEmpty || double.tryParse(text) == null) {
      Get.snackbar(
        'Invalid Input',
        'Please enter a valid glucose value.',
      );
      return;
    }
    if (double.parse(text) < 1.0 || double.parse(text) > 33.3) {
      Get.snackbar(
        'Invalid Value',
        'Glucose must be between 1.0 and 33.3 mmol/L.',
      );
      return;
    }

    final success = await vitalsController.submitBloodGlucose(
      glucoseValue: double.parse(text),
      type: _selectedType,
      context: context,
    );

    if (success) {
      vitalsController.glucoseController.clear();
      if (mounted) Navigator.pop(context);
    }


    Get.snackbar(
      'Error',
      'Failed to save glucose record',
      backgroundColor: Colors.red,
    );

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

                  /// Purple BG — covers title + image + input zone
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: ClipPath(
                      clipper: BottomEllipseClipper(),
                      child: Container(
                        height: 290 * scale,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          color: const Color(0xffB475FF),
                        ),
                      ),
                    ),
                  ),

                  /// Main Column
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      // ── PURPLE ZONE ──────────────────────────────

                      /// Close + Title + Subtitle row at very top
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            /// Title + Subtitle
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Blood Glucose',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Track your blood glucose level and stay in control of your health.',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w400,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 12),

                            /// Close Button
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 5 * scale),

                      /// Glucose Drop Image (centered)
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.35),
                        ),
                        child: Image.asset(
                          glucoseDrop,
                          width: 80 * scale,
                          height: 80 * scale,
                        ),
                      ),

                      SizedBox(height: 10 * scale),

                      /// Input Chip — now where title used to be
                      Container(
                        width: 130 * scale,
                        height: 40 * scale,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.5),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 70 * scale,
                                child: TextFormField(
                                  controller:
                                  vitalsController.glucoseController,
                                  keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    height: 1,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  autofocus: true,
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    disabledBorder: InputBorder.none,
                                    errorBorder: InputBorder.none,
                                    focusedErrorBorder: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                    hintText: '0.0',
                                    hintStyle: TextStyle(
                                      color: Colors.white.withOpacity(0.4),
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 6 * scale),
                              Text(
                                "mmol/L",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 10,
                                  height: 1,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── WHITE ZONE ───────────────────────────────
                      SizedBox(height: 1 * scale),

                      /// "Your reading is" status — right below input
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: ValueListenableBuilder(
                          valueListenable: vitalsController.glucoseController,
                          builder: (context, value, child) {
                            final text = vitalsController
                                .glucoseController.text
                                .trim();
                            final isEmpty = text.isEmpty;
                            final status = getGlucoseStatus(
                                double.tryParse(text) ?? 0.0);

                            if (isEmpty) return const SizedBox.shrink();

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 14),
                              decoration: BoxDecoration(
                                color: status.containerBg,
                                border:
                                Border.all(color: status.containerBorder),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    height: 40,
                                    width: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: status.statusColor
                                          .withOpacity(0.2),
                                    ),
                                    child: Center(
                                      child: Icon(status.statusIcon,
                                          color: status.statusColor, size: 22),
                                    ),
                                  ),
                                  SizedBox(width: 10 * scale),
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Your reading is",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 10,
                                            color: isDarkMode ? white : black,
                                          ),
                                        ),
                                        SizedBox(height: 2 * scale),
                                        Text(
                                          status.statusLabel,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: status.statusColor,
                                          ),
                                        ),
                                        SizedBox(height: 2 * scale),
                                        Text(
                                          status.description,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w400,
                                            fontSize: 10,
                                            color: isDarkMode ? white : black,
                                            height: 1.4,
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

                      SizedBox(height: 14 * scale),

                      /// Fasting / Post Meal / Random
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
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

                      SizedBox(height: 12 * scale),

                      /// Conversion note
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            Icon(
                              FontAwesomeIcons.circleInfo,
                              size: 10,
                              color: isDarkMode
                                  ? white.withOpacity(0.4)
                                  : Colors.grey.shade400,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "To convert to mg/dL, multiply the value by 18",
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                fontSize: 10,
                                color: isDarkMode
                                    ? white.withOpacity(0.4)
                                    : Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 14 * scale),

                      /// Action Buttons
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            _cancelOrSave(
                              label: "Cancel",
                              color: cancelButtonColor,
                              borderColor: cancelButtonColor,
                              textColor: isDarkMode ? black : black,
                              scale: scale,
                              isDarkMode: isDarkMode,
                            ),
                            const SizedBox(width: 10),
                            _cancelOrSave(
                              label: "Save",
                              color: AppColors.primaryColor,
                              borderColor: AppColors.primaryColor,
                              textColor: isDarkMode ? white : white,
                              scale: scale,
                              isDarkMode: isDarkMode,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 16 * scale),
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

  Widget _glucoseType({
    required IconData icon,
    required String label,
    required double scale,
    required bool isDarkMode,
  }) {
    final bool isSelected = _selectedType == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = label),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 40 * scale,
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xffB475FF)
                  : glucoseChipColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? const Color(0xffB475FF)
                    : glucoseChipBorderColor,
                width: 0.5,
              ),
              boxShadow: isSelected
                  ? [
                BoxShadow(
                  color: const Color(0xffB475FF).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ]
                  : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 12 * scale,
                  color: isSelected ? white : borderChipUnitColor,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? white : black,
                    fontSize: 9 * scale,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cancelOrSave({
    required String label,
    required Color color,
    required Color borderColor,
    required Color textColor,
    required double scale,
    required bool isDarkMode,
  }) {
    final bool isSave = label == 'Save';
    return Expanded(
      flex: isSave ? 1 : 1,
      child: GestureDetector(
        onTap: isSave ? _saveReading : () => Navigator.pop(context),
        child: Container(
          height: 44 * scale,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 0.5),
            boxShadow: isSave
                ? [
              BoxShadow(
                color: AppColors.primaryColor.withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 12 * scale,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}