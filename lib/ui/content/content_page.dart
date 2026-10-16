import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:mvskoke_language_app/models/content_item.dart';
import 'package:mvskoke_language_app/services/content_service.dart';
import 'package:mvskoke_language_app/services/service_locator.dart';
import 'package:mvskoke_language_app/ui/components/reader_widget.dart';

Logger log = Logger();

class ContentPage extends StatefulWidget {
  const ContentPage({super.key, required this.contentId});

  final String contentId;

  @override
  ContentPageState createState() => ContentPageState();
}

class ContentPageState extends State<ContentPage> {
  final contentService = sl<ContentService>();
  late Future<ContentItem?> contentItemFuture;
  String title = '';

  @override
  initState() {
    super.initState();
    contentItemFuture = getContentItem();
  }

  Future<ContentItem?> getContentItem() async {
    final item = await contentService.getContentById(widget.contentId);
    log.i('getContentItem: item = $item');
    title = item?.title ?? '';
    return item;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder(
        future: contentItemFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('No content found.'));
          } else {
            final contentItem = snapshot.data!;
            return contentItem.textFile != null
                ? ReaderWidget(
                    data: contentItem.textFile!,
                    mediaId: contentItem.mediaId,
                  )
                : Container();
          }
        },
      ),
    );
  }
}
