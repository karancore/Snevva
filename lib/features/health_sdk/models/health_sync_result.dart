import 'blood_glucose_record.dart';
import 'blood_pressure_record.dart';
import 'heart_rate_record.dart';
import 'sleep_record.dart';

class HealthSyncResult {
  final HeartRateRecord? latestHeartRate;
  final BloodGlucoseRecord? latestGlucose;
  final BloodPressureRecord? latestBloodPressure;
  final SleepRecord? latestSleep;

  final List<HeartRateRecord> heartRateHistory;
  final List<BloodGlucoseRecord> glucoseHistory;
  final List<BloodPressureRecord> bloodPressureHistory;
  final List<SleepRecord> sleepHistory;

  final DateTime syncedAt;

  /// Non-null when a partial or full failure occurred but some data was recovered.
  final String? errorMessage;

  const HealthSyncResult({
    this.latestHeartRate,
    this.latestGlucose,
    this.latestBloodPressure,
    this.latestSleep,
    this.heartRateHistory = const [],
    this.glucoseHistory = const [],
    this.bloodPressureHistory = const [],
    this.sleepHistory = const [],
    required this.syncedAt,
    this.errorMessage,
  });

  bool get hasAnyData =>
      latestHeartRate != null ||
      latestGlucose != null ||
      latestBloodPressure != null ||
      latestSleep != null;

  /// Total actual sleep time across last 24 hours.
  Duration get totalSleepLast24h {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    return sleepHistory
        .where((s) => s.start.isAfter(cutoff) && s.isActualSleep)
        .fold(Duration.zero, (sum, s) => sum + s.duration);
  }

  static HealthSyncResult empty({String? errorMessage}) => HealthSyncResult(
        syncedAt: DateTime.now(),
        errorMessage: errorMessage,
      );
}