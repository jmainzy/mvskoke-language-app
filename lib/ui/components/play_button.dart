
import 'package:flutter/material.dart';
import 'package:mvskoke_language_app/managers/audio_manager.dart';
import 'package:mvskoke_language_app/notifiers/play_button_notifier.dart';
import 'package:mvskoke_language_app/services/service_locator.dart';
import 'package:mvskoke_language_app/utilities/dimens.dart';

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