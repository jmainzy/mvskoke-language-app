import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logger/logger.dart';
import 'package:mvskoke_language_app/models/media_item.dart';
import 'package:mvskoke_language_app/ui/components/reader_chrome_scope.dart';
import 'package:mvskoke_language_app/ui/components/video_player.dart';
import 'package:mvskoke_language_app/ui/content/content_page_manager.dart';
import 'package:mvskoke_language_app/ui/content/word_widget.dart';
import 'package:mvskoke_language_app/utilities/dimens.dart';
import 'package:readalong/readalong.dart';

Logger log = Logger();

class _WordDefinitionPosition extends SingleChildLayoutDelegate {
  const _WordDefinitionPosition(this.word, this.safePadding);

  final Rect word;
  final EdgeInsets safePadding;
  static const double gap = 8;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints(
      maxWidth: (constraints.maxWidth - safePadding.horizontal - 2 * gap).clamp(
        0,
        280,
      ),
      maxHeight: (constraints.maxHeight - safePadding.vertical - 2 * gap).clamp(
        0,
        double.infinity,
      ),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final left = safePadding.left + gap;
    final right = size.width - safePadding.right - gap;
    final top = safePadding.top + gap;
    final bottom = size.height - safePadding.bottom - gap;
    final preferredX = word.right + gap;
    final preferredY = word.top - gap - childSize.height;
    final x = preferredX + childSize.width <= right
        ? preferredX
        : word.left - gap - childSize.width;
    final y = preferredY >= top ? preferredY : word.bottom + gap;
    return Offset(
      x.clamp(left, (right - childSize.width).clamp(left, double.infinity)),
      y.clamp(top, (bottom - childSize.height).clamp(top, double.infinity)),
    );
  }

  @override
  bool shouldRelayout(covariant _WordDefinitionPosition oldDelegate) =>
      word != oldDelegate.word || safePadding != oldDelegate.safePadding;
}

class ContentPage extends StatefulWidget {
  const ContentPage({super.key, required this.contentId});

  final String contentId;

  @override
  ContentPageState createState() => ContentPageState();
}

class ContentPageState extends State<ContentPage> with WidgetsBindingObserver {
  var manager = ContentPageManager();
  late ValueNotifier<bool> _chromeVisibility;
  bool? _wasActive;
  bool? _wasLandscape;
  OverlayEntry? _wordDefinitionOverlay;
  int _readerPageIndex = 0;

  @override
  initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    manager.contentItemFuture = manager.getContentItem(widget.contentId);
  }

  @override
  void didUpdateWidget(covariant ContentPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contentId != widget.contentId) {
      _hideWordDefinition();
      _readerPageIndex = 0;
      manager.dispose();
      manager = ContentPageManager();
      manager.contentItemFuture = manager.getContentItem(widget.contentId);
    }
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
      unawaited(manager.saveVideoProgress());
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
    _hideWordDefinition();
    WidgetsBinding.instance.removeObserver(this);
    manager.dispose();
    super.dispose();
  }

  void _toggleReaderChrome() {
    _chromeVisibility.value = !_chromeVisibility.value;
  }

  void _handleReaderPosition(ReadAlongPosition position) {
    if (position.pageIndex != _readerPageIndex) {
      _hideWordDefinition();
      _readerPageIndex = position.pageIndex;
    }
  }

  void _hideWordDefinition() {
    _wordDefinitionOverlay?.remove();
    _wordDefinitionOverlay?.dispose();
    _wordDefinitionOverlay = null;
  }

  void _showWordDefinition(String word, Rect bounds) {
    _hideWordDefinition();
    final overlay = Overlay.of(context);
    final overlayBox = overlay.context.findRenderObject() as RenderBox;
    final rect = Rect.fromPoints(
      overlayBox.globalToLocal(bounds.topLeft),
      overlayBox.globalToLocal(bounds.bottomRight),
    );
    _wordDefinitionOverlay = OverlayEntry(
      builder: (overlayContext) => Positioned.fill(
        child: CustomSingleChildLayout(
          delegate: _WordDefinitionPosition(
            rect,
            MediaQuery.paddingOf(overlayContext),
          ),
          child: WordWidget(
            word: manager.getWord(word)!,
            onHide: _hideWordDefinition,
          ),
        ),
      ),
    );
    overlay.insert(_wordDefinitionOverlay!);
  }

  Widget _buildVideoPlayer() {
    final media = manager.mediaItem;
    final sourceUrl = media?.uri;
    if (media?.mediaType != MediaType.video || sourceUrl == null) {
      return const SizedBox.shrink();
    }

    return VideoPlayer(url: sourceUrl, controller: manager.playbackController!);
  }

  @override
  Widget build(BuildContext context) {
    final appBarVisible = _chromeVisibility.value && !kIsWeb;
    return AnimatedBuilder(
      animation: _chromeVisibility,
      builder: (context, _) => Scaffold(
        appBar: appBarVisible
            ? AppBar(
                title: FutureBuilder(
                  future: manager.contentItemFuture,
                  builder: (context, snapshot) => Text(manager.title),
                ),
              )
            : null,
        body: Stack(
          children: [
            FutureBuilder(
              future: manager.contentItemFuture,
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
                      manager.mediaItem?.performer != null &&
                          manager.mediaItem!.performer!.isNotEmpty
                      ? '${contentItem.title} reading by ${manager.mediaItem!.performer}'
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
                                audioSource: manager.audioSource,
                                playbackController: manager.playbackController,
                                audioTitle: infoTitle,
                                onReaderSurfaceTap: _toggleReaderChrome,
                                onPositionChanged: _handleReaderPosition,
                                indexedWords: manager.indexedWords.toSet(),
                                onWordTap: _showWordDefinition,
                              ),
                            ),
                            manager.mediaItem?.mediaType != MediaType.video
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
                      manager.mediaItem?.mediaType == MediaType.video;

                  if (manager.mediaItem?.mediaType == MediaType.video) {
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
                      manager.mediaItem?.mediaType == MediaType.video
                          ? videoPlayer
                          : SizedBox.shrink(),
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
