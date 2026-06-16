import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

import '../models/blood_glucose_record.dart';
import '../models/blood_pressure_record.dart';
import '../models/health_sync_result.dart';
import '../models/heart_rate_record.dart';
import '../models/sleep_record.dart';
import '../services/health_service.dart';

/// Maps raw [HealthDataPoint]s from the SDK into strongly-typed domain models
/// and assembles [HealthSyncResult].
///
/// All data-access errors are caught here so callers always receive a result
/// (possibly with an [HealthSyncResult.errorMessage]) rather than an exception.
class HealthRepository {
  HealthRepository._();

  // ─── Public API ──────────────────────────────────────────────────────────

  /// Convenience: fetch all vitals + sleep for the last [days] days.
  ///
  /// Vitals and sleep are fetched in parallel to reduce latency.
  static Future<HealthSyncResult> syncLastDays({int days = 30}) async {
    final end = DateTime.now();
    final start = end.subtract(Duration(days: days));

    try {
      // Parallel fetch — vitals and sleep are independent.
      final results = await Future.wait([
        HealthService.fetchAllVitals(start: start, end: end),
        HealthService.fetchSleep(start: start, end: end),
      ]);

      final vitalPoints = results[0];
      final sleepPoints = results[1];

      final hrPoints = vitalPoints
          .where((p) => p.type == HealthDataType.HEART_RATE)
          .toList();
      final bgPoints = vitalPoints
          .where((p) => p.type == HealthDataType.BLOOD_GLUCOSE)
          .toList();
      final sysPoints = vitalPoints
          .where((p) => p.type == HealthDataType.BLOOD_PRESSURE_SYSTOLIC)
          .toList();
      final diaPoints = vitalPoints
          .where((p) => p.type == HealthDataType.BLOOD_PRESSURE_DIASTOLIC)
          .toList();

      final hrRecords = _mapHeartRate(hrPoints);
      final bgRecords = _mapBloodGlucose(bgPoints);
      final bpRecords = _mapBloodPressure(sysPoints, diaPoints);
      final sleepRecords = _mapSleep(sleepPoints);

      // Sort newest-first throughout.
      hrRecords.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
      bgRecords.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
      bpRecords.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
      sleepRecords.sort((a, b) => b.start.compareTo(a.start));

      debugPrint(
          '[HealthRepository] sync: hr=${hrRecords.length} bg=${bgRecords.length} '
          'bp=${bpRecords.length} sleep=${sleepRecords.length}');

      return HealthSyncResult(
        latestHeartRate: hrRecords.isNotEmpty ? hrRecords.first : null,
        latestGlucose: bgRecords.isNotEmpty ? bgRecords.first : null,
        latestBloodPressure: bpRecords.isNotEmpty ? bpRecords.first : null,
        latestSleep: sleepRecords.isNotEmpty ? sleepRecords.first : null,
        heartRateHistory: hrRecords,
        glucoseHistory: bgRecords,
        bloodPressureHistory: bpRecords,
        sleepHistory: sleepRecords,
        syncedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[HealthRepository] syncLastDays error: $e');
      return HealthSyncResult.empty(
        errorMessage: 'Sync failed. Please try again.',
      );
    }
  }

  // ─── Per-type fetchers ───────────────────────────────────────────────────

  static Future<HeartRateRecord?> latestHeartRate() async {
    final end = DateTime.now();
    final start = end.subtract(const Duration(hours: 24));
    final points = await HealthService.fetchHeartRate(start: start, end: end);
    if (points.isEmpty) return null;
    points.sort((a, b) => b.dateTo.compareTo(a.dateTo));
    return _toHeartRate(points.first);
  }

  static Future<BloodGlucoseRecord?> latestBloodGlucose() async {
    final end = DateTime.now();
    final start = end.subtract(const Duration(days: 7));
    final points =
        await HealthService.fetchBloodGlucose(start: start, end: end);
    if (points.isEmpty) return null;
    points.sort((a, b) => b.dateTo.compareTo(a.dateTo));
    return _toBloodGlucose(points.first);
  }

  static Future<BloodPressureRecord?> latestBloodPressure() async {
    final end = DateTime.now();
    final start = end.subtract(const Duration(days: 7));
    final points =
        await HealthService.fetchBloodPressure(start: start, end: end);
    final sys = points
        .where((p) => p.type == HealthDataType.BLOOD_PRESSURE_SYSTOLIC)
        .toList();
    final dia = points
        .where((p) => p.type == HealthDataType.BLOOD_PRESSURE_DIASTOLIC)
        .toList();
    final records = _mapBloodPressure(sys, dia);
    if (records.isEmpty) return null;
    records.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return records.first;
  }

  static Future<SleepRecord?> latestSleep() async {
    final end = DateTime.now();
    final start = end.subtract(const Duration(days: 2));
    final points = await HealthService.fetchSleep(start: start, end: end);
    final records = _mapSleep(points);
    if (records.isEmpty) return null;
    records.sort((a, b) => b.start.compareTo(a.start));
    return records.first;
  }

  // ─── Mappers ─────────────────────────────────────────────────────────────

  static List<HeartRateRecord> _mapHeartRate(List<HealthDataPoint> points) =>
      points.map(_toHeartRate).whereType<HeartRateRecord>().toList();

  static HeartRateRecord? _toHeartRate(HealthDataPoint p) {
    final value = p.value;
    if (value is! NumericHealthValue) return null;
    final bpm = value.numericValue.toDouble();
    // Discard physiologically impossible readings.
    if (bpm <= 0 || bpm > 300) return null;
    return HeartRateRecord(
      beatsPerMinute: bpm,
      recordedAt: p.dateTo,
      sourceName: p.sourceName,
    );
  }

  static List<BloodGlucoseRecord> _mapBloodGlucose(
          List<HealthDataPoint> points) =>
      points.map(_toBloodGlucose).whereType<BloodGlucoseRecord>().toList();

  static BloodGlucoseRecord? _toBloodGlucose(HealthDataPoint p) {
    final value = p.value;
    if (value is! NumericHealthValue) return null;
    final mmol = value.numericValue.toDouble();
    if (mmol <= 0) return null;
    return BloodGlucoseRecord(
      mmolPerL: mmol,
      recordedAt: p.dateTo,
      sourceName: p.sourceName,
    );
  }

  /// Pairs systolic and diastolic points by matching their timestamps within a
  /// 60-second tolerance — BP readings always come as a pair from the device.
  static List<BloodPressureRecord> _mapBloodPressure(
    List<HealthDataPoint> sysPoints,
    List<HealthDataPoint> diaPoints,
  ) {
    if (sysPoints.isEmpty || diaPoints.isEmpty) return [];

    final records = <BloodPressureRecord>[];

    for (final sys in sysPoints) {
      final sysVal = sys.value;
      if (sysVal is! NumericHealthValue) continue;
      final systolic = sysVal.numericValue.toDouble();
      if (systolic <= 0) continue;

      // Find the nearest diastolic within 60 s.
      HealthDataPoint? pair;
      Duration bestDiff = const Duration(seconds: 61);

      for (final dia in diaPoints) {
        final diff = (sys.dateTo.difference(dia.dateTo)).abs();
        if (diff < bestDiff) {
          bestDiff = diff;
          pair = dia;
        }
      }

      if (pair == null) continue;
      final diaVal = pair.value;
      if (diaVal is! NumericHealthValue) continue;
      final diastolic = diaVal.numericValue.toDouble();
      if (diastolic <= 0) continue;

      records.add(BloodPressureRecord(
        systolic: systolic,
        diastolic: diastolic,
        recordedAt: sys.dateTo,
        sourceName: sys.sourceName,
      ));
    }

    return records;
  }

  static List<SleepRecord> _mapSleep(List<HealthDataPoint> points) {
    final records = <SleepRecord>[];

    for (final p in points) {
      final start = p.dateFrom;
      final end = p.dateTo;

      // Skip zero-duration or negative-duration records.
      if (!end.isAfter(start)) continue;

      final stage = _sleepStageFromType(p.type);
      records.add(SleepRecord(
        start: start,
        end: end,
        stage: stage,
        sourceName: p.sourceName,
      ));
    }

    return records;
  }

  static SleepStage _sleepStageFromType(HealthDataType type) {
    return switch (type) {
      HealthDataType.SLEEP_IN_BED => SleepStage.inBed,
      HealthDataType.SLEEP_ASLEEP => SleepStage.asleep,
      HealthDataType.SLEEP_AWAKE ||
      HealthDataType.SLEEP_AWAKE_IN_BED =>
        SleepStage.awake,
      HealthDataType.SLEEP_DEEP => SleepStage.deep,
      HealthDataType.SLEEP_LIGHT => SleepStage.light,
      HealthDataType.SLEEP_REM => SleepStage.rem,
      HealthDataType.SLEEP_SESSION => SleepStage.session,
      _ => SleepStage.unknown,
    };
  }
}