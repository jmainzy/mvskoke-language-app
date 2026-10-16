import 'package:flutter/material.dart';
import 'package:mvskoke_language_app/services/content_service.dart';
import 'package:mvskoke_language_app/services/service_locator.dart';
import 'package:mvskoke_language_app/ui/components/reader_widget.dart';

class ContentPage extends StatefulWidget {
  const ContentPage({super.key, required this.contentId});

  final String contentId;

  @override
  ContentPageState createState() => ContentPageState();
}

class ContentPageState extends State<ContentPage> {
  final contentService = sl<ContentService>();
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: contentService.getContentById(widget.contentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No content found.'));
        } else {
          final contentItem = snapshot.data!.first;
          return Scaffold(
            appBar: AppBar(title: Text(contentItem.title)),
            body: contentItem.textFile != null
                ? ReaderWidget(textFile: contentItem.textFile!)
                : Container(),
          );
        }
      },
    );
  }
}
