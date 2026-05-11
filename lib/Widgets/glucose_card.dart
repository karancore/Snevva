import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../consts/colors.dart';
import '../consts/images.dart';

enum GlucoseStatus { low, normal, high }

const Color sugarTypeBorderColor = Color(0xffD2D2D2);
const Color sugarTypeShadowColor = Color(0x40000000);

class GlucoseCard extends StatelessWidget {
  final String glucoseLevel;
  final String time;

  const GlucoseCard({
    super.key,
    required this.glucoseLevel,
    required this.time,
  });

  GlucoseStatus _getStatus(String level) {
    final value = double.tryParse(level);
    if (value == null) return GlucoseStatus.normal;
    if (value < 70) return GlucoseStatus.low;
    if (value > 180) return GlucoseStatus.high;
    return GlucoseStatus.normal;
  }

  Color _getStatusColor(GlucoseStatus status) {
    return switch (status) {
      GlucoseStatus.low => AppColors.glucoseColor,
      GlucoseStatus.high => AppColors.glucoseColor,
      GlucoseStatus.normal => AppColors.glucoseColor,
    };
  }

  String _getStatusLabel(GlucoseStatus status) {
    return switch (status) {
      GlucoseStatus.low => 'Low',
      GlucoseStatus.high => 'High',
      GlucoseStatus.normal => 'Normal',
    };
  }

  @override
  Widget build(BuildContext context) {
    final status = _getStatus(glucoseLevel);
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _getStatusColor(status);
    double scale = MediaQuery.of(context).size.width / 360;

    return Card(
      color: isDarkMode ? darkGray : white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      elevation: 4.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60 * scale,
                  height: 60 * scale,
                  decoration: BoxDecoration(
                    // ✅ Dark: dark purple tint | Light: light purple tint
                    color:
                        isDarkMode
                            ? const Color(0xff2A1A4A)
                            : const Color(0xffF5F4FE),
                    borderRadius: BorderRadius.circular(6.0),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 16.0,
                  ),
                  child: Center(
                    child: Image.asset(
                      glucoseDrop,
                      height: 40 * scale,
                      width: 29 * scale,
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Column(
                    children: [
                      Text(
                        'Blood Glucose',
                        style: TextStyle(
                          fontSize: 18.0,
                          fontWeight: FontWeight.w600,
                          // ✅ Dark: white | Light: default (black)
                          color: isDarkMode ? white : black,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      Text(
                        ' $glucoseLevel mg/dL',
                        style: TextStyle(
                          fontSize: 28.0,
                          // ✅ Already had this — kept
                          color: isDarkMode ? white : black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),
                Text(
                  DateFormat('h:mm a').format(DateTime.parse(time)),
                  style: TextStyle(
                    fontSize: 14.0,
                    // ✅ Dark: light grey | Light: dark grey
                    color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
                  ),
                ),
              ],
            ),

            SizedBox(height: 16.0 * scale),

            Row(
              children: [
                Text(
                  "Hypos Level | ",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    height: 1,
                    fontSize: 18,
                    // ✅ Dark: white | Light: black
                    color: isDarkMode ? white : black,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 2.0,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(5.0),
                  ),
                  child: Text(
                    _getStatusLabel(status),
                    style: const TextStyle(
                      fontSize: 14.0,
                      color: white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 16 * scale),

            Row(
              children: [
                // Fasting chip
                Container(
                  height: 24 * scale,
                  width: 130 * scale,
                  padding: const EdgeInsets.symmetric(
                    vertical: 4.5,
                    horizontal: 12.5,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      // ✅ Dark: dim border | Light: original border
                      color:
                          isDarkMode ? Colors.grey[700]! : sugarTypeBorderColor,
                      width: 1,
                    ),
                    borderRadius: const BorderRadius.all(Radius.circular(5)),
                    color: isDarkMode ? darkGray : white,
                    boxShadow: [
                      BoxShadow(
                        color:
                            isDarkMode
                                ? white.withOpacity(0.1)
                                : sugarTypeShadowColor,
                        offset: const Offset(1, 1),
                        blurRadius: 1,
                        spreadRadius: -1,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 15 * scale,
                        width: 15 * scale,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.glucoseColor,
                        ),
                        padding: const EdgeInsets.all(2),
                        child: const Center(
                          child: Icon(Icons.bloodtype, color: white, size: 12),
                        ),
                      ),
                      const Spacer(flex: 2),
                      Text(
                        "Fasting",
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          // ✅ Dark: white | Light: black
                          color: isDarkMode ? white : black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const Spacer(flex: 2),
                    ],
                  ),
                ),

                SizedBox(width: 18 * scale),

                // Insulin chip
                Container(
                  height: 24 * scale,
                  width: 130 * scale,
                  padding: const EdgeInsets.symmetric(
                    vertical: 4.5,
                    horizontal: 12.5,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      // ✅ Dark: dim border | Light: original border
                      color:
                          isDarkMode ? Colors.grey[700]! : sugarTypeBorderColor,
                      width: 1,
                    ),
                    borderRadius: const BorderRadius.all(Radius.circular(5)),
                    color: isDarkMode ? darkGray : white,
                    boxShadow: [
                      BoxShadow(
                        color: sugarTypeShadowColor,
                        offset: const Offset(1, 1),
                        blurRadius: 1,
                        spreadRadius: -1,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 15 * scale,
                        width: 15 * scale,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDarkMode ? darkGray : white,
                          border: Border.all(
                            color: AppColors.glucoseColor,
                            width: 1,
                          ),
                        ),
                        child: FaIcon(
                          FontAwesomeIcons.syringe,
                          color: AppColors.glucoseColor,
                          size: 7 * scale,
                        ),
                      ),
                      const Spacer(flex: 2),
                      Text(
                        "10 insulin units",
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          // ✅ Dark: white | Light: black
                          color: isDarkMode ? white : black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const Spacer(flex: 2),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
