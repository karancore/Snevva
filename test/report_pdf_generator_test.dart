import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:snevva/models/health_report.dart';
import 'package:snevva/services/report_pdf_generator.dart';

class MockPathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async {
    return '.';
  }
}

void main() {
  setUp(() {
    PathProviderPlatform.instance = MockPathProviderPlatform();
  });

  test(
    'generates PDF with a large number of parameters without throwing TooManyPagesException',
    () async {
      // Construct a report with 50 parameters to ensure it spans multiple pages
      final parametersJson = List.generate(
        50,
        (index) => {
          'test_name': 'Parameter #$index',
          'value': '${10.0 + index}',
          'unit': 'mg/dL',
          'reference_range': '10.0 - 50.0',
          'status': index % 2 == 0 ? 'Normal' : 'High',
          'severity_score': index % 3,
          'hex_code': index % 2 == 0 ? '#22C55E' : '#EF4444',
          'clinical_meaning':
              'This is a long clinical meaning explanation for parameter #$index to verify line-wrapping and layout stability across multiple pages.',
          'possible_causes': ['Cause A', 'Cause B'],
          'recommended_actions': ['Action X', 'Action Y'],
          'diet_recommendations': ['Eat more veggies'],
          'exercise_recommendations': ['Walk 30 mins'],
        },
      );

      final reportJson = {
        'overall_health_score': 72,
        'overall_status': 'Moderate',
        'doctor_consultation_recommended': true,
        'emergency_attention_needed': false,
        'key_findings': [
          'Finding number one is important.',
          'Finding number two suggests some caution.',
        ],
        'parameters': parametersJson,
        'top_concerns': [
          {
            'rank': 1,
            'parameter': 'Parameter #1',
            'message': 'This is highly elevated and needs attention.',
            'hex_code': '#EF4444',
          },
        ],
        'overall_diet_plan': [
          'Reduce sodium intake.',
          'Drink plenty of water.',
        ],
        'overall_exercise_plan': ['Do cardio 3 times a week.'],
        'recommendations': ['Monitor symptoms weekly.'],
        'patient_summary': 'Summary of the patient health.',
        'ai_disclaimer':
            'This is an AI generated report. Please consult a doctor for official medical advice.',
      };

      final report = HealthReport.fromJson(reportJson);

      // Call generate - should complete without throwing TooManyPagesException
      final file = await ReportPdfGenerator.generate(
        report: report,
        title: 'Full Health Report',
      );

      expect(file, isNotNull);
      expect(await file.exists(), isTrue);

      // Cleanup the generated PDF file
      if (await file.exists()) {
        await file.delete();
      }
    },
  );
}
