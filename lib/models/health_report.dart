import 'package:flutter/material.dart';

class TopConcern {
  final int rank;
  final String parameter;
  final String message;
  final String hexCode;

  TopConcern.fromJson(Map<String, dynamic> j)
    : rank = j['rank'] ?? 0,
      parameter = j['parameter'] ?? '',
      message = j['message'] ?? '',
      hexCode = j['hex_code'] ?? '#EF4444';

  Color get color {
    try {
      final hex = hexCode.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return Colors.red;
    }
  }
}

class MergeMeta {
  final String source;
  final int totalParams;
  final int aiParams;
  final int kbParams;
  final String mergedAt;

  MergeMeta.fromJson(Map<String, dynamic> j)
    : source = j['source'] ?? '',
      totalParams = j['total_params'] ?? 0,
      aiParams = j['ai_params'] ?? 0,
      kbParams = j['kb_params'] ?? 0,
      mergedAt = j['merged_at'] ?? '';

  String get formattedDate {
    try {
      final dt = DateTime.parse(mergedAt).toLocal();
      final dd = dt.day.toString().padLeft(2, '0');
      final mm = dt.month.toString().padLeft(2, '0');
      final yyyy = dt.year;
      final hh = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$dd/$mm/$yyyy  $hh:$min';
    } catch (_) {
      return mergedAt;
    }
  }
}

class ReportParameter {
  final String testName;
  final String value;
  final String unit;
  final String referenceRange;
  final String status;
  final int severityScore;
  final String hexCode;
  final String clinicalMeaning;
  final List<String> possibleCauses;
  final List<String> recommendedActions;
  final List<String> dietRecommendations;
  final List<String> exerciseRecommendations;

  ReportParameter.fromJson(Map<String, dynamic> j)
    : testName = j['test_name'] ?? '',
      value = j['value'] ?? '',
      unit = j['unit'] ?? '',
      referenceRange = j['reference_range'] ?? '',
      status = j['status'] ?? '',
      severityScore = j['severity_score'] ?? 0,
      hexCode = j['hex_code'] ?? '#22C55E',
      clinicalMeaning = j['clinical_meaning'] ?? '',
      possibleCauses = List<String>.from(j['possible_causes'] ?? []),
      recommendedActions = List<String>.from(j['recommended_actions'] ?? []),
      dietRecommendations = List<String>.from(j['diet_recommendations'] ?? []),
      exerciseRecommendations = List<String>.from(
        j['exercise_recommendations'] ?? [],
      );

  Color get statusColor {
    try {
      final hex = hexCode.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }
}

class HealthReport {
  final int overallHealthScore;
  final String overallStatus;
  final bool doctorConsultationRecommended;
  final bool emergencyAttentionNeeded;
  final List<String> keyFindings;
  final List<ReportParameter> parameters;
  final List<TopConcern> topConcerns;
  final List<String> overallDietPlan;
  final List<String> overallExercisePlan;
  final List<String> recommendations;
  final String patientSummary;
  final String aiDisclaimer;
  final MergeMeta? mergeMeta;

  HealthReport.fromJson(Map<String, dynamic> j)
    : overallHealthScore = j['overall_health_score'] ?? 0,
      overallStatus = j['overall_status'] ?? '',
      doctorConsultationRecommended =
          j['doctor_consultation_recommended'] ?? false,
      emergencyAttentionNeeded =
          j['emergency_attention_needed'] ??
          j['urgent_medical_review_needed'] ??
          false,
      keyFindings = List<String>.from(j['key_findings'] ?? []),
      parameters =
          (j['parameters'] as List? ?? [])
              .map((e) => ReportParameter.fromJson(e))
              .toList(),
      topConcerns =
          (j['top_concerns'] as List? ?? [])
              .map((e) => TopConcern.fromJson(e))
              .toList(),
      overallDietPlan = List<String>.from(j['overall_diet_plan'] ?? []),
      overallExercisePlan = List<String>.from(j['overall_exercise_plan'] ?? []),
      recommendations = List<String>.from(j['recommendations'] ?? []),
      patientSummary = j['patient_summary'] ?? '',
      aiDisclaimer = j['ai_disclaimer'] ?? '',
      mergeMeta =
          j['merge_meta'] != null ? MergeMeta.fromJson(j['merge_meta']) : null;
}
