import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:mvskoke_language_app/models/media_item.dart';

import 'package:mvskoke_language_app/services/content_service.dart';
import 'package:mvskoke_language_app/services/service_locator.dart';
import 'package:mvskoke_language_app/ui/components/audio_player_widget.dart';
import 'package:mvskoke_language_app/utilities/dimens.dart';
import 'package:mvskoke_language_app/utilities/readalong_parser.dart';

Logger log = Logger();

class ReaderWidget extends StatefulWidget {
  final String data;
  final String? mediaId;
  const ReaderWidget({super.key, required this.data, this.mediaId});

  @override
  ReaderWidgetState createState() => ReaderWidgetState();
}

class ReaderWidgetState extends State<ReaderWidget> {
  final contentService = sl<ContentService>();
  final parser = ReadalongParser();
  ReadAlong? readalong;
  MediaObject? media;

  @override
  void initState() {
    super.initState();
    getData();
  }

  void getData() async {
    readalong = await parser.getText(widget.data);
    log.i('medaId = ${widget.mediaId}');
    if (widget.mediaId != null) {
      media = await contentService.getMediaById(widget.mediaId!);
      log.i('media = $media');
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (readalong != null)
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(Dimens.marginShort),
              itemCount: readalong!.sentences.length,
              itemBuilder: (context, index) {
                final sentence = readalong!.sentences[index];
                return SentenceWidget(sentence: sentence);
              },
            ),
          ),
        if (media != null) AudioPlayerWidget(mediaItems: [media!]),
      ],
    );
  }
}

class SentenceWidget extends StatelessWidget {
  final ReadAlongSentence sentence;

  const SentenceWidget({super.key, required this.sentence});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Dimens.marginShort),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(sentence.text, style: const TextStyle(fontSize: 18)),
          if (sentence.translation != null)
            Text(
              sentence.translation!,
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
        ],
      ),
    );
  }
}
