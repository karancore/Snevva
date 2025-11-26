class ReminderModel {
  String? title;
  String? description;
  String? category;
  List<String> medicineName;
  int? startDay;
  int? startMonth;
  int? startYear;
  List<String> remindTime;
  int? remindFrequencyHour;
  int? remindFrequencyCount;
  bool? enablePushNotification;
  bool? isActive;

  ReminderModel({
    this.title,
    this.description,
    this.category,
    this.medicineName = const [],
    this.startDay,
    this.startMonth,
    this.startYear,
    this.remindTime = const [],
    this.remindFrequencyHour,
    this.remindFrequencyCount,
    this.enablePushNotification,
    this.isActive,
  });

  /// Create object from JSON
  factory ReminderModel.fromJson(Map<String, dynamic> json) {
    return ReminderModel(
      title: json['title'],
      description: json['description'],
      category: json['category'],
      medicineName: List<String>.from(json['medicineName'] ?? []),
      startDay: json['startDay'],
      startMonth: json['startMonth'],
      startYear: json['startYear'],
      remindTime: List<String>.from(json['remindTime'] ?? []),
      remindFrequencyHour: json['remindFrequencyHour'],
      remindFrequencyCount: json['remindFrequencyCount'],
      enablePushNotification: json['enablePushNotification'],
      isActive: json['isActive'],
    );
  }

  /// Convert object to JSON
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'medicineName': medicineName,
      'startDay': startDay,
      'startMonth': startMonth,
      'startYear': startYear,
      'remindTime': remindTime,
      'remindFrequencyHour': remindFrequencyHour,
      'remindFrequencyCount': remindFrequencyCount,
      'enablePushNotification': enablePushNotification,
      'isActive': isActive,
    };
  }
}
