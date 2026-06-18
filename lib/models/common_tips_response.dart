class CommonTipsResponse {
  final bool? status;
  final String? statusType;
  final String? message;
  final List<CommonTip>? data;

  CommonTipsResponse({this.status, this.statusType, this.message, this.data});

  factory CommonTipsResponse.fromJson(Map<String, dynamic> json) {
    return CommonTipsResponse(
      status: json['status'],
      statusType: json['statusType'],
      message: json['message'],
      data:
          json['data'] != null
              ? List<CommonTip>.from(
                json['data'].map((x) => CommonTip.fromJson(x)),
              )
              : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'statusType': statusType,
      'message': message,
      'data': data?.map((x) => x.toJson()).toList(),
    };
  }
}

class CommonTip {
  final int? id;
  final String? dataCode;
  final ThumbnailMedia? thumbnailMedia;
  final String? heading;
  final String? title;
  final String? shortDescription;
  final List<String>? steps;
  final List<String>? tags;
  final bool? isActive;

  CommonTip({
    this.id,
    this.dataCode,
    this.thumbnailMedia,
    this.heading,
    this.title,
    this.shortDescription,
    this.steps,
    this.tags,
    this.isActive,
  });

  factory CommonTip.fromJson(Map<String, dynamic> json) {
    return CommonTip(
      id: json['Id'],
      dataCode: json['DataCode'],
      thumbnailMedia:
          json['ThumbnailMedia'] != null
              ? ThumbnailMedia.fromJson(json['ThumbnailMedia'])
              : null,
      heading: json['Heading'],
      title: json['Title'],
      shortDescription: json['ShortDescription'],
      steps: json['Steps'] != null ? List<String>.from(json['Steps']) : [],
      tags: json['Tags'] != null ? List<String>.from(json['Tags']) : [],
      isActive: json['IsActive'],
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
}

class ThumbnailMedia {
  final String? mediaCode;
  final String? title;
  final String? contentType;
  final String? description;
  final String? originalFilename;
  final String? cdnUrl;
  final String? originBucket;

  ThumbnailMedia({
    this.mediaCode,
    this.title,
    this.contentType,
    this.description,
    this.originalFilename,
    this.cdnUrl,
    this.originBucket,
  });

  factory ThumbnailMedia.fromJson(Map<String, dynamic> json) {
    return ThumbnailMedia(
      mediaCode: json['MediaCode'],
      title: json['Title'],
      contentType: json['ContentType'],
      description: json['Description'],
      originalFilename: json['OriginalFilename'],
      cdnUrl: json['CdnUrl'],
      originBucket: json['OriginBucket'],
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
    };
  }
}
