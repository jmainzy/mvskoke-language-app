import 'package:mvskoke_language_app/models/media_item.dart';

class ContentItem {
  final String id;
  final String title;
  final String? subtitle;
  final String? textFile;
  final String? mediaId;
  final String? thumbnail;
  final MediaType mediaType;
  bool get isVideo => mediaType == MediaType.video;

  ContentItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.textFile,
    this.mediaId,
    this.thumbnail,
    this.mediaType = MediaType.audio,
  });
}
