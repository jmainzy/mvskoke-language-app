import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:logger/logger.dart';
import 'package:readalong/readalong.dart';
import 'package:vimeo_video_player/vimeo_video_player.dart';

import 'vimeo_duration_stream_stub.dart'
    if (dart.library.js_interop) 'vimeo_duration_stream_web.dart'
    as duration_stream;

Logger log = Logger();

class VimeoPlaybackController implements PlaybackController {
  VimeoPlaybackController({this.initialPosition = Duration.zero})
    : _position = initialPosition,
      _initialPositionSeekPending = initialPosition > Duration.zero {
    _durationMessageSubscription = duration_stream.vimeoDurationStream().listen(
      handleDuration,
    );
  }

  final Duration initialPosition;
  final StreamController<Duration> _positionEvents =
      StreamController<Duration>.broadcast(sync: true);
  final StreamController<Duration?> _durationEvents =
      StreamController<Duration?>.broadcast(sync: true);
  final StreamController<PlayerState> _stateEvents =
      StreamController<PlayerState>.broadcast(sync: true);

  InAppWebViewController? _webViewController;
  Duration _position = Duration.zero;
  Duration? _duration;
  double _speed = 1;
  PlayerState _state = PlayerState(false, ProcessingState.loading);
  bool _disposed = false;
  bool _restoredInitialPosition = false;
  bool _initialPositionSeekPending;
  StreamSubscription<double>? _durationMessageSubscription;
  Completer<void>? _durationResponse;

  @override
  Duration get position => _position;

  @override
  Duration? get duration => _duration;

  @override
  double get speed => _speed;

  @override
  PlayerState get state => _state;

  @override
  Stream<Duration> get positionStream => _positionEvents.stream;

  @override
  Stream<Duration?> get durationStream => _durationEvents.stream;

  @override
  Stream<PlayerState> get stateStream => _stateEvents.stream;

  void attach(InAppWebViewController controller) {
    _webViewController = controller;
  }

  void handleReady() {
    if (_disposed) return;
    if (initialPosition > Duration.zero && !_restoredInitialPosition) {
      _restoredInitialPosition = true;
      unawaited(_restoreInitialPosition());
    } else {
      _updateState(PlayerState(false, ProcessingState.ready));
      unawaited(_refreshDuration());
    }
  }

  void handlePosition(double seconds) {
    if (_disposed || !seconds.isFinite || seconds < 0) return;
    final position = Duration(milliseconds: (seconds * 1000).round());
    if (_initialPositionSeekPending && position < initialPosition) return;
    _initialPositionSeekPending = false;
    _position = position;
    _positionEvents.add(position);
  }

  void handleDuration(double seconds) {
    if (_disposed || !seconds.isFinite || seconds < 0) return;
    _duration = Duration(milliseconds: (seconds * 1000).round());
    _durationEvents.add(_duration);
    final response = _durationResponse;
    if (response != null && !response.isCompleted) response.complete();
  }

  void handlePlay() {
    if (_disposed) return;
    _updateState(PlayerState(true, ProcessingState.ready));
  }

  void handlePause() {
    if (!_disposed) {
      _updateState(PlayerState(false, ProcessingState.ready));
    }
  }

  void handleEnded() {
    if (!_disposed) {
      _updateState(PlayerState(false, ProcessingState.completed));
    }
  }

  void handlePlayerEvent(Object? event) {
    if (_disposed) return;
    if (event is String) {
      if (event.startsWith('currentPosition:')) {
        final seconds = _number(event.substring('currentPosition:'.length));
        if (seconds != null) handlePosition(seconds);
        return;
      }
      switch (event) {
        case 'onReady':
          handleReady();
        case 'onPlay':
          handlePlay();
        case 'onPause':
          handlePause();
        case 'onFinish':
          handleEnded();
      }
      return;
    }
    if (event is! Map) return;
    final type = event['type'];
    if (type == 'time' ||
        type == 'loaded' ||
        type == 'ready' ||
        type == 'seeked' ||
        type == 'ended') {
      final seconds = _number(event['seconds']);
      final isStaleInitialPosition =
          initialPosition > Duration.zero &&
          ((type == 'loaded' || type == 'ready') ||
              (type == 'time' &&
                  _initialPositionSeekPending &&
                  seconds != null &&
                  Duration(milliseconds: (seconds * 1000).round()) <
                      initialPosition));
      if (seconds != null && !isStaleInitialPosition) {
        handlePosition(seconds);
      }
      final durationSeconds = _number(event['duration']);
      if (durationSeconds != null) {
        _duration = Duration(milliseconds: (durationSeconds * 1000).round());
        _durationEvents.add(_duration);
      }
    }

    switch (type) {
      case 'ready':
      case 'loaded':
        handleReady();
      case 'play':
        handlePlay();
      case 'pause':
        handlePause();
      case 'bufferstart':
        _updateState(PlayerState(_state.playing, ProcessingState.buffering));
      case 'bufferend':
        _updateState(PlayerState(_state.playing, ProcessingState.ready));
      case 'ended':
        handleEnded();
      case 'error':
        _updateState(PlayerState(false, ProcessingState.idle));
    }
  }

