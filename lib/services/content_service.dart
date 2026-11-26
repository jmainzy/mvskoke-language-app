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
    uri: 'chipbear.mp3',
    performer: 'Rebecca Barnett',
    copyright: '© 2026 Mvskoke Language Program',
    lastUpdate: Timestamp.now(),
  ),
  MediaObject(
    id: '2',
    title: '1878 Postoak letter to A.E.W. Robertson',
    uri: 'postoak-01.mp3',
    performer: 'Margaret McKane Mauldin',
    copyright: '© 2026 MCN',
    lastUpdate: Timestamp.now(),
  ),
  MediaObject(
    id: '3',
    title: 'Nokose Oklane',
    uri: 'example.wav',
    performer: 'Margaret McKane Mauldin',
    copyright: '© 2026 MCN',
    lastUpdate: Timestamp.now(),
  ),
  MediaObject(
    id: '4',
    title: 'Eco ton momen Cufe',
    uri: 'eco-cufe.mp3',
    performer: 'Margaret McKane Mauldin',
    copyright: '© 2026 MCN',
    lastUpdate: Timestamp.now(),
  ),
  MediaObject(
    id: '5',
    title: 'Interview with Bessie Spencer',
    uri: 'https://vimeo.com/253875203',
    performer: 'Bessie Spencer',
    copyright: '© 2026 MCN',
    mediaType: MediaType.video,
    lastUpdate: Timestamp.now(),
  ),
  MediaObject(
    id: '7',
    title: 'Interview with Ella Colman',
    uri: 'https://vimeo.com/169627576',
    performer: 'Ella Colman',
    copyright: '© 2026 MCN',
    mediaType: MediaType.video,
    lastUpdate: Timestamp.now(),
  ),
  MediaObject(
    id: '6',
    title: 'cvyacetos',
    uri: 'cvyacetos.mp3',
    performer: 'Gracine Hicks',
    copyright: '© 2026 MCN',
    lastUpdate: Timestamp.now(),
  ),
];

final List<ContentItem> stories = [
  ContentItem(
    id: '5',
    title: 'Cvyacetos',
    subtitle: 'I like',
    textFile: 'cvyacetos.readalong',
    mediaId: '6',
    thumbnail: 'image-cvyacetos-20261112170953-0.jpg',
  ),
  ContentItem(
    id: '3',
    title: 'Eco ton momen Cufe',
    subtitle: 'How Deer Fooled Rabbit',
    textFile: 'eco-cufe.readalong',
    mediaId: '4',
    thumbnail: 'image-eco-ton-momen-c-20261110164718-0.png',
  ),
  ContentItem(
    id: '1',
    title: 'Nere nettv Onvkuce',
    subtitle: 'A story of day and night',
    textFile: 'chipbear.readalong',
    mediaId: '1',
    thumbnail: 'nere-p1.png',
  ),
  ContentItem(
    id: '4',
    title: 'Interview with Bessie Spencer',
    textFile: 'mus16051.eaf',
    mediaId: '5',
    thumbnail: 'mus16051-thumb.png',
    mediaType: MediaType.video,
  ),
  ContentItem(
    id: '2',
    title: '1878 Postoak letter to A.E.W. Robertson',
    textFile: 'postoak-01.readalong',
    mediaId: '2',
    thumbnail: 'postoak-01.png',
  ),
  ContentItem(
    id: '6',
    title: 'Interview with Ella Colman',
    textFile: 'mus16019.eaf',
    mediaId: '7',
    thumbnail: 'mus16019-thumb.png',
    mediaType: MediaType.video,
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
      var filename = '$dir${item.uri}';
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
    return Uri.parse('https://example.com/audio/${item.uri}');
  }
}
