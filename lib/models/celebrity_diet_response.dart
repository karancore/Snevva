class CelebrityResponse {
  final bool status;
  final String statusType;
  final String message;
  final List<CelebrityDiet> data;

  CelebrityResponse({
    required this.status,
    required this.statusType,
    required this.message,
    required this.data,
  });

  factory CelebrityResponse.fromJson(Map<String, dynamic> json) {
    return CelebrityResponse(
      status: json['status'] ?? false,
      statusType: json['statusType'] ?? '',
      message: json['message'] ?? '',
      data: (json['data'] as List<dynamic>? ?? [])
          .map((e) => CelebrityDiet.fromJson(e))
          .toList(),
    );
  }
}

class CelebrityDiet {
  final int id;
  final String heading;
  final String title;
  final String shortDescription;
  final String thumbnailUrl;
  final List<MealPlanItem> mealPlan;

  CelebrityDiet({
    required this.id,
    required this.heading,
    required this.title,
    required this.shortDescription,
    required this.thumbnailUrl,
    required this.mealPlan,
  });

  factory CelebrityDiet.fromJson(Map<String, dynamic> json) {
    return CelebrityDiet(
      id: json['Id'] ?? 0,
      heading: json['Heading'] ?? '',
      title: json['Title'] ?? '',
      shortDescription: json['ShortDescription'] ?? '',
      thumbnailUrl: json['ThumbnailMedia']?['CdnUrl'] ?? '',
      mealPlan: (json['MealPlan'] as List<dynamic>? ?? [])
          .map((e) => MealPlanItem.fromJson(e))
          .toList(),
    );
  }
}

class MealPlanItem {
  final int day;
  final String breakFast;
  final String breakFastMedia;
  final String lunch;
  final String lunchMedia;
  final String evening;
  final String eveningMedia;
  final String dinner;
  final String dinnerMedia;

  MealPlanItem({
    required this.day,
    required this.breakFast,
    required this.breakFastMedia,
    required this.lunch,
    required this.lunchMedia,
    required this.evening,
    required this.eveningMedia,
    required this.dinner,
    required this.dinnerMedia,
  });

  factory MealPlanItem.fromJson(Map<String, dynamic> json) {
    return MealPlanItem(
      day: json['Day'] ?? 0,
      breakFast: json['BreakFast'] ?? '',
      breakFastMedia: json['BreakFastMedia']?['CdnUrl'] ?? '',
      lunch: json['Lunch'] ?? '',
      lunchMedia: json['LunchMedia']?['CdnUrl'] ?? '',
      evening: json['Evening'] ?? '',
      eveningMedia: json['EveningMedia']?['CdnUrl'] ?? '',
      dinner: json['Dinner'] ?? '',
      dinnerMedia: json['DinnerMedia']?['CdnUrl'] ?? '',
    );
  }
}
