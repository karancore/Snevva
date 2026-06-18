class AlertsResponse {
  final List<Alerts> alerts;

  AlertsResponse({required this.alerts});

  factory AlertsResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final List list =
        data is Map<String, dynamic>
            ? (data['pushNotifications'] ?? data['PushNotifications'] ?? [])
                as List
            : [];

    return AlertsResponse(alerts: list.map((e) => Alerts.fromJson(e)).toList());
  }
}

class Alerts {
  final String heading;
  final String title;
  final String dataCode;
  final String id;
  final List<String> times;
  final bool isActive;

  Alerts({
    required this.id,
    required this.dataCode,
    required this.heading,
    required this.title,
    required this.times,
    required this.isActive,
  });

  factory Alerts.fromJson(Map<String, dynamic> json) {
    return Alerts(
      id: (json['id'] ?? json['Id'] ?? '').toString(),

      dataCode: (json['dataCode'] ?? json['DataCode'] ?? '').toString(),

      heading: (json['heading'] ?? json['Heading'] ?? '').toString(),
      title: (json['title'] ?? json['Title'] ?? '').toString(),
      times:
          ((json['time'] ?? json['Time'] ?? []) as List)
              .map((time) => time.toString())
              .toList(),
      isActive: json['isActive'] ?? json['IsActive'] ?? false,
    );
  }
}
