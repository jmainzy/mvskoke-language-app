import 'package:logger/logger.dart';
import 'package:mvskoke_language_app/models/content_item.dart';
import 'package:mvskoke_language_app/models/media_item.dart';
import 'package:mvskoke_language_app/utilities/timestamp.dart';

Logger log = Logger();

final List<MediaObject> mediaItems = [
  MediaObject(
    id: '1',
    title: 'Day/Night Onvkuce',
    filename: 'day_night_onvkuce.mp3',
    performer: 'Mvskoke Language App',
    copyright: '© 2023 Mvskoke Language Program',
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
  ContentItem(id: '2', title: 'Nokose Oklane', textFile: 'nokose_oklane.txt'),
  ContentItem(id: '3', title: 'Letter', textFile: 'letter.txt'),
  ContentItem(
    id: '4',
    title: 'Roretv Hvtvm Tohkvlke',
    textFile: 'roretv_hvtvm_tohkvlke.txt',
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
}
