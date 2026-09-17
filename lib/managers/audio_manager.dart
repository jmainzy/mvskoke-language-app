import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mvskoke_language_app/models/enums.dart';
import 'package:mvskoke_language_app/models/media_item.dart';
import 'package:mvskoke_language_app/notifiers/play_button_notifier.dart';
import 'package:mvskoke_language_app/notifiers/progress_notifier.dart';
import 'package:mvskoke_language_app/services/audio_player_service.dart';
import 'package:mvskoke_language_app/services/service_locator.dart';

/// Manager for handling audio playback and media items, e.g. playlists.
class AudioManager {
  final _audioService = sl<AudioPlayerService>();

  // Listeners: Updates going to the UI
  final playButtonNotifier = PlayButtonNotifier();
  final progressNotifier = ProgressNotifier();
  final currentSongTitleNotifier = ValueNotifier<String>('');
  final currentMedia = ValueNotifier<MediaItem?>(null);
  // final speedNotifier = SpeedNotifier();

  // Events: Calls coming from the UI
  Future<AudioManager> init() async {
    _listenToPlaybackState();
    _listenToCurrentPosition();
    _listenToBufferedPosition();
    _listenToTotalDuration();
    _listenToChangesInSong();
    return this;
  }

  void play() => _audioService.play();
  void replay() {
    _audioService.seek(Duration.zero);
    _audioService.play();
  }

  void pause() => _audioService.pause();
  void stop() => _audioService.stop();
  void seek(Duration position) => _audioService.seek(position);

  void skipBack() {
    // Seek back 10 seconds
    _audioService.rewind();
  }

  void skipForward() {
    // Seek forward 10 seconds
    _audioService.fastForward();
  }

  /// Loads audio items and sets the audio service with the media items.
  ///
  Future<void> setMedia(
    Uri uri, {
    required AssetLocation location,
    required String id,
    required String title,
    required String album,
  }) async {
    await _audioService.playFromUri(uri, {
      'id': id,
      'location': location.name,
      'title': title,
      'album': album,
    });
    return;
  }

  void _listenToPlaybackState() {
    _audioService.playbackState.listen((playbackState) {
      final isPlaying = playbackState.playing;
      final processingState = playbackState.processingState;
      if (processingState == AudioProcessingState.loading ||
          processingState == AudioProcessingState.buffering) {
        switch (playButtonNotifier.value) {
          case ButtonState.playing:
          case ButtonState.playingLoading:
            playButtonNotifier.value = ButtonState.playingLoading;
            break;
          case ButtonState.completed:
          case ButtonState.paused:
          case ButtonState.pausedLoading:
            playButtonNotifier.value = ButtonState.pausedLoading;
            break;
        }
      } else if (!isPlaying) {
        playButtonNotifier.value = ButtonState.paused;
      } else if (processingState != AudioProcessingState.completed) {
        playButtonNotifier.value = ButtonState.playing;
      } else {
        playButtonNotifier.value = ButtonState.completed;
      }
    });
  }

  void _listenToCurrentPosition() {
    AudioService.position.listen((position) {
      final oldState = progressNotifier.value;
      progressNotifier.value = ProgressBarState(
        current: position,
        buffered: oldState.buffered,
        total: oldState.total,
      );
    });
  }

  void _listenToBufferedPosition() {
    _audioService.playbackState.listen((playbackState) {
      final oldState = progressNotifier.value;
      progressNotifier.value = ProgressBarState(
        current: oldState.current,
        buffered: playbackState.bufferedPosition,
        total: oldState.total,
      );
    });
  }

  void _listenToTotalDuration() {
    _audioService.mediaItem.listen((mediaItem) {
      final oldState = progressNotifier.value;
      progressNotifier.value = ProgressBarState(
        current: oldState.current,
        buffered: oldState.buffered,
        total: mediaItem?.duration ?? Duration.zero,
      );
    });
  }

  void _listenToChangesInSong() {
    _audioService.mediaItem.listen((mediaItem) {
      currentSongTitleNotifier.value = mediaItem?.title ?? '';
      currentMedia.value = mediaItem;
    });
  }

  Future<(Uri, AssetLocation)> getAudioUri(MediaObject item) async {
    String? localUri = await findInAssets(item);
    if (localUri != null) {
      return (Uri(path: localUri), AssetLocation.asset);
    } else {
      var uri = getAudioUrl(item);
      return (uri, AssetLocation.remote);
    }
  }

  Future<String?> findInAssets(MediaObject item) async {
    var filename = 'assets/audio/${item.filename}';
    try {
      await rootBundle.load(filename);
    } catch (e) {
      logger.i('file not found locally $filename');
      return null;
    }
    return filename;
  }

  Uri getAudioUrl(MediaObject item) {
    // return webService!.getAudioUrl(item.filename);
    return Uri.parse('https://example.com/audio/${item.filename}');
  }
}
