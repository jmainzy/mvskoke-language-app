import 'package:flutter/material.dart';
import 'package:mvskoke_language_app/services/content_service.dart';
import 'package:mvskoke_language_app/services/service_locator.dart';

class ReaderWidget extends StatefulWidget {
  final String textFile;
  const ReaderWidget({super.key, required this.textFile});

  @override
  ReaderWidgetState createState() => ReaderWidgetState();
}

class ReaderWidgetState extends State<ReaderWidget> {
  final contentService = sl<ContentService>();
  @override
  Widget build(BuildContext context) {
    return Text(widget.textFile);
  }
}
