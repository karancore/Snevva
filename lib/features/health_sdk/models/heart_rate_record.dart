import 'package:flutter/material.dart';

class HeartRateRecord {
  final double beatsPerMinute;
  final DateTime recordedAt;
  final String? sourceName;

  const HeartRateRecord({
    required this.beatsPerMinute,
    required this.recordedAt,
    this.sourceName,
  });

  String get status {
    if (beatsPerMinute < 40) return 'Critical Low';
    if (beatsPerMinute < 60) return 'Low';
    if (beatsPerMinute <= 100) return 'Normal';
    if (beatsPerMinute <= 120) return 'Elevated';
    return 'High';
  }

  Color get statusColor {
    switch (status) {
      case 'Normal':
        return const Color(0xFF8CDC52);
      case 'Low':
      case 'Elevated':
        return const Color(0xFFFFD900);
      default:
        return const Color(0xFFFF5151);
    }
  }

  @override
  String toString() =>
      'HeartRateRecord(bpm: $beatsPerMinute, at: $recordedAt, src: $sourceName)';
}