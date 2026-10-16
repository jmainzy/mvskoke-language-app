import 'dart:async';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:mvskoke_language_app/managers/audio_manager.dart';
import 'package:mvskoke_language_app/models/enums.dart';
import 'package:mvskoke_language_app/models/media_item.dart';
import 'package:mvskoke_language_app/notifiers/play_button_notifier.dart';
import 'package:mvskoke_language_app/notifiers/progress_notifier.dart';
import 'package:mvskoke_language_app/services/service_locator.dart';
import 'package:mvskoke_language_app/utilities/dimens.dart';

/// Displays inline audio player
class MiniAudioWidget extends StatefulWidget {
  final MediaObject mediaItem;

  const MiniAudioWidget({
    required this.mediaItem,
    super.key,
  });

  @override
  State<MiniAudioWidget> createState() => _MiniAudioWidgetState();
}

class _MiniAudioWidgetState extends State<MiniAudioWidget> {
  Logger logger = Logger();

  Future<void>? initAudioFuture;
  late MediaObject currentMedia;

  @override
  void initState() {
    super.initState();
    currentMedia = widget.mediaItem;
  }

  Future<void> initializeAudio() async {
    var (Uri uri, AssetLocation location) =
        await sl<AudioManager>().getAudioUri(currentMedia);
    if (!mounted) return;
    initAudioFuture = sl<AudioManager>().setMedia(
      uri,
      location: location,
      id: currentMedia.id,
      title: currentMedia.title ?? '',
      album: 'Mvskoke Opunvkv',
    );
    setState(() {});
    return;
  }

  @override
  Widget build(BuildContext context) {
    // final dm = sl<DownloadManager>();
    // final filename = widget.mediaItem?.filename;

    return Material(
        child: Container(
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
                padding: EdgeInsetsGeometry.only(right: Dimens.marginShort),
                child: initAudioFuture != null
                    ? FutureBuilder<void>(
                        future: initAudioFuture,
                        builder: (context, snapshot) {
                          return Column(
                            children: [
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) ...[
                                const _LoadingWidget(),
                              ] else if (snapshot.hasError) ...[
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                          vertical: Dimens.marginLarge),
                                      child: Icon(Icons.error),
                                    ),
                                  ],
                                )
                              ] else ...[
                                _PlayerControls(),
                              ],
                            ],
                          );
                        })
                    : _UnloadedWidget(onPressed: () {
                        initializeAudio();
                      }))));
  }

  @override
  void dispose() {
    sl<AudioManager>().stop();
    super.dispose();
  }
}

class _UnloadedWidget extends StatelessWidget {
  final VoidCallback onPressed;
  const _UnloadedWidget({required this.onPressed});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      IconButton(
          onPressed: () => onPressed.call(),
          icon: Icon(
            Icons.play_arrow,
          )),
      Expanded(child: LinearProgressIndicator(value: 0))
    ]);
  }
}

class _LoadingWidget extends StatelessWidget {
  const _LoadingWidget();
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Padding(
          padding: EdgeInsetsGeometry.all(15.0),
          child: Icon(
            Icons.play_arrow,
            color: Colors.grey,
          )),
      Expanded(child: LinearProgressIndicator())
    ]);
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
            PlayButton(),
            Expanded(
              child: ProgressBar(
                progress: value.current,
                buffered: value.buffered,
                total: value.total,
                onSeek: audioManager.seek,
                timeLabelLocation: TimeLabelLocation.sides,
                timeLabelTextStyle: Theme.of(
                  context,
                ).textTheme.bodySmall!.copyWith(fontFamily: 'Noto'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class PlayButton extends StatelessWidget {
  const PlayButton({super.key});
  @override
  Widget build(BuildContext context) {
    final pageManager = sl<AudioManager>();
    return ValueListenableBuilder<ButtonState>(
      valueListenable: pageManager.playButtonNotifier,
      builder: (_, value, _) {
        switch (value) {
          case ButtonState.playingLoading:
          case ButtonState.pausedLoading:
            return Container(
              margin: const EdgeInsets.all(8.0),
              width: 32.0,
              height: 32.0,
              child: const CircularProgressIndicator(),
            );
          case ButtonState.completed:
            return IconButton(
              icon: const Icon(Icons.replay),
              onPressed: pageManager.replay,
            );
          case ButtonState.paused:
            return IconButton(
              icon: const Icon(Icons.play_arrow, size: Dimens.playButtonSize),
              onPressed: pageManager.play,
            );
          case ButtonState.playing:
            return IconButton(
              icon: const Icon(Icons.pause),
              onPressed: pageManager.pause,
            );
        }
      },
    );
  }
}