class MoodModel {
  final int id;
  final String mood;
  final int day;
  final int month;
  final int year;
  final String time;

  MoodModel({
    required this.id,
    required this.mood,
    required this.day,
    required this.month,
    required this.year,
    required this.time,
  });

  /// 🔹 FROM JSON
  factory MoodModel.fromJson(Map<String, dynamic> json) {
    return MoodModel(
      id: json['Id'] ?? 0,
      mood: json['Mood'] ?? '',
      day: json['Day'] ?? 0,
      month: json['Month'] ?? 0,
      year: json['Year'] ?? 0,
      time: json['Time'] ?? '',
    );
  }

  /// 🔹 TO JSON
  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Mood': mood,
      'Day': day,
      'Month': month,
      'Year': year,
      'Time': time,
    };
  }

  /// 🔹 STRING REPRESENTATION
  @override
  String toString() {
    return 'MoodModel(Id: $id, Mood: $mood, Date: $day/$month/$year, Time: $time)';
  }

  /// 🔹 EXTRA: formatted date
  String get formattedDate {
    return '$day/${month.toString().padLeft(2, '0')}/$year';
  }

  /// 🔹 EXTRA: full readable string
  String get displayText {
    return '$mood on $formattedDate at $time';
  }

  /// 🔹 COPY WITH (useful for updates)
  MoodModel copyWith({
    int? id,
    String? mood,
    int? day,
    int? month,
    int? year,
    String? time,
  }) {
    return MoodModel(
      id: id ?? this.id,
      mood: mood ?? this.mood,
      day: day ?? this.day,
      month: month ?? this.month,
      year: year ?? this.year,
      time: time ?? this.time,
    );
  }
}
