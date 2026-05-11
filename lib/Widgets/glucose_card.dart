import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../consts/colors.dart';
import '../consts/images.dart';

enum GlucoseStatus { low, normal, high }

const Color sugarTypeBorderColor = Color(0xffD2D2D2);
const Color sugarTypeShadowColor = Color(0x40000000);

class GlucoseCard extends StatelessWidget {
  final String glucoseLevel; // mmol/L value as string
  final String time; // ISO8601
  final String type; // "Fasting" | "Post Meal" | "Custom"

  const GlucoseCard({
    super.key,
    required this.glucoseLevel,
    required this.time,
    required this.type,
  });

  GlucoseStatus _getStatus(String level) {
    final value = double.tryParse(level);
    if (value == null) return GlucoseStatus.normal;
    // mmol/L thresholds: <3.9 low, >10.0 high
    if (value < 3.9) return GlucoseStatus.low;
    if (value > 10.0) return GlucoseStatus.high;
    return GlucoseStatus.normal;
  }

  String _getStatusLabel(GlucoseStatus status) {
    return switch (status) {
      GlucoseStatus.low => 'Low',
      GlucoseStatus.high => 'High',
      GlucoseStatus.normal => 'Normal',
    };
  }

  Color _getStatusColor(GlucoseStatus status) {
    return switch (status) {
      GlucoseStatus.low => const Color(0xffE05050),
      GlucoseStatus.high => const Color(0xffE08A00),
      GlucoseStatus.normal => AppColors.glucoseColor,
    };
  }

  IconData _getTypeIcon() {
    return switch (type) {
      'Fasting' => Icons.bloodtype,
      'Post Meal' => Icons.restaurant,
      _ => Icons.water_drop,
    };
  }

  @override
  Widget build(BuildContext context) {
    final status = _getStatus(glucoseLevel);
    final statusColor = _getStatusColor(status);
    final bool isDarkMode = Theme
        .of(context)
        .brightness == Brightness.dark;
    final double scale = MediaQuery
        .of(context)
        .size
        .width / 360;

    return Card(
      color: isDarkMode ? darkGray : white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      elevation: 4.0,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60 * scale,
                  height: 60 * scale,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? const Color(0xff2A1A4A)
                        : const Color(0xffF5F4FE),
                    borderRadius: BorderRadius.circular(6.0),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Blood Glucose',
                        style: TextStyle(
                          fontSize: 18.0,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? white : black,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      // Show mmol/L + converted mg/dL
                      Text(
                        '$glucoseLevel mmol/L',
                        style: TextStyle(
                          fontSize: 24.0,
                          color: isDarkMode ? white : black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '≈ ${_toMgDl(glucoseLevel)} mg/dL',
                        style: TextStyle(
                          fontSize: 12.0,
                          color: isDarkMode
                              ? Colors.grey[400]
                              : Colors.grey[600],
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
                    color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
                  ),
                ),
              ],
            ),

            SizedBox(height: 16.0 * scale),

            // ── Status row ──────────────────────────────────────────────
            Row(
              children: [
                Text(
                  "Hypos Level | ",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    height: 1,
                    fontSize: 18,
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

            // ── Type chip ───────────────────────────────────────────────
            Row(
              children: [
                _typeChip(
                  icon: _getTypeIcon(),
                  label: type,
                  scale: scale,
                  isDarkMode: isDarkMode,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// mmol/L → mg/dL
  String _toMgDl(String mmol) {
    final v = double.tryParse(mmol);
    if (v == null) return '—';
    return (v * 18).toStringAsFixed(0);
  }

  Widget _typeChip({
    required IconData icon,
    required String label,
    required double scale,
    required bool isDarkMode,
  }) {
    return Container(
      height: 24 * scale,
      padding: const EdgeInsets.symmetric(vertical: 4.5, horizontal: 12.5),
      decoration: BoxDecoration(
        border: Border.all(
          color: isDarkMode ? Colors.grey[700]! : sugarTypeBorderColor,
          width: 1,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(5)),
        color: isDarkMode ? darkGray : white,
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? white.withOpacity(0.1) : sugarTypeShadowColor,
            offset: const Offset(1, 1),
            blurRadius: 1,
            spreadRadius: -1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 15 * scale,
            width: 15 * scale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.glucoseColor,
            ),
            padding: const EdgeInsets.all(2),
            child: Center(
              child: Icon(icon, color: white, size: 9),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? white : black,
            ),
          ),
        ],
      ),
    );
  }
}