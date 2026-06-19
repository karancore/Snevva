import 'package:flutter/material.dart';

class BloodPressureRecord {
  final double systolic;   // mmHg
  final double diastolic;  // mmHg
  final DateTime recordedAt;
  final String? sourceName;

  const BloodPressureRecord({
    required this.systolic,
    required this.diastolic,
    required this.recordedAt,
    this.sourceName,
  });

  // AHA / ACC 2017 classification
  String get category {
    if (systolic < 120 && diastolic < 80) return 'Normal';
    if (systolic < 130 && diastolic < 80) return 'Elevated';
    if (systolic < 140 || diastolic < 90) return 'High Stage 1';
    if (systolic < 180 && diastolic < 120) return 'High Stage 2';
    return 'Crisis';
  }

  Color get statusColor {
    switch (category) {
      case 'Normal':
        return const Color(0xFF8CDC52);
      case 'Elevated':
        return const Color(0xFFFFD900);
      case 'High Stage 1':
        return const Color(0xFFFF9238);
      default:
        return const Color(0xFFFF5151);
    }
  }

  String get formatted => '${systolic.toStringAsFixed(0)}/${diastolic.toStringAsFixed(0)}';

  @override
  String toString() =>
      'BloodPressureRecord($formatted mmHg, at: $recordedAt)';
}