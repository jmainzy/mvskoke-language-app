import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
