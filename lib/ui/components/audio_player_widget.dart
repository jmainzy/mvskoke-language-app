import 'dart:async';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:marquee/marquee.dart';
import 'package:mvskoke_language_app/managers/audio_manager.dart';
import 'package:mvskoke_language_app/models/enums.dart';
import 'package:mvskoke_language_app/models/media_item.dart';
import 'package:mvskoke_language_app/notifiers/progress_notifier.dart';
import 'package:mvskoke_language_app/services/service_locator.dart';
import 'package:mvskoke_language_app/utilities/dimens.dart';

class AudioPlayerWidget extends StatefulWidget {
  final List<MediaObject> mediaItems;
  final VoidCallback? onClose;

  const AudioPlayerWidget({required this.mediaItems, this.onClose, super.key});

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  Logger logger = Logger();

  late Future<void> initAudioFuture;
  late MediaObject currentMedia;

  @override
  void initState() {
    super.initState();
    currentMedia = widget.mediaItems.first;
    initAudioFuture = initializeAudio();
  }

  Future<void> initializeAudio() async {
    var (Uri uri, AssetLocation location) = await sl<AudioManager>()
        .getAudioUri(currentMedia);
    logger.i("uri = $uri, location = $location");
    if (!mounted) return;
    await sl<AudioManager>().setMedia(
      uri,
      location: location,
      id: currentMedia.id,
      title: currentMedia.title,
      album: 'Nak-cokv Esyvhiketv',
    );
    logger.i('set media');
    sl<AudioManager>().play();
    return;
  }

  @override
  Widget build(BuildContext context) {
    // final dm = sl<DownloadManager>();
    // final filename = widget.mediaItem?.filename;

    return Material(
      child: Container(
        color: Theme.of(context).colorScheme.surface,
        child: FutureBuilder<void>(
          future: initAudioFuture,
          builder: (context, snapshot) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: Dimens.marginShort),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 36),
                      Expanded(
                        child: _PlayerTitle(
                          title: currentMedia.title,
                          performer: currentMedia.performer,
                          album: currentMedia.copyright,
                        ),
                      ),
                      // if (filename != null)
                      //   AnimatedBuilder(
                      //     animation: dm,
                      //     builder: (context, _) {
                      //       final task = dm.getTask(filename);
                      //       switch (task.state) {
                      //         case DownloadState.downloaded:
                      //           return IconButton(
                      //             icon: const Icon(
                      //               Icons.delete,
                      //               color: Colors.red,
                      //             ),
                      //             tooltip: 'Delete downloaded file',
                      //             onPressed: () => dm.deleteFile(filename),
                      //           );
                      //         case DownloadState.downloading:
                      //           return CircularProgressIndicator(
                      //             value: task.progress,
                      //           );
                      //         case DownloadState.failed:
                      //           return IconButton(
                      //             icon: const Icon(
                      //               Icons.error,
                      //               color: Colors.red,
                      //             ),
                      //             onPressed: () => dm.downloadFile(filename),
                      //           );
                      //         case DownloadState.notDownloaded:
                      //           return IconButton(
                      //             icon: const Icon(Icons.download),
                      //             onPressed: () => dm.downloadFile(filename),
                      //           );
                      //       }
                      //     },
                      //   ),

                      IconButton(
                        onPressed: widget.onClose,
                        icon: const Icon(Icons.close, color: Colors.black54),
                      ),
                    ],
                  ),
                  if (snapshot.connectionState == ConnectionState.waiting) ...[
                    const _LoadingWidget(),
                  ] else if (snapshot.hasError) ...[
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: Dimens.marginLarge,
                          ),
                          child: Icon(Icons.error),
                        ),
                      ],
                    ),
                  ] else ...[
                    _PlayerControls(),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    sl<AudioManager>().stop();
    super.dispose();
  }
}

class _PlayerTitle extends StatelessWidget {
  final String title;
  final String? performer;
  final String? album;

  const _PlayerTitle({required this.title, this.performer, this.album});

  @override
  Widget build(BuildContext context) {
    TextStyle subtitleStyle = Theme.of(context).textTheme.bodyMedium!.copyWith(
      color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
      fontWeight: FontWeight.w400,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Dimens.marginShort),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _AutoMarquee(
            text: title,
            style: Theme.of(context).textTheme.titleSmall!
                .copyWith(fontWeight: FontWeight.w400),
          ),
          if (performer != null)
            _AutoMarquee(text: performer!, style: subtitleStyle),
          if (album != null) _AutoMarquee(text: album!, style: subtitleStyle),
        ],
      ),
    );
  }
}

class _AutoMarquee extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const _AutoMarquee({required this.text, this.style});

  @override
  Widget build(BuildContext context) {
    return AutoSizeText(
      text,
      maxLines: 1,
      minFontSize: 13,
      style: style,
      overflowReplacement: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: style != null ? style!.fontSize! + 5 : 30,
        ),
        child: Center(
          child: Marquee(
            text: text,
            style: style!,
            scrollAxis: Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.start,
            blankSpace: Dimens.marginLarge * 2,
            pauseAfterRound: const Duration(seconds: 2),
            // startPadding: Dimens.marginShort,
          ),
        ),
      ),
    );
  }
}

class _LoadingWidget extends StatelessWidget {
  const _LoadingWidget();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Dimens.marginShort),
      child: LinearProgressIndicator(),
    );
  }
}

class _PlayerControls extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final audioManager = sl<AudioManager>();
    return ValueListenableBuilder<ProgressBarState>(
      valueListenable: audioManager.progressNotifier,
      builder: (context, value, child) {
        return Row(
          children: [
            const SizedBox(width: Dimens.marginLarge),
            Expanded(
              child: ProgressBar(
                progress: value.current,
                buffered: value.buffered,
                total: value.total,
                onSeek: audioManager.seek,
                timeLabelLocation: TimeLabelLocation.sides,
                timeLabelTextStyle: Theme.of(context).textTheme.bodySmall!
                    .copyWith(fontFamily: 'Noto'),
              ),
            ),
            const SizedBox(width: Dimens.marginLarge),
          ],
        );
      },
    );
  }
}
