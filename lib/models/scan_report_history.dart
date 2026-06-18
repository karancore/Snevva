class ScanReportHistory {
  final String id;
  final String title;
  final DateTime dateTime;
  final String content;
  final String? patientName;
  final String? gender;
  final String? ageRange;

  ScanReportHistory({
    required this.id,
    required this.title,
    required this.dateTime,
    required this.content,
    this.patientName,
    this.gender,
    this.ageRange,
  });

  factory ScanReportHistory.fromJson(Map<String, dynamic> json) {
    return ScanReportHistory(
      id: json['id'],
      title: json['title'],
      dateTime: DateTime.parse(json['dateTime']),
      content: json['content'],
      // Older saved entries won't have these — defaults to null safely.
      patientName: json['patientName'],
      gender: json['gender'],
      ageRange: json['ageRange'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'dateTime': dateTime.toIso8601String(),
    'content': content,
    'patientName': patientName,
    'gender': gender,
    'ageRange': ageRange,
  };
}