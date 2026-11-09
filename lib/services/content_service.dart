import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';
import 'package:mvskoke_language_app/models/content_item.dart';
import 'package:mvskoke_language_app/models/enums.dart';
import 'package:mvskoke_language_app/models/media_item.dart';
import 'package:mvskoke_language_app/utilities/timestamp.dart';

Logger log = Logger();

final List<MediaObject> mediaItems = [
  MediaObject(
    id: '1',
    title: 'Day/Night Onvkuce',
    filename: 'chipbear.mp3',
    performer: 'Rebecca Barnett',
    copyright: '© 2026 Mvskoke Language Program',
    lastUpdate: Timestamp.now(),
  ),
  MediaObject(
    id: '2',
    title: '1878 Postoak letter to A.E.W. Robertson',
    filename: 'postoak-01.mp3',
    performer: 'Julia',
    copyright: '© 2026 MCN',
    lastUpdate: Timestamp.now(),
  ),
  MediaObject(
    id: '3',
    title: 'Nokose Oklane',
    filename: 'example.wav',
    performer: 'Margaret McKane Mauldin',
    copyright: '© 2026 MCN',
    lastUpdate: Timestamp.now(),
  ),
];

final List<ContentItem> stories = [
  ContentItem(
    id: '1',
    title: 'Day/Night Onvkuce',
    textFile: 'chipbear.readalong',
    mediaId: '1',
  ),
  ContentItem(
    id: '2',
    title: '1878 Postoak letter to A.E.W. Robertson',
    textFile: 'postoak-01.readalong',
    mediaId: '2',
  ),
  ContentItem(
    id: '3',
    title: 'Nokose Oklane',
    textFile: 'example.readalong',
    mediaId: '3',
  ),
];

class ContentService {
  List<ContentItem> getStories() {
    return stories;
  }

  Future<ContentItem?> getContentById(String id) async {
    return stories.firstWhere((story) => story.id == id);
  }

  Future<MediaObject?> getMediaById(String id) async {
    log.i('getMediaById: id = $id');
    return mediaItems.firstWhere((media) => media.id == id);
  }

  Future<AudioSource> getAudioSource(String mediaId) async {
    final media = await getMediaById(mediaId);
    if (media != null) {
      var (Uri uri, AssetLocation location) = await getAudioUri(media);
      if (location == AssetLocation.asset) {
        return AudioSource.asset(uri.path);
      } else {
        return AudioSource.uri(uri);
      }
    } else {
      throw Exception('Media not found for id: $mediaId');
    }
  }

  Future<(Uri, AssetLocation)> getAudioUri(MediaObject item) async {
    String? localUri = await findInAssets(item);
    if (localUri != null) {
      return (Uri(path: localUri), AssetLocation.asset);
    } else {
      var uri = getAudioUrl(item);
      return (uri, AssetLocation.remote);
    }
  }

  Future<String?> findInAssets(MediaObject item) async {
    var dirs = ['assets/audio/', 'assets/readalongs/'];
    for (var dir in dirs) {
      var filename = '$dir${item.filename}';
      try {
        await rootBundle.load(filename);
        return filename;
      } catch (e) {
        log.i('file not found locally $filename');
      }
    }
    return null;
  }

  Uri getAudioUrl(MediaObject item) {
    // return webService!.getAudioUrl(item.filename);
    return Uri.parse('https://example.com/audio/${item.filename}');
  }
}
