import 'package:flutter/material.dart';

class BpmStatus {
  final String label;
  final Color color;

  BpmStatus({required this.label, required this.color});
}

BpmStatus getBpmStatus(int bpm) {
  // ⚫ Invalid
  if (bpm <= 0) {
    return BpmStatus(label: "Enter BPM", color: Colors.grey);
  }

  // 🔴 Medical Concern
  if (bpm >= 180) {
    return BpmStatus(label: "Medical Concern", color: Colors.red);
  }

  // 🟠 Heavy Exertion / Anxiety
  if (bpm >= 140) {
    return BpmStatus(label: "Heavy Exertion", color: Colors.deepOrange);
  }

  // 🟡 Exercise / Stress
  if (bpm >= 100) {
    return BpmStatus(label: "Exercise / Stress", color: Colors.amber);
  }

  // 🟢 Normal Adult
  if (bpm >= 60) {
    return BpmStatus(label: "Normal", color: Colors.green);
  }

  // 🔵 Athlete / Resting
  return BpmStatus(label: "Athlete / Resting", color: Colors.blue);
}
