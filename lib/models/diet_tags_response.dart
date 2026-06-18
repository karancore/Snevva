class DietTagsResponse {
  final bool? status;
  final String? statusType;
  final String? message;
  final List<DietTagData>? data;

  DietTagsResponse({this.status, this.statusType, this.message, this.data});

  factory DietTagsResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];

    return DietTagsResponse(
      status: json['status'],
      statusType: json['statusType']?.toString(),
      message: json['message']?.toString(),
      data:
          rawData is List
              ? List<DietTagData>.from(
                rawData.whereType<Map>().map(
                  (x) => DietTagData.fromJson(Map<String, dynamic>.from(x)),
                ),
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
    final rawMealPlan = json['MealPlan'];
    final rawTags = json['Tags'];

    return DietTagData(
      id: _asInt(json['Id']),
      dataCode: json['DataCode']?.toString(),
      thumbnailMedia: _extractMediaUrl(json['ThumbnailMedia']),
      heading: json['Heading']?.toString(),
      title: json['Title']?.toString(),
      shortDescription: json['ShortDescription']?.toString(),
      mealPlan:
          rawMealPlan is List
              ? List<MealPlanItem>.from(
                rawMealPlan.whereType<Map>().map(
                  (x) => MealPlanItem.fromJson(Map<String, dynamic>.from(x)),
                ),
              )
              : <MealPlanItem>[],
      tags:
          rawTags is List
              ? rawTags.map((tag) => tag.toString()).toList()
              : <String>[],
      isActive: json['IsActive'] is bool ? json['IsActive'] : null,
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
      day: _asInt(json['Day']) ?? 0,
      breakFast: json['BreakFast']?.toString() ?? '',
      breakFastMedia: _extractMediaUrl(json['BreakFastMedia']),
      lunch: json['Lunch']?.toString() ?? '',
      lunchMedia: _extractMediaUrl(json['LunchMedia']),
      evening: json['Evening']?.toString() ?? '',
      eveningMedia: _extractMediaUrl(json['EveningMedia']),
      dinner: json['Dinner']?.toString() ?? '',
      dinnerMedia: _extractMediaUrl(json['DinnerMedia']),
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

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

String? _extractMediaUrl(dynamic media) {
  if (media == null) return null;
  if (media is String) return _normalizeMediaUrl(media);
  if (media is Map) {
    final mediaMap = Map<dynamic, dynamic>.from(media);
    return _normalizeMediaUrl(
      mediaMap['CdnUrl'] ??
          mediaMap['cdnUrl'] ??
          mediaMap['Url'] ??
          mediaMap['url'],
    );
  }
  return null;
}

String? _normalizeMediaUrl(dynamic value) {
  final url = value?.toString().trim() ?? '';
  if (url.isEmpty) return null;
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  if (url.startsWith('//')) return 'https:$url';
  return 'https://$url';
}
