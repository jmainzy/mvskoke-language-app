class ContentItem {
  final String id;
  final String title;
  final String? textFile;
  final String? mediaId;

  ContentItem({
    required this.id,
    required this.title,
    this.textFile,
    this.mediaId,
  });
}
