import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:just_audio/just_audio.dart' hide PlayerState, ProcessingState;
import 'package:logger/logger.dart';
import 'package:mvskoke_language_app/models/content_item.dart';
import 'package:mvskoke_language_app/models/media_item.dart';
import 'package:mvskoke_language_app/services/content_service.dart';
import 'package:mvskoke_language_app/services/service_locator.dart';
import 'package:mvskoke_language_app/services/store_service.dart';
import 'package:mvskoke_language_app/ui/components/reader_chrome_scope.dart';
import 'package:mvskoke_language_app/ui/components/video_player.dart';
import 'package:mvskoke_language_app/utilities/dimens.dart';
import 'package:mvskoke_language_app/utilities/utils.dart';
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
  Future<String?>? _videoUrlFuture;
  VimeoPlaybackController? _vimeoPlaybackController;
  StreamSubscription<Duration>? _videoPositionSubscription;
  StreamSubscription<PlayerState>? _videoStateSubscription;
  Timer? _progressSaveTimer;
  Duration? _latestVideoPosition;
  MediaObject? mediaItem;
  AudioSource? audioSource;
  late ValueNotifier<bool> _chromeVisibility;
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
    _chromeVisibility = chromeScope?.visibility ?? ValueNotifier(true);
    _syncChromeVisibility(chromeScope);
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncChromeVisibility(ReaderChromeScope.maybeOf(context));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(_saveVideoProgress());
    }
  }

  void _syncChromeVisibility(ReaderChromeScope? chromeScope) {
    _chromeVisibility = chromeScope?.visibility ?? ValueNotifier(true);
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final isActive = chromeScope?.isActive ?? true;
    if (isActive && (_wasLandscape != isLandscape || _wasActive != isActive)) {
      _wasLandscape = isLandscape;
      _wasActive = isActive;
      _chromeVisibility.value = !isLandscape || kIsWeb;
    } else if (!isActive) {
      _wasActive = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _progressSaveTimer?.cancel();
    unawaited(_videoPositionSubscription?.cancel());
    unawaited(_videoStateSubscription?.cancel());
    unawaited(_saveVideoProgress());
    _vimeoPlaybackController?.dispose();
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
      if (mediaItem?.mediaType == MediaType.video && mediaItem?.uri != null) {
        final embedUrl = Utils.getVimeoEmbedUrl(mediaItem!.uri!);
        if (embedUrl != null) {
          final progress = sl<StoreService>().getVideoProgress(item.id);
          _latestVideoPosition = progress?.position ?? Duration.zero;
          _vimeoPlaybackController = VimeoPlaybackController(
            initialPosition: _latestVideoPosition!,
          );
          _videoPositionSubscription = _vimeoPlaybackController!.positionStream
              .listen(_handleVideoPosition);
          _videoStateSubscription = _vimeoPlaybackController!.stateStream
              .listen((state) {
                if (state.processingState == ProcessingState.completed ||
                    !state.playing) {
                  unawaited(_saveVideoProgress());
                }
              });
        } else {
          _videoUrlFuture = Utils.getVideoUrl(mediaItem!.uri!);
        }
      } else {
        audioSource = await contentService.getAudioSource(item.mediaId!);
      }
    }
    return item;
  }

  void _handleVideoPosition(Duration position) {
    _latestVideoPosition = position;
    _progressSaveTimer ??= Timer(const Duration(seconds: 5), () {
      _progressSaveTimer = null;
      unawaited(_saveVideoProgress());
    });
  }

  Future<void> _saveVideoProgress() async {
    final controller = _vimeoPlaybackController;
    final position = _latestVideoPosition;
    if (controller == null ||
        position == null ||
        mediaItem?.mediaType != MediaType.video) {
      return;
    }

    try {
      await sl<StoreService>().saveVideoProgress(
        widget.contentId,
        position: position,
        duration: controller.duration,
      );
    } catch (error, stackTrace) {
      log.e(
        'Unable to save video progress',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Widget _buildVideoPlayer() {
    final media = mediaItem;
    final sourceUrl = media?.uri;
    if (media?.mediaType != MediaType.video || sourceUrl == null) {
      return const SizedBox.shrink();
    }

    return VideoPlayer(url: sourceUrl, controller: _vimeoPlaybackController!);
  }

  @override
  Widget build(BuildContext context) {
    final appBarVisible = _chromeVisibility.value && !kIsWeb;
    return AnimatedBuilder(
      animation: _chromeVisibility,
      builder: (context, _) => Scaffold(
        appBar: appBarVisible ? AppBar(title: Text(title)) : null,
        body: Stack(
          children: [
            FutureBuilder(
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
                  final videoPlayer = _buildVideoPlayer();
                  final safePadding = MediaQuery.paddingOf(context).bottom; // Will cause a rebuild only if padding changes (requires Flutter > 3.10)
                  final reader = contentItem.textFile != null
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Expanded(
                              child: ReadAlong(
                                xmlAsset:
                                    'assets/readalongs/${contentItem.textFile}',
                                imagesFolder: 'assets/images',
                                audioSource: audioSource,
                                playbackController: _vimeoPlaybackController,
                                audioTitle: infoTitle,
                                onReaderSurfaceTap: _toggleReaderChrome,
                              ),
                            ),
                            mediaItem?.mediaType != MediaType.video
                                ? SizedBox(
                                    height: safePadding + Dimens.marginLarge,
                                    child: Container(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerLow,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ],
                        )
                      : const SizedBox.shrink();
                  final showSideBySide =
                      MediaQuery.orientationOf(context) ==
                          Orientation.landscape &&
                      mediaItem?.mediaType == MediaType.video;

                  if (mediaItem?.mediaType == MediaType.video) {
                    return Flex(
                      direction: showSideBySide
                          ? Axis.horizontal
                          : Axis.vertical,
                      children: [
                        Flexible(
                          flex: showSideBySide ? 1 : 0,
                          fit: showSideBySide ? FlexFit.tight : FlexFit.loose,
                          child: Center(child: videoPlayer),
                        ),
                        SizedBox(
                          width: showSideBySide ? 1 : 0,
                          height: showSideBySide ? 0 : 1,
                          child: showSideBySide
                              ? VerticalDivider(
                                  width: 1,
                                  color: Theme.of(context).dividerColor,
                                )
                              : null,
                        ),
                        Expanded(child: reader),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      videoPlayer,
                      Expanded(child: reader),
                    ],
                  );
                }
              },
            ),
            if (!appBarVisible && !kIsWeb)
              IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}
