import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvskoke_language_app/ui/components/video_player.dart';
import 'package:readalong/readalong.dart';
import 'package:vimeo_video_player/vimeo_video_player.dart';

void main() {
  testWidgets('passes the saved position to the Vimeo player', (tester) async {
    final controller = VimeoPlaybackController(
      initialPosition: const Duration(seconds: 45),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: VideoPlayer(
          url: 'https://vimeo.com/253875203',
          controller: controller,
        ),
      ),
    );

    final vimeoPlayer = tester.widget<VimeoVideoPlayer>(
      find.byType(VimeoVideoPlayer),
    );
    expect(vimeoPlayer.initialPositionInSeconds, 45);
  });

  test('initializes with initial position', () {
    final controller = VimeoPlaybackController(
      initialPosition: const Duration(seconds: 45),
    );

    expect(controller.position, const Duration(seconds: 45));
    expect(controller.initialPosition, const Duration(seconds: 45));
  });

  test('ready and loaded events preserve initial position', () {
    final controller = VimeoPlaybackController(
      initialPosition: const Duration(seconds: 45),
    );

    final positions = <Duration>[];
    controller.positionStream.listen(positions.add);

    // Vimeo sends loaded/ready with current time = 0 before seeking
    controller.handlePlayerEvent({
      'type': 'ready',
      'duration': 180,
      'seconds': 0,
    });

    expect(controller.duration, const Duration(seconds: 180));
    expect(controller.position, const Duration(seconds: 45));

    // Subsequent normal time update
    controller.handlePlayerEvent({
      'type': 'time',
      'duration': 180,
      'seconds': 46.5,
    });

    expect(controller.position, const Duration(milliseconds: 46500));
  });

  test('state updates on play, pause, ended', () {
    final controller = VimeoPlaybackController();

    final states = <PlayerState>[];
    controller.stateStream.listen(states.add);

    controller.handlePlayerEvent({'type': 'play'});
    expect(controller.state.playing, isTrue);

    controller.handlePlayerEvent({'type': 'pause'});
    expect(controller.state.playing, isFalse);

    controller.handlePlayerEvent({
      'type': 'ended',
      'duration': 100,
      'seconds': 100,
    });
    expect(controller.state.processingState, ProcessingState.completed);
  });

  test('handles event strings emitted by vimeo_video_player', () {
    final controller = VimeoPlaybackController();

    controller.handlePlayerEvent('onReady');
    expect(controller.state.processingState, ProcessingState.ready);

    controller.handlePlayerEvent('currentPosition:46.5');
    expect(controller.position, const Duration(milliseconds: 46500));

    controller.handlePlayerEvent('onPlay');
    expect(controller.state.playing, isTrue);

    controller.handlePlayerEvent('onPause');
    expect(controller.state.playing, isFalse);

    controller.handlePlayerEvent('onFinish');
    expect(controller.state.processingState, ProcessingState.completed);
  });

  test('updates duration from the web player message bridge', () {
    final controller = VimeoPlaybackController();

    controller.handleDuration(180);

    expect(controller.duration, const Duration(minutes: 3));
  });
}
