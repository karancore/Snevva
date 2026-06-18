import 'dart:convert';

class GlucoseReading {
  final String glucoseLevel; // in mmol/L
  final String time; // ISO8601 string
  final String type; // "Fasting" | "Post Meal" | "Custom"

  const GlucoseReading({
    required this.glucoseLevel,
    required this.time,
    required this.type,
  });

  Map<String, dynamic> toMap() => {
    'glucoseLevel': glucoseLevel,
    'time': time,
    'type': type,
  };

  factory GlucoseReading.fromMap(Map<String, dynamic> map) => GlucoseReading(
    glucoseLevel: map['glucoseLevel'] ?? '',
    time: map['time'] ?? '',
    type: map['type'] ?? 'Custom',
  );

  String toJson() => json.encode(toMap());

  factory GlucoseReading.fromJson(String source) =>
      GlucoseReading.fromMap(json.decode(source));
}
