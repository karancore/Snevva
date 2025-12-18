class TipsResponse {
  final bool status;
  final String statusType;
  final String message;
  final List<TipData> data;

  TipsResponse({
    required this.status,
    required this.statusType,
    required this.message,
    required this.data,
  });

  factory TipsResponse.fromJson(Map<String, dynamic> json) {
    return TipsResponse(
      status: json['status'] ?? false,
      statusType: json['statusType'] ?? '',
      message: json['message'] ?? '',
      data: (json['data'] as List<dynamic>? ?? [])
          .map((e) => TipData.fromJson(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'statusType': statusType,
      'message': message,
      'data': data.map((e) => e.toJson()).toList(),
    };
  }
}

class TipData {
  final int id;
  final String dataCode;
  final ThumbnailMedia? thumbnailMedia;
  final String heading;
  final String title;
  final String shortDescription;
  final List<String> steps;
  final List<String> tags;
  final bool isActive;

  TipData({
    required this.id,
    required this.dataCode,
    this.thumbnailMedia,
    required this.heading,
    required this.title,
    required this.shortDescription,
    required this.steps,
    required this.tags,
    required this.isActive,
  });

  factory TipData.fromJson(Map<String, dynamic> json) {
    return TipData(
      id: json['Id'] ?? 0,
      dataCode: json['DataCode'] ?? '',
      thumbnailMedia: json['ThumbnailMedia'] != null
          ? ThumbnailMedia.fromJson(json['ThumbnailMedia'])
          : null,
      heading: json['Heading'] ?? '',
      title: json['Title'] ?? '',
      shortDescription: json['ShortDescription'] ?? '',
      steps: List<String>.from(json['Steps'] ?? []),
      tags: List<String>.from(json['Tags'] ?? []),
      isActive: json['IsActive'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'DataCode': dataCode,
      'ThumbnailMedia': thumbnailMedia?.toJson(),
      'Heading': heading,
      'Title': title,
      'ShortDescription': shortDescription,
      'Steps': steps,
      'Tags': tags,
      'IsActive': isActive,
    };
  }

  // FIX: Add toString method for proper debugging
  @override
  String toString() {
    return 'TipData(id: $id, title: $title, heading: $heading, tags: $tags)';
  }
}

class ThumbnailMedia {
  final String mediaCode;
  final String title;
  final String contentType;
  final String description;
  final String originalFilename;
  final String cdnUrl;
  final String originBucket;
  final dynamic mediaVariantsDto;

  ThumbnailMedia({
    required this.mediaCode,
    required this.title,
    required this.contentType,
    required this.description,
    required this.originalFilename,
    required this.cdnUrl,
    required this.originBucket,
    this.mediaVariantsDto,
  });

  factory ThumbnailMedia.fromJson(Map<String, dynamic> json) {
    final rawUrl = json['CdnUrl'] ?? '';

    return ThumbnailMedia(
      mediaCode: json['MediaCode'] ?? '',
      title: json['Title'] ?? '',
      contentType: json['ContentType'] ?? '',
      description: json['Description'] ?? '',
      originalFilename: json['OriginalFilename'] ?? '',
      cdnUrl: rawUrl.isNotEmpty && !rawUrl.startsWith('http')
          ? 'https://$rawUrl'
          : rawUrl,
      originBucket: json['OriginBucket'] ?? '',
      mediaVariantsDto: json['MediaVariantsDto'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'MediaCode': mediaCode,
      'Title': title,
      'ContentType': contentType,
      'Description': description,
      'OriginalFilename': originalFilename,
      'CdnUrl': cdnUrl,
      'OriginBucket': originBucket,
      'MediaVariantsDto': mediaVariantsDto,
    };
  }

  // FIX: Add toString method for proper debugging
  @override
  String toString() {
    return 'ThumbnailMedia(title: $title, cdnUrl: $cdnUrl)';
  }
}