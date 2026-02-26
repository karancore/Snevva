class AlertsResponse {
  final List<Alerts> alerts;

  AlertsResponse({required this.alerts});

  factory AlertsResponse.fromJson(Map<String, dynamic> json) {
    final List list = json['data']['pushNotifications'] ?? [];

    return AlertsResponse(alerts: list.map((e) => Alerts.fromJson(e)).toList());
  }
}

class Alerts {
  final String heading;
  final String title;
  final String dataCode;
  final List<String> times;
  final bool isActive;

  Alerts({
    required this.dataCode,
    required this.heading,
    required this.title,
    required this.times,
    required this.isActive,
  });

  factory Alerts.fromJson(Map<String, dynamic> json) {
    return Alerts(
      dataCode: json['dataCode'] ?? '',
      heading: json['heading'] ?? '',
      title: json['title'] ?? '',
      times: List<String>.from(json['time'] ?? []),
      isActive: json['isActive'] ?? false,
    );
  }
}