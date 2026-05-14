import 'package:snevva/models/queryParamViewModels/fetch_health_report_vm.dart';

class RequestedHealthRecord {
  final List<String> serviceType;
  final String timePeriod;
  final DateTime requestedOn;
  final ExportType exportType;
  final String? base64Data; // ← store API response here
  final bool isFailed; // ← flag if API call failed

  RequestedHealthRecord({
    required this.serviceType,
    required this.timePeriod,
    required this.requestedOn,
    required this.exportType,
    this.base64Data,
    this.isFailed = false,
  });
}