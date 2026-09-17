import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:mvskoke_language_app/models/enums.dart';
import 'package:path_provider/path_provider.dart';

Logger logger = Logger();

/// A simplified version of the player state.
///
enum AudioPlayerState { loading, playing, paused, completed }

///
/// Don't instantiate this class directly.
/// Only access the audio player service through getIt.
/// Example: AudioPlayerService player = getIt`<AudioPlayerService`>();
///
/// @link https://suragch.medium.com/background-audio-in-flutter-with-audio-service-and-just-audio-3cce17b4a7d
///
class AudioPlayerService extends BaseAudioHandler {
  /// The duration for the current media item.
  ///
  ValueNotifier<Duration> currentItemDuration = ValueNotifier<Duration>(
    Duration.zero,
  );

  /// The audio player instance.
  ///
  final _player = AudioPlayer();

  late final Uri albumArtUri;

  bool get hasNext => _player.hasNext;
  bool get hasPrevious => _player.hasPrevious;

  /// The audio player service constructor.
  ///
  AudioPlayerService() {
    _notifyAudioHandlerAboutPlaybackEvents();
    _listenForDurationChanges();
    _initAlbumArt();
  }

  /// Initializes the audio player service.
  ///
  Future<AudioPlayerService> init() async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    final String channelId = "${packageInfo.packageName}.audio";
    return await AudioService.init(
      builder: () => AudioPlayerService(),
      config: AudioServiceConfig(
        androidNotificationChannelId: channelId,
        // Replace with your app's package name
        androidNotificationChannelName: 'Audio playback',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        androidShowNotificationBadge: true,
        androidNotificationIcon: 'mipmap/ic_launcher',
      ),
    );
  }

  /// Clear the current audio sources.
  ///
  Future<void> clear() async {
    // return await _player.clear();
  }

  /// Play the audio.
  ///
  @override
  Future<void> play() async => _player.play();

  /// Pause the audio.
  ///
  @override
  Future<void> pause() async => _player.pause();

  /// Seek to a specific position in the audio.
  ///
  /// [position] the position to seek to.
  ///
  @override
  Future<void> seek(Duration? position, {int? index}) async =>
      _player.seek(position, index: index);

  /// Stop and dispose the audio player.
  ///
  @override
  Future<void> stop() async {
    _player.stop();
    return super.stop();
  }

  /// Dispose of the audio player.
  ///
  Future<void> dispose() async => _player.dispose();

  /// Subscribe to player state updates.
  ///
  /// [onPlayerStateUpdate] the callback function to call on player state updates.
  ///
  /// Returns a [StreamSubscription] that can be used to cancel the subscription.
  ///
  StreamSubscription<PlayerState> subscribeToPlayerState(
    Function(AudioPlayerState) onPlayerStateUpdate,
  ) {
    return _player.playerStateStream.listen((event) {
      AudioPlayerState newState = AudioPlayerState.loading;
      // Handle completed state first
      if (event.processingState == ProcessingState.completed) {
        newState = AudioPlayerState.completed;
      }
      // Handle playing state next
      else if (event.playing) {
        newState = AudioPlayerState.playing;
      }
      // Handle other states based on processing state
      else {
        switch (event.processingState) {
          case ProcessingState.idle:
          case ProcessingState.loading:
          case ProcessingState.buffering:
            newState = AudioPlayerState.loading;
            break;
          case ProcessingState.ready:
            newState = AudioPlayerState.paused;
            break;
          case ProcessingState.completed:
            newState = AudioPlayerState.completed;
            break;
        }
      }
      onPlayerStateUpdate(newState);
    });
  }

  /// Subscribe to position updates.
  ///
  /// [onPositionUpdate] the callback function to call on position updates.
  ///
  /// Returns a [StreamSubscription] that can be used to cancel the subscription.
  ///
  StreamSubscription<Duration> subscribeToPositionUpdates(
    Function(Duration) onPositionUpdate,
  ) {
    return _player.positionStream.listen(onPositionUpdate);
  }

  /// Set the asset path for the audio.
  ///
  /// [assetPath] the path to the audio asset.
  /// [package] the package name of the asset.
  /// [preload] whether to preload the audio. (default: true)
  /// [initialPosition] the initial position to start playing from.
  ///
  /// Returns the duration of the audio.
  ///
  Future<Duration?> setAsset(
    String assetPath, {
    String? package,
    bool preload = true,
    Duration? initialPosition,
  }) async {
    return _player.setAsset(
      assetPath,
      package: package,
      preload: preload,
      initialPosition: initialPosition,
    );
  }

  @override
  Future<void> playFromUri(Uri uri, [Map<String, dynamic>? extras]) async {
    MediaItem mediaItem = MediaItem(
      id: extras?['id'].toString() ?? '-1',
      album: extras?['album'] ?? '',
      title: extras?['title'] ?? '',
      artUri: albumArtUri,
      extras: {'location': extras?['location'] ?? AssetLocation.remote.name},
    );

    // if player is playing, stop it
    if (_player.playing || _player.processingState == ProcessingState.ready) {
      await _player.stop();
    }

    // Check if the URI is for the test file
    if (uri.toString().contains('assets/audio/Test.mp3')) {
      await _player.setAsset('assets/audio/Test.mp3');
      queue.value.clear();
      queue.add([mediaItem]);
      await _player.load();
      play();
      return;
    }

    // Default
    _player.setAudioSource(_createAudioSource(uri, mediaItem));
    queue.value.clear();
    queue.add([mediaItem]);
    await _player.load();
    play();
    return;
  }

  AudioSource _createAudioSource(Uri uri, MediaItem mediaItem) {
    AssetLocation location = AssetLocation.values.byName(
      mediaItem.extras?['location'],
    );

    switch (location) {
      case AssetLocation.asset:
        return AudioSource.asset(uri.toString(), tag: mediaItem); // asset path
      case AssetLocation.local:
        return AudioSource.uri(uri, tag: mediaItem); // local file URI
      case AssetLocation.remote:
        return AudioSource.uri(uri, tag: mediaItem);
    }
  }

  Future<void> _initAlbumArt() async {
    // get application directory
    final appDir = await getApplicationDocumentsDirectory();
    // use the app logo as the album art
    const artPath = 'assets/images/icon.png';
    // write the asset to the application directory
    final file = File('${appDir.path}/icon.png');
    // write the file
    await file.writeAsBytes(
      (await rootBundle.load(artPath)).buffer.asUint8List(),
    );
    albumArtUri = file.uri;
    return;
  }

  /// Get the file Uri from the given string. This specifically fixes an issue with
  /// iOS where the file Uri is not recognized correctly.
  ///
  /// [uriString] the string to convert to a Uri.
  ///
  /// Returns a [Uri] object.
  ///
  // Uri _getUri(String uriString) {
  //   if (uriString.startsWith('/')) {
  //     // This is a local file path - convert to a file:// URI
  //     return Uri.file(uriString);
  //   }
  //   return Uri.parse(uriString);
  // }

  void _listenForDurationChanges() {
    _player.durationStream.listen((duration) {
      var index = _player.currentIndex;
      final newQueue = queue.value;
      if (index == null || newQueue.isEmpty) return;
      final oldMediaItem = newQueue[index];
      final newMediaItem = oldMediaItem.copyWith(duration: duration);
      newQueue[index] = newMediaItem;
      queue.add(newQueue);
      mediaItem.add(newMediaItem);
    });
  }

  /// Notify the audio handler about playback events.
  ///
  void _notifyAudioHandlerAboutPlaybackEvents() {
    _player.playbackEventStream.listen((PlaybackEvent event) {
      final playing = _player.playing;
      playbackState.add(
        playbackState.value.copyWith(
          androidCompactActionIndices: const [0, 1, 3],
          controls: Platform.isAndroid
              ? [
                  MediaControl.skipToPrevious,
                  if (playing) MediaControl.pause else MediaControl.play,
                  MediaControl.rewind,
                  MediaControl.fastForward,
                  MediaControl.skipToNext,
                ]
              : [
                  MediaControl.skipToPrevious,
                  if (playing) MediaControl.pause else MediaControl.play,
                  MediaControl.skipToNext,
                ],
          systemActions: {MediaAction.seek},
          playing: playing,
          processingState: const {
            ProcessingState.idle: AudioProcessingState.idle,
            ProcessingState.loading: AudioProcessingState.loading,
            ProcessingState.buffering: AudioProcessingState.buffering,
            ProcessingState.ready: AudioProcessingState.ready,
            ProcessingState.completed: AudioProcessingState.completed,
          }[_player.processingState]!,
          updatePosition: _player.position,
          bufferedPosition: _player.bufferedPosition,
          speed: _player.speed,
          queueIndex: event.currentIndex,
        ),
      );
    });
  }
}
