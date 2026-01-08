class DietTagsResponse {
  final bool? status;
  final String? statusType;
  final String? message;
  final List<DietTagData>? data;

  DietTagsResponse({this.status, this.statusType, this.message, this.data});

  factory DietTagsResponse.fromJson(Map<String, dynamic> json) {
    return DietTagsResponse(
      status: json['status'],
      statusType: json['statusType'],
      message: json['message'],
      data:
          json['data'] != null
              ? List<DietTagData>.from(
                json['data'].map((x) => DietTagData.fromJson(x)),
              )
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "status": status,
      "statusType": statusType,
      "message": message,
      "data": data?.map((x) => x.toJson()).toList(),
    };
  }
}

class DietTagData {
  final int? id;
  final String? dataCode;
  final String? thumbnailMedia;
  final String? heading;
  final String? title;
  final String? shortDescription;
  final List<MealPlanItem> mealPlan;
  final List<String> tags;
  final bool? isActive;

  DietTagData({
    this.id,
    this.dataCode,
    this.thumbnailMedia,
    this.heading,
    this.title,
    this.shortDescription,
    required this.mealPlan,
    required this.tags,
    this.isActive,
  });

  factory DietTagData.fromJson(Map<String, dynamic> json) {
    return DietTagData(
      id: json['Id'],
      dataCode: json['DataCode'],
      thumbnailMedia: json['ThumbnailMedia'],
      heading: json['Heading'],
      title: json['Title'],
      shortDescription: json['ShortDescription'],
      mealPlan: List<MealPlanItem>.from(
        json['MealPlan'].map((x) => MealPlanItem.fromJson(x)),
      ),
      tags: List<String>.from(json['Tags']),
      isActive: json['IsActive'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "Id": id,
      "DataCode": dataCode,
      "ThumbnailMedia": thumbnailMedia,
      "Heading": heading,
      "Title": title,
      "ShortDescription": shortDescription,
      "MealPlan": mealPlan.map((x) => x.toJson()).toList(),
      "Tags": tags,
      "IsActive": isActive,
    };
  }
}

class MealPlanItem {
  final int day;
  final String breakFast;
  final String? breakFastMedia;
  final String lunch;
  final String? lunchMedia;
  final String evening;
  final String? eveningMedia;
  final String dinner;
  final String? dinnerMedia;

  MealPlanItem({
    required this.day,
    required this.breakFast,
    this.breakFastMedia,
    required this.lunch,
    this.lunchMedia,
    required this.evening,
    this.eveningMedia,
    required this.dinner,
    this.dinnerMedia,
  });

  factory MealPlanItem.fromJson(Map<String, dynamic> json) {
    return MealPlanItem(
      day: json['Day'],
      breakFast: json['BreakFast'],
      breakFastMedia: json['BreakFastMedia'],
      lunch: json['Lunch'],
      lunchMedia: json['LunchMedia'],
      evening: json['Evening'],
      eveningMedia: json['EveningMedia'],
      dinner: json['Dinner'],
      dinnerMedia: json['DinnerMedia'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "Day": day,
      "BreakFast": breakFast,
      "BreakFastMedia": breakFastMedia,
      "Lunch": lunch,
      "LunchMedia": lunchMedia,
      "Evening": evening,
      "EveningMedia": eveningMedia,
      "Dinner": dinner,
      "DinnerMedia": dinnerMedia,
    };
  }
}
