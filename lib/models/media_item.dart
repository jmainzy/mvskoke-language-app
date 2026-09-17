import 'package:audio_service/audio_service.dart';
import 'package:mvskoke_language_app/utilities/timestamp.dart';
import 'package:mvskoke_language_app/utilities/utils.dart';

class MediaObject extends MediaItem {
  final String? filename;
  final String? performer;
  final String copyright;
  final Timestamp? lastUpdate;

  MediaObject({
    required super.id,
    required super.title,
    required this.filename,
    required this.performer,
    required this.copyright,
    required this.lastUpdate,
  });

  @override
  String toString() {
    return '''
    MediaItem(id: $id, 
      title: $title, 
      filename: $filename,
      performer: $performer,
      copyright: $copyright,
      lastUpdate: $lastUpdate)
    ''';
  }

  MediaObject fromMap(Map<String, dynamic> map) {
    final lastUpdate = Utils.getFormattedDate(map['created_at']);
    return MediaObject(
      id: map['id'],
      title: map['title'],
      filename: map['filename'],
      performer: map['performer'],
      copyright: map['copyright'],
      lastUpdate: lastUpdate,
    );
  }

  @override
  Map<String, dynamic> toMap(MediaObject object) {
    return {
      'id': object.id,
      'title': object.title,
      'filename': object.filename,
      'performer': object.performer,
      'copyright': object.copyright,
      'lastUpdate': object.lastUpdate.toString(),
    };
  }
}
