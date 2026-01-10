class DaySymptoms {
  final DateTime date;           // normalized date (yyyy-mm-dd)
  final List<String> symptoms;   // list of symptoms
  final String note;             // optional note

  DaySymptoms({
    required DateTime date,
    required this.symptoms,
    required this.note,
  }) : date = DateTime(date.year, date.month, date.day);

  /// 🔹 Convert to JSON (for DB / API)
  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'symptoms': symptoms,
        'note': note,
      };

  /// 🔹 Create from JSON
  factory DaySymptoms.fromJson(Map<String, dynamic> json) {
    final parsedDate = DateTime.parse(json['date']);

    return DaySymptoms(
      date: DateTime(
        parsedDate.year,
        parsedDate.month,
        parsedDate.day,
      ),
      symptoms: List<String>.from(json['symptoms'] ?? []),
      note: json['note'] ?? '',
    );
  }

  /// 🔹 Helpful for debugging
  @override
  String toString() {
    return 'DaySymptoms(date: $date, symptoms: $symptoms, note: $note)';
  }
}
