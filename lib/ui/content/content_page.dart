import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';
import 'package:mvskoke_language_app/models/content_item.dart';
import 'package:mvskoke_language_app/models/media_item.dart';
import 'package:mvskoke_language_app/services/content_service.dart';
import 'package:mvskoke_language_app/services/service_locator.dart';
import 'package:mvskoke_language_app/ui/components/reader_chrome_scope.dart';
import 'package:readalong/readalong.dart';

Logger log = Logger();

class ContentPage extends StatefulWidget {
  const ContentPage({super.key, required this.contentId});

  final String contentId;

  @override
  ContentPageState createState() => ContentPageState();
}

class ContentPageState extends State<ContentPage> with WidgetsBindingObserver {
  final contentService = sl<ContentService>();
  late Future<ContentItem?> contentItemFuture;
  late MediaObject? mediaItem;
  late AudioSource? audioSource;
  final ValueNotifier<bool> _localChromeVisibility = ValueNotifier(true);
  late ValueNotifier<bool> _chromeVisibility = _localChromeVisibility;
  bool? _wasActive;
  bool? _wasLandscape;
  String title = '';

  @override
  initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    contentItemFuture = getContentItem();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final chromeScope = ReaderChromeScope.maybeOf(context);
    _chromeVisibility = chromeScope?.visibility ?? _localChromeVisibility;
    _syncChromeVisibility(chromeScope);
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncChromeVisibility(ReaderChromeScope.maybeOf(context));
    });
  }

  void _syncChromeVisibility(ReaderChromeScope? chromeScope) {
    _chromeVisibility = chromeScope?.visibility ?? _localChromeVisibility;
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final isActive = chromeScope?.isActive ?? true;
    if (isActive && (_wasLandscape != isLandscape || _wasActive != isActive)) {
      _wasLandscape = isLandscape;
      _wasActive = isActive;
      _chromeVisibility.value = !isLandscape;
    } else if (!isActive) {
      _wasActive = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _localChromeVisibility.dispose();
    super.dispose();
  }

  void _toggleReaderChrome() {
    _chromeVisibility.value = !_chromeVisibility.value;
  }

  Future<ContentItem?> getContentItem() async {
    final item = await contentService.getContentById(widget.contentId);
    log.i('getContentItem: item = $item');
    title = item?.title ?? '';
    if (item?.mediaId != null && item!.mediaId!.isNotEmpty) {
      mediaItem = await contentService.getMediaById(item.mediaId!);
      audioSource = await contentService.getAudioSource(item.mediaId!);
    }
    return item;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _chromeVisibility,
      builder: (context, _) => Scaffold(
        appBar: _chromeVisibility.value ? AppBar(title: Text(title)) : null,
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
              final infoTitle =
                  mediaItem?.performer != null &&
                      mediaItem!.performer!.isNotEmpty
                  ? '${contentItem.title} reading by ${mediaItem!.performer}'
                  : null;
              return contentItem.textFile != null
                  ? ReadAlong(
                      xmlAsset: 'assets/readalongs/${contentItem.textFile}',
                      imagesFolder: 'assets/images',
                      audioSource: audioSource,
                      audioTitle: infoTitle,
                      onReaderSurfaceTap: _toggleReaderChrome,
                    )
                  : Container();
            }
          },
        ),
      ),
    );
  }
}
