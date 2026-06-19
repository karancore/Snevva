import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

/// Low-level wrapper around the `health` package.
///
/// Responsibilities:
///   - One-time SDK configuration.
///   - Fetching raw [HealthDataPoint] lists by type and time window.
///   - No domain mapping — that belongs in HealthRepository.
class HealthService {
  HealthService._();

  static final Health _health = Health();
  static bool _configured = false;

  // ─── Initialisation ──────────────────────────────────────────────────────

  /// Must be called once before any data fetch (call from main or binding).
  static Future<void> configure() async {
    if (_configured) return;
    try {
      await _health.configure();
      _configured = true;
      debugPrint('[HealthService] SDK configured.');
    } catch (e) {
      debugPrint('[HealthService] configure() error: $e');
    }
  }

  // ─── Heart Rate ──────────────────────────────────────────────────────────

  static Future<List<HealthDataPoint>> fetchHeartRate({
    required DateTime start,
    required DateTime end,
  }) =>
      _fetch(types: [HealthDataType.HEART_RATE], start: start, end: end);

  // ─── Blood Glucose ───────────────────────────────────────────────────────

  static Future<List<HealthDataPoint>> fetchBloodGlucose({
    required DateTime start,
    required DateTime end,
  }) =>
      _fetch(types: [HealthDataType.BLOOD_GLUCOSE], start: start, end: end);

  // ─── Blood Pressure ──────────────────────────────────────────────────────

  /// Fetches systolic AND diastolic points in a single call.
  /// The repository pairs them by timestamp.
  static Future<List<HealthDataPoint>> fetchBloodPressure({
    required DateTime start,
    required DateTime end,
  }) =>
      _fetch(
        types: [
          HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
          HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
        ],
        start: start,
        end: end,
      );

  // ─── Sleep ───────────────────────────────────────────────────────────────

  /// Sleep types differ by platform:
  ///   Android (Health Connect): SLEEP_SESSION is the whole-night container;
  ///     DEEP / LIGHT / REM are stage sub-records.
  ///   iOS (HealthKit): SLEEP_IN_BED is the legacy bucket; iOS 16+ adds
  ///     DEEP / LIGHT / REM inside SLEEP_ASLEEP.
  static Future<List<HealthDataPoint>> fetchSleep({
    required DateTime start,
    required DateTime end,
  }) {
    final types = Platform.isAndroid
        ? [
            HealthDataType.SLEEP_SESSION,
            HealthDataType.SLEEP_ASLEEP,
            HealthDataType.SLEEP_AWAKE,
            HealthDataType.SLEEP_DEEP,
            HealthDataType.SLEEP_LIGHT,
            HealthDataType.SLEEP_REM,
          ]
        : [
            HealthDataType.SLEEP_IN_BED,
            HealthDataType.SLEEP_ASLEEP,
            HealthDataType.SLEEP_AWAKE,
            HealthDataType.SLEEP_DEEP,
            HealthDataType.SLEEP_LIGHT,
            HealthDataType.SLEEP_REM,
          ];
    return _fetch(types: types, start: start, end: end);
  }

  // ─── Batch fetch ─────────────────────────────────────────────────────────

  /// Fetch all four vital types in one call for efficiency.
  static Future<List<HealthDataPoint>> fetchAllVitals({
    required DateTime start,
    required DateTime end,
  }) =>
      _fetch(
        types: [
          HealthDataType.HEART_RATE,
          HealthDataType.BLOOD_GLUCOSE,
          HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
          HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
        ],
        start: start,
        end: end,
      );

  // ─── Private ─────────────────────────────────────────────────────────────

  static Future<List<HealthDataPoint>> _fetch({
    required List<HealthDataType> types,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final points = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: types,
      );
      // removeDuplicates is an instance method in health v13.3.1, not static.
      return _health.removeDuplicates(points);
    } catch (e) {
      debugPrint('[HealthService] fetch $types error: $e');
      return [];
    }
  }
}