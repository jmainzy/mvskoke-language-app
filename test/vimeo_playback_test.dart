import 'package:flutter_test/flutter_test.dart';
import 'package:mvskoke_language_app/ui/components/vimeo_player.dart';
import 'package:readalong/readalong.dart';

void main() {
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
    final controller = VimeoPlaybackController(
      initialPosition: const Duration(seconds: 10),
    );

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
}
