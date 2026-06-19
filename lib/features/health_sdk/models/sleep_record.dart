import 'package:flutter/material.dart';

enum SleepStage {
  inBed,    // iOS: SLEEP_IN_BED
  asleep,   // both: SLEEP_ASLEEP / HC stage SLEEPING
  awake,    // both: SLEEP_AWAKE
  light,    // iOS: SLEEP_ASLEEP_CORE (light/core)
  deep,     // iOS: SLEEP_ASLEEP_DEEP
  rem,      // iOS: SLEEP_ASLEEP_REM
  session,  // Android HC: SLEEP_SESSION (whole night)
  unknown,
}

class SleepRecord {
  final DateTime start;
  final DateTime end;
  final SleepStage stage;
  final String? sourceName;

  const SleepRecord({
    required this.start,
    required this.end,
    required this.stage,
    this.sourceName,
  });

  Duration get duration => end.difference(start);

  bool get isActualSleep =>
      stage == SleepStage.asleep ||
      stage == SleepStage.light ||
      stage == SleepStage.deep ||
      stage == SleepStage.rem ||
      stage == SleepStage.session;

  String get stageLabel => switch (stage) {
        SleepStage.inBed => 'In Bed',
        SleepStage.asleep => 'Asleep',
        SleepStage.awake => 'Awake',
        SleepStage.light => 'Light',
        SleepStage.deep => 'Deep',
        SleepStage.rem => 'REM',
        SleepStage.session => 'Sleep Session',
        SleepStage.unknown => 'Unknown',
      };

  Color get stageColor => switch (stage) {
        SleepStage.deep => const Color(0xFF4A90D9),
        SleepStage.rem => const Color(0xFF9B59B6),
        SleepStage.light || SleepStage.asleep || SleepStage.session =>
          const Color(0xFF8CDC52),
        SleepStage.awake => const Color(0xFFFFD900),
        _ => const Color(0xFF878787),
      };

  String get formattedDuration {
    final h = duration.inHours;
    final m = duration.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  String toString() =>
      'SleepRecord($stageLabel, ${start.toIso8601String()}–${end.toIso8601String()}, src=$sourceName)';
}