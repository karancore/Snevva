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

GlucoseStatus getGlucoseStatus(double mgdl) =>
    getGlucoseStatusForType(mgdl, 'Fasting');

// Returns status using clinically correct ranges per measurement type.
// Fasting  : 8+ hours without food (ADA standard)
// Post Meal: 1-2 hours after eating
// Random   : any time of day
GlucoseStatus getGlucoseStatusForType(double mgdl, String type) {
  switch (type) {
    case 'Post Meal':
      return _postMealStatus(mgdl);
    case 'Random':
      return _randomStatus(mgdl);
    case 'Fasting':
    default:
      return _fastingStatus(mgdl);
  }
}

GlucoseStatus _fastingStatus(double mgdl) {
  if (mgdl < 70) {
    return const GlucoseStatus(
      statusLabel: "Low Sugar",
      statusColor: Color(0xffFF6B6B),
      statusIcon: Icons.sentiment_dissatisfied_outlined,
      description: "Fasting glucose is too low. Consider eating something.",
    );
  }
  if (mgdl <= 99) {
    return const GlucoseStatus(
      statusLabel: "Healthy",
      statusColor: Color(0xff2DBF5F),
      statusIcon: Icons.sentiment_satisfied_alt_outlined,
      description: "Fasting glucose is within the normal range (70–99 mg/dL).",
    );
  }
  if (mgdl <= 125) {
    return const GlucoseStatus(
      statusLabel: "Pre-Diabetic",
      statusColor: Color(0xffF5A623),
      statusIcon: Icons.sentiment_neutral_outlined,
      description:
          "Fasting glucose is slightly elevated (100–125 mg/dL). Monitor regularly.",
    );
  }
  if (mgdl <= 199) {
    return const GlucoseStatus(
      statusLabel: "High Sugar",
      statusColor: Color(0xffFF8C42),
      statusIcon: Icons.mood_bad_outlined,
      description:
          "Fasting glucose is high (126–199 mg/dL). Consult your doctor.",
    );
  }
  return const GlucoseStatus(
    statusLabel: "Critical",
    statusColor: Color(0xffE53935),
    statusIcon: Icons.sentiment_very_dissatisfied_outlined,
    description:
        "Fasting glucose is critically high (≥200 mg/dL). Seek medical advice.",
  );
}

GlucoseStatus _postMealStatus(double mgdl) {
  if (mgdl < 70) {
    return const GlucoseStatus(
      statusLabel: "Low Sugar",
      statusColor: Color(0xffFF6B6B),
      statusIcon: Icons.sentiment_dissatisfied_outlined,
      description:
          "Post-meal glucose is too low. You may need to eat more carbs.",
    );
  }
  if (mgdl <= 139) {
    return const GlucoseStatus(
      statusLabel: "Healthy",
      statusColor: Color(0xff2DBF5F),
      statusIcon: Icons.sentiment_satisfied_alt_outlined,
      description:
          "Post-meal glucose is normal (70–139 mg/dL). Great response!",
    );
  }
  if (mgdl <= 179) {
    return const GlucoseStatus(
      statusLabel: "Watch Out",
      statusColor: Color(0xffF5A623),
      statusIcon: Icons.sentiment_neutral_outlined,
      description:
          "Post-meal glucose is slightly elevated (140–179 mg/dL). Monitor your diet.",
    );
  }
  if (mgdl <= 199) {
    return const GlucoseStatus(
      statusLabel: "High Sugar",
      statusColor: Color(0xffFF8C42),
      statusIcon: Icons.mood_bad_outlined,
      description:
          "Post-meal glucose is high (180–199 mg/dL). Review your meal choices.",
    );
  }
  return const GlucoseStatus(
    statusLabel: "Critical",
    statusColor: Color(0xffE53935),
    statusIcon: Icons.sentiment_very_dissatisfied_outlined,
    description:
        "Post-meal glucose is critically high (≥200 mg/dL). Consult your doctor.",
  );
}

GlucoseStatus _randomStatus(double mgdl) {
  if (mgdl < 70) {
    return const GlucoseStatus(
      statusLabel: "Low Sugar",
      statusColor: Color(0xffFF6B6B),
      statusIcon: Icons.sentiment_dissatisfied_outlined,
      description:
          "Blood glucose is too low. Have a fast-acting carbohydrate immediately.",
    );
  }
  if (mgdl <= 139) {
    return const GlucoseStatus(
      statusLabel: "Normal",
      statusColor: Color(0xff2DBF5F),
      statusIcon: Icons.sentiment_satisfied_alt_outlined,
      description: "Random glucose is within the normal range (70–139 mg/dL).",
    );
  }
  if (mgdl <= 199) {
    return const GlucoseStatus(
      statusLabel: "Elevated",
      statusColor: Color(0xffF5A623),
      statusIcon: Icons.sentiment_neutral_outlined,
      description:
          "Random glucose is elevated (140–199 mg/dL). Consider further testing.",
    );
  }
  return const GlucoseStatus(
    statusLabel: "High",
    statusColor: Color(0xffE53935),
    statusIcon: Icons.mood_bad_outlined,
    description:
        "Random glucose is high (≥200 mg/dL). Consult your doctor soon.",
  );
}