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
import 'package:mvskoke_language_app/ui/components/vimeo_player.dart';
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
    _chromeVisibility = chromeScope?.visibility ?? _localChromeVisibility;
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
    _localChromeVisibility.dispose();
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
          _videoPositionSubscription = _vimeoPlaybackController!
              .positionStream
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

    final vimeoEmbedUrl = Utils.getVimeoEmbedUrl(sourceUrl);
    if (vimeoEmbedUrl != null) {
      return VimeoPlayer(
        embedUrl: vimeoEmbedUrl,
        controller: _vimeoPlaybackController!,
      );
    }

    return FutureBuilder<String?>(
      future: _videoUrlFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AspectRatio(
            aspectRatio: 16 / 9,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final videoUrl = snapshot.data;
        if (videoUrl == null) {
          return const Center(child: Text('No video found.'));
        }
        return AspectRatio(
          aspectRatio: 16 / 9,
          child: Center(child: Text('Video player for $videoUrl')),
        );
      },
    );
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
              final videoPlayer = _buildVideoPlayer();
              final reader = contentItem.textFile != null
                  ? ReadAlong(
                      xmlAsset: 'assets/readalongs/${contentItem.textFile}',
                      imagesFolder: 'assets/images',
                      audioSource: audioSource,
                      playbackController: _vimeoPlaybackController,
                      audioTitle: infoTitle,
                      onReaderSurfaceTap: _toggleReaderChrome,
                    )
                  : const SizedBox.shrink();
              final showSideBySide =
                  MediaQuery.orientationOf(context) == Orientation.landscape &&
                  mediaItem?.mediaType == MediaType.video;

              if (mediaItem?.mediaType == MediaType.video) {
                return Flex(
                  direction: showSideBySide ? Axis.horizontal : Axis.vertical,
                  children: [
                    Flexible(
                      flex: showSideBySide ? 1 : 0,
                      fit: showSideBySide ? FlexFit.tight : FlexFit.loose,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: videoPlayer,
                        ),
                      ),
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
      ),
    );
  }
}
