import 'package:flutter/material.dart';

/// Add this inside getGlucoseStatus return or as separate helper
extension GlucoseStatusColors on GlucoseStatus {
  Color get containerBg => statusColor.withOpacity(0.08);

  Color get containerBorder => statusColor.withOpacity(0.25);
}

class GlucoseStatus {
  final String statusLabel;
  final Color statusColor;
  final String description;
  final IconData statusIcon;

  const GlucoseStatus({
    required this.statusLabel,
    required this.statusColor,
    required this.description,
    required this.statusIcon,
  });
}

GlucoseStatus getGlucoseStatus(double mmol) {
  // LOW  (< 3.9)
  if (mmol < 3.9) {
    return const GlucoseStatus(
      statusLabel: "Low Sugar",
      statusColor: Color(0xffFF6B6B),
      statusIcon: Icons.sentiment_dissatisfied_outlined,
      description:
          "Your blood glucose level is lower than normal. Consider eating something.",
    );
  }

  // HEALTHY  (3.9 – 5.5)
  if (mmol < 5.6) {
    return const GlucoseStatus(
      statusLabel: "Healthy",
      statusColor: Color(0xff2DBF5F),
      statusIcon: Icons.sentiment_satisfied_alt_outlined,
      description: "Your blood glucose level is within the normal range.",
    );
  }

  // SLIGHTLY ELEVATED  (5.6 – 6.9)
  if (mmol < 7.0) {
    return const GlucoseStatus(
      statusLabel: "Watch Out",
      statusColor: Color(0xffF5A623),
      statusIcon: Icons.sentiment_neutral_outlined,
      description:
          "Your glucose level is slightly elevated. Keep monitoring regularly.",
    );
  }

  // HIGH  (7.0 – 11.0)
  if (mmol <= 11.0) {
    return const GlucoseStatus(
      statusLabel: "High Sugar",
      statusColor: Color(0xffFF8C42),
      statusIcon: Icons.mood_bad_outlined,
      description: "Your blood glucose level is higher than recommended.",
    );
  }

  // CRITICAL  (> 11.0)
  return const GlucoseStatus(
    statusLabel: "Critical",
    statusColor: Color(0xffE53935),
    statusIcon: Icons.sentiment_very_dissatisfied_outlined,
    description:
        "Your glucose level is critically high. Please monitor carefully.",
  );
}
