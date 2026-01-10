class MusicResponse {
  final bool status;
  final String statusType;
  final String message;
  final List<MusicItem> data;

  MusicResponse({
    required this.status,
    required this.statusType,
    required this.message,
    required this.data,
  });

  factory MusicResponse.fromJson(Map<String, dynamic> json) {
    return MusicResponse(
      status: json['status'] ?? false,
      statusType: json['statusType'] ?? '',
      message: json['message'] ?? '',
      data:
          json['data'] != null
              ? List<MusicItem>.from(
                json['data'].map((x) => MusicItem.fromJson(x)),
              )
              : [],
    );
  }
  @override
  String toString() {
    return 'MusicResponse(status: $status, statusType: $statusType, message: $message, data: ${data.toString()})';
  }
}

class MusicItem {
  final int id;
  final String dataCode;
  final String title;
  final String artistName;
  final String shortDescription;
  final List<String> tags;
  final bool isActive;
  final Media media;
  final String? thumbnailMedia; // ✅ changed

  MusicItem({
    required this.id,
    required this.dataCode,
    required this.title,
    required this.artistName,
    required this.shortDescription,
    required this.tags,
    required this.isActive,
    required this.media,
    this.thumbnailMedia,
  });

  factory MusicItem.fromJson(Map<String, dynamic> json) {
    return MusicItem(
      id: json['Id'],
      dataCode: json['DataCode'] ?? '',
      title: json['Title'] ?? '',
      artistName: json['ArtistName'] ?? '',
      shortDescription: json['ShortDescription'] ?? '',
      tags: json['Tags'] != null ? List<String>.from(json['Tags']) : [],
      isActive: json['IsActive'] ?? false,
      media: Media.fromJson(json['Media']),

      // ✅ extract CDN URL safely
      thumbnailMedia:
          json['ThumbnailMedia'] != null
              ? json['ThumbnailMedia']['CdnUrl'] as String?
              : null,
    );
  }
  @override
  String toString() {
    return 'MusicItem(id: $id, title: $title, artist: $artistName, cdnUrl: ${media.cdnUrl})';
  }
}

class Media {
  final String mediaCode;
  final String title;
  final String contentType;
  final String description;
  final String originalFilename;
  final String cdnUrl;
  final String originBucket;

  Media({
    required this.mediaCode,
    required this.title,
    required this.contentType,
    required this.description,
    required this.originalFilename,
    required this.cdnUrl,
    required this.originBucket,
  });

  factory Media.fromJson(Map<String, dynamic> json) {
    final rawCdnUrl = json['CdnUrl'] ?? '';
    return Media(
      mediaCode: json['MediaCode'] ?? '',
      title: json['Title'] ?? '',
      contentType: json['ContentType'] ?? '',
      description: json['Description'] ?? '',
      originalFilename: json['OriginalFilename'] ?? '',
      cdnUrl: _withHttps(rawCdnUrl),
      originBucket: json['OriginBucket'] ?? '',
    );
  }
  @override
  String toString() {
    return 'Media(mediaCode: $mediaCode, title: $title, contentType: $contentType, description: $description , originalFilename : $originalFilename, cdnUrl: $cdnUrl, originBucket: $originBucket)';
  }
}

String _withHttps(String url) {
  if (url.isEmpty) return '';
  return url.startsWith('http') ? url : 'https://$url';
}
