import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:logger/logger.dart';
import 'package:readalong/readalong.dart';

Logger log = Logger();

class VimeoPlaybackController implements PlaybackController {
  VimeoPlaybackController({this.initialPosition = Duration.zero})
    : _position = initialPosition,
      _initialPositionSeekPending = initialPosition > Duration.zero;

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

  void handlePlayerEvent(Object? event) {
    if (_disposed || event is! Map) return;
    final type = event['type'];
    if (type == 'time' ||
        type == 'loaded' ||
        type == 'ready' ||
        type == 'seeked' ||
        type == 'ended') {
      final seconds = _number(event['seconds']);
      final position = seconds == null
          ? null
          : Duration(milliseconds: (seconds * 1000).round());
      if (type == 'seeked' ||
          (type == 'time' &&
              position != null &&
              position >= initialPosition)) {
        _initialPositionSeekPending = false;
      }
      final isStaleInitialPosition =
          initialPosition > Duration.zero &&
          ((type == 'loaded' || type == 'ready') ||
              (type == 'time' &&
                  _initialPositionSeekPending &&
                  position != null &&
                  position < initialPosition));
      if (seconds != null &&
          !isStaleInitialPosition) {
        _position = position!;
        _positionEvents.add(_position);
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
        if (initialPosition > Duration.zero && !_restoredInitialPosition) {
          _restoredInitialPosition = true;
          unawaited(_restoreInitialPosition());
        } else {
          _updateState(PlayerState(false, ProcessingState.ready));
        }
      case 'play':
        if (initialPosition > Duration.zero && !_restoredInitialPosition) {
          _restoredInitialPosition = true;
          unawaited(_restoreInitialPosition());
        }
        _updateState(PlayerState(true, ProcessingState.ready));
      case 'pause':
        _updateState(PlayerState(false, ProcessingState.ready));
      case 'bufferstart':
        _updateState(PlayerState(_state.playing, ProcessingState.buffering));
      case 'bufferend':
        _updateState(PlayerState(_state.playing, ProcessingState.ready));
      case 'ended':
        _updateState(PlayerState(false, ProcessingState.completed));
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
    if (!_disposed) {
      _updateState(PlayerState(false, ProcessingState.ready));
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
    final argument = value == null ? '' : ',${jsonEncode(value)}';
    await webView.evaluateJavascript(
      source:
          'if (window.readAlongVimeo && window.readAlongVimeo.$command) { window.readAlongVimeo.$command($argument); }',
    );
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
  Future<void> seek(Duration position) =>
      _run('seek', position.inMilliseconds / 1000);

  @override
  Future<void> setSpeed(double speed) async {
    await _run('setSpeed', speed);
    _speed = speed;
  }

  Future<void> dispose() async {
    _disposed = true;
    _webViewController = null;
    await _positionEvents.close();
    await _durationEvents.close();
    await _stateEvents.close();
  }
}

class VimeoPlayer extends StatelessWidget {
  const VimeoPlayer({
    super.key,
    required this.embedUrl,
    required this.controller,
  });

  final String embedUrl;
  final VimeoPlaybackController controller;

  String get _playerHtml {
    final initialSeconds = controller.initialPosition.inSeconds;
    final urlWithFragment = initialSeconds > 0 && !embedUrl.contains('#')
        ? '$embedUrl#t=${initialSeconds}s'
        : embedUrl;
    final safeUrl = jsonEncode(urlWithFragment);
    final safeInitialSeconds = initialSeconds > 0 ? initialSeconds : 0;
    return '''
<!doctype html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    html, body, #player { margin: 0; width: 100%; height: 100%; overflow: hidden; background: #000; }
    iframe { width: 100%; height: 100%; border: 0; }
  </style>
</head>
<body>
  <div id="player"></div>
  <script src="https://player.vimeo.com/api/player.js"></script>
  <script>
    const iframe = document.createElement('iframe');
    iframe.src = $safeUrl;
    iframe.allow = 'autoplay; fullscreen; picture-in-picture; encrypted-media';
    iframe.allowFullscreen = true;
    iframe.setAttribute('playsinline', '');
    document.getElementById('player').appendChild(iframe);

    const player = new Vimeo.Player(iframe);
    const initialPositionSeconds = $safeInitialSeconds;
    let initialSeekPerformed = false;

    function send(type, details = {}) {
      if (window.flutter_inappwebview) {
        window.flutter_inappwebview.callHandler(
          'readAlongVimeoEvent',
          Object.assign({type: type}, details)
        );
      }
    }

    function checkAndRestorePosition() {
      if (!initialSeekPerformed && initialPositionSeconds > 0) {
        initialSeekPerformed = true;
        player.setCurrentTime(initialPositionSeconds).catch(function(err) {
          console.warn('setCurrentTime failed', err);
        });
      }
    }

    window.readAlongVimeo = {
      play: () => player.play(),
      pause: () => player.pause(),
      seek: (seconds) => player.setCurrentTime(seconds),
      setSpeed: (rate) => player.setPlaybackRate(rate)
    };

    function notifyReady() {
      Promise.all([
        player.getDuration(),
        player.getCurrentTime()
      ]).then(([duration, seconds]) => {
        checkAndRestorePosition();
        send('ready', {
          duration: duration,
          seconds: initialPositionSeconds > 0 ? Math.max(seconds, initialPositionSeconds) : seconds
        });
      }).catch((e) => send('error', {message: e.message}));
    }

    player.ready().then(notifyReady);
    player.on('loaded', notifyReady);

    player.on('play', () => {
      checkAndRestorePosition();
      send('play');
    });
    player.on('pause', () => send('pause'));
    player.on('bufferstart', () => send('bufferstart'));
    player.on('bufferend', () => send('bufferend'));
    player.on('timeupdate', (data) => send('time', {
      seconds: data.seconds,
      duration: data.duration
    }));
    player.on('seeked', (data) => send('seeked', {
      seconds: data.seconds,
      duration: data.duration
    }));
    player.on('ended', () => player.getDuration().then(
      (duration) => send('ended', {seconds: duration, duration: duration})
    ));
    player.on('error', (error) => send('error', {message: error.message}));
  </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: InAppWebView(
        initialData: InAppWebViewInitialData(data: _playerHtml),
        initialSettings: InAppWebViewSettings(
          allowsInlineMediaPlayback: true,
          mediaPlaybackRequiresUserGesture: true,
        ),
        onWebViewCreated: (webViewController) {
          webViewController.addJavaScriptHandler(
            handlerName: 'readAlongVimeoEvent',
            callback: (arguments) {
              if (arguments.isNotEmpty) {
                controller.handlePlayerEvent(arguments.first);
              }
              return null;
            },
          );
          controller.attach(webViewController);
        },
      ),
    );
  }
}
