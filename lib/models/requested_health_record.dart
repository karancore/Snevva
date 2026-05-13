class RequestedHealthRecord {
  final List<String> serviceType;
  final String timePeriod;
  final DateTime requestedOn;

  RequestedHealthRecord({
    required this.serviceType,
    required this.timePeriod,
    required this.requestedOn,
  });
}
