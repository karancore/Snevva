class ScanReportHistory {
  final String id;
  final String title;
  final DateTime dateTime;
  final String content;

  ScanReportHistory({
    required this.id,
    required this.title,
    required this.dateTime,
    required this.content,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'dateTime': dateTime.toIso8601String(),
    'content': content,
  };

  factory ScanReportHistory.fromJson(Map<String, dynamic> json) =>
      ScanReportHistory(
        id: json['id'] as String,
        title: json['title'] as String,
        dateTime: DateTime.parse(json['dateTime'] as String),
        content: json['content'] as String,
      );
}