  Future<void> _restoreInitialPosition() async {
    final duration = _duration;
    final target = duration == null
        ? initialPosition
        : Duration(
            milliseconds: initialPosition.inMilliseconds
                .clamp(0, duration.inMilliseconds)
                .toInt(),
          );
    _position = target;
    _positionEvents.add(target);
    try {
      await _run('seek', target.inMilliseconds / 1000);
    } catch (error, stackTrace) {
      log.e(
        'Unable to restore Vimeo playback position',
        error: error,
        stackTrace: stackTrace,
      );
    }
    unawaited(_refreshDuration());
    if (!_disposed) {
      _updateState(PlayerState(_state.playing, ProcessingState.ready));
    }
  }

  Future<void> _refreshDuration() async {
    final webView = _webViewController;
    if (webView == null || _disposed) return;
    try {
      if (kIsWeb) {
        final response = Completer<void>();
        _durationResponse = response;
        try {
          await webView.evaluateJavascript(
            source: '''
              player.getDuration().then(function(seconds) {
                window.parent.postMessage(
                  {readAlongVimeoDuration: seconds},
                  '*'
                );
              }).catch(function(error) {
                console.error('Unable to read Vimeo video duration', error);
              });
            ''',
          );
          await response.future.timeout(const Duration(seconds: 3));
        } on TimeoutException {
          log.w('Timed out while reading Vimeo video duration on web');
        } finally {
          if (identical(_durationResponse, response)) {
            _durationResponse = null;
          }
        }
        return;
      }

      final result = await webView.callAsyncJavaScript(
        functionBody: 'return await player.getDuration();',
      );
      if (result?.error != null) {
        throw StateError(result!.error!);
      }
      final seconds = _number(result?.value);
      if (seconds != null && seconds >= 0 && !_disposed) {
        _duration = Duration(milliseconds: (seconds * 1000).round());
        _durationEvents.add(_duration);
      }
    } catch (error, stackTrace) {
      log.e(
        'Unable to read Vimeo video duration',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _updateState(PlayerState state) {
    _state = state;
    _stateEvents.add(state);
  }

  double? _number(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value');

  Future<void> _run(String command, [Object? value]) async {
    final webView = _webViewController;
    if (webView == null) {
      log.w('run($command) called but Vimeo player not ready yet');
      return;
    }
    final functionBody = switch (command) {
      'play' => 'return await player.play();',
      'pause' => 'return await player.pause();',
      'seek' => 'return await player.setCurrentTime(seconds);',
      'setSpeed' => 'return await player.setPlaybackRate(speed);',
      _ => throw ArgumentError.value(command, 'command'),
    };
    if (kIsWeb) {
      final javascriptCall = switch (command) {
        'play' => 'player.play()',
        'pause' => 'player.pause()',
        'seek' => 'player.setCurrentTime(${jsonEncode(value)})',
        'setSpeed' => 'player.setPlaybackRate(${jsonEncode(value)})',
        _ => throw ArgumentError.value(command, 'command'),
      };
      await webView.evaluateJavascript(
        source:
            '''
          (function() {
            var result = $javascriptCall;
            if (result && typeof result.catch === 'function') {
              result.catch(function(error) {
                console.error('Vimeo $command failed', error);
              });
            }
          })();
        ''',
      );
      return;
    }

    final result = await webView.callAsyncJavaScript(
      functionBody: functionBody,
      arguments: {
        if (command == 'seek') 'seconds': value,
        if (command == 'setSpeed') 'speed': value,
      },
    );
    if (result?.error != null) {
      throw StateError('Vimeo $command failed: ${result!.error}');
    }
  }

  @override
  Future<void> play() => _run('play');

  @override
  Future<void> pause() => _run('pause');

  @override
  Future<void> stop() async {
    await pause();
    await seek(Duration.zero);
  }

  @override
  Future<void> seek(Duration position) async {
    _initialPositionSeekPending = false;
    _position = position;
    _positionEvents.add(position);
    await _run('seek', position.inMilliseconds / 1000);
  }

  @override
  Future<void> setSpeed(double speed) async {
    await _run('setSpeed', speed);
    _speed = speed;
  }

  Future<void> dispose() async {
    _disposed = true;
    _webViewController = null;
    await _durationMessageSubscription?.cancel();
    await _positionEvents.close();
    await _durationEvents.close();
    await _stateEvents.close();
  }
}

String _extractVideoId(String url) {
  final match = RegExp(r'vimeo\.com/(?:.*?/)?(\d+)').firstMatch(url);
  if (match != null && match.groupCount >= 1) {
    return match.group(1)!;
  }
  throw ArgumentError('Invalid Vimeo URL: $url');
}

class VideoPlayer extends StatelessWidget {
  const VideoPlayer({super.key, required this.url, required this.controller});

  final String url;
  final VimeoPlaybackController controller;

  @override
  Widget build(BuildContext context) {
    final videoId = _extractVideoId(url);
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: VimeoVideoPlayer(
        videoId: videoId,
        isAutoPlay: true,
        initialPositionInSeconds: controller.initialPosition.inSeconds > 0
            ? controller.initialPosition.inSeconds
            : null,
        onReady: controller.handleReady,
        onPlay: controller.handlePlay,
        onPause: controller.handlePause,
        onFinish: controller.handleEnded,
        currentPositionInSeconds: controller.handlePosition,
        onInAppWebViewCreated: (webViewController) {
          controller.attach(webViewController);
        },
      ),
    );
  }
}
