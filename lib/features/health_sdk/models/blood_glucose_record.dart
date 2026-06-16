import 'package:flutter/material.dart';

// The `health` package returns blood glucose in mmol/L on both platforms.
class BloodGlucoseRecord {
  final double mmolPerL;
  final DateTime recordedAt;
  final String? sourceName;

  const BloodGlucoseRecord({
    required this.mmolPerL,
    required this.recordedAt,
    this.sourceName,
  });

  // Convenience conversion; display layer can pick the preferred unit.
  double get mgPerDl => mmolPerL * 18.0;

  String get status {
    // WHO fasting reference ranges in mmol/L
    if (mmolPerL < 3.9) return 'Low';
    if (mmolPerL <= 5.5) return 'Normal';
    if (mmolPerL <= 6.9) return 'Pre-diabetic';
    return 'High';
  }

  Color get statusColor {
    switch (status) {
      case 'Normal':
        return const Color(0xFF8CDC52);
      case 'Pre-diabetic':
      case 'Low':
        return const Color(0xFFFFD900);
      default:
        return const Color(0xFFFF5151);
    }
  }

  @override
  String toString() =>
      'BloodGlucoseRecord(mmol/L: $mmolPerL, at: $recordedAt)';
}