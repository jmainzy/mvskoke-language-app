class Readalong {
  final String id;
  final String title;
  final String? textFile;
  final String? mediaId;

  Readalong({
    required this.id,
    required this.title,
    this.textFile,
    this.mediaId,
  });
}
