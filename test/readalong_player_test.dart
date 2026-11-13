import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvskoke_language_app/ui/components/vimeo_player.dart';
import 'package:readalong/readalong.dart';

void main() {
  testWidgets('loads and displays the bundled Chipbear ReadAlong file', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          height: 600,
          child: ReadAlong(xmlAsset: 'assets/readalongs/chipbear.readalong'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(ReadAlong), findsOneWidget);
    expect(find.textContaining('Nere'), findsWidgets);
    expect(find.textContaining('A night and day story'), findsOneWidget);
    expect(find.textContaining('Unable to load ReadAlong XML'), findsNothing);
  });

  testWidgets('renders example page graphics from the images folder', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          height: 800,
          child: ReadAlong(
            xmlAsset: 'assets/readalongs/example.readalong',
            imagesFolder: 'assets/images',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(find.textContaining('Unable to load page image'), findsNothing);
  });

  testWidgets(
    'loads mus16051.eaf with playback controller and highlights active sentence',
    (tester) async {
      final controller = VimeoPlaybackController(
        initialPosition: const Duration(seconds: 10),
      );
      final xml = File('assets/readalongs/mus16051.eaf').readAsStringSync();
      ReadAlongPosition? lastPosition;

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            height: 800,
            child: ReadAlong(
              xml: xml,
              playbackController: controller,
              onPositionChanged: (pos) => lastPosition = pos,
            ),
          ),
        ),
      );
      for (
        var i = 0;
        i < 10 && find.textContaining('Hēsci').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(ReadAlong), findsOneWidget);
      expect(find.textContaining('Hēsci'), findsOneWidget);

      // Vimeo can report the old time after the saved position is restored.
      controller.handlePlayerEvent({
        'type': 'ready',
        'seconds': 0.0,
        'duration': 180.0,
      });
      await tester.pump();
      expect(lastPosition?.activeWordId, 'a406779');

      controller.handlePlayerEvent({
        'type': 'loaded',
        'seconds': 0.0,
        'duration': 180.0,
      });
      await tester.pump();
      expect(lastPosition?.activeWordId, 'a406779');

      controller.handlePlayerEvent({
        'type': 'time',
        'seconds': 0.0,
        'duration': 180.0,
      });
      await tester.pump();
      expect(lastPosition?.activeWordId, 'a406779');

      controller.handlePlayerEvent({
        'type': 'seeked',
        'seconds': 10.0,
        'duration': 180.0,
      });
      await tester.pump();
      expect(lastPosition?.activeWordId, 'a406779');

      // Continue emitting time updates inside the first annotation.
      controller.handlePlayerEvent({
        'type': 'time',
        'seconds': 11.0,
        'duration': 180.0,
      });
      await tester.pump();

      expect(lastPosition?.activeWordId, 'a406779');

      // Find the Text widget containing 'Hēsci' and verify its text span has background color
      final textFinder = find.textContaining('Hēsci');
      final textWidget = tester.widget<Text>(textFinder);
      final textSpan = textWidget.textSpan as TextSpan?;
      expect(textSpan, isNotNull);
      final wordSpan = textSpan!.children?.first as TextSpan?;
      expect(wordSpan, isNotNull);
      expect(wordSpan!.style?.backgroundColor, isNotNull);
    },
  );
}
