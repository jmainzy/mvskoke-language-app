import 'package:mvskoke_language_app/models/content_item.dart';

final List<ContentItem> stories = [
  ContentItem(
    id: '1',
    title: 'Day/Night Onvkuce',
    textFile: 'day_night_onvkuce.txt',
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

  Future<List<ContentItem>> getContentById(String id) async {
    return stories.where((story) => story.id == id).toList();
  }
}
