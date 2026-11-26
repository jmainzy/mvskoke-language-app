import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mvskoke_language_app/models/content_item.dart';
import 'package:mvskoke_language_app/services/content_service.dart';
import 'package:mvskoke_language_app/services/service_locator.dart';
import 'package:mvskoke_language_app/ui/content/content_page.dart';
import 'package:readalong/readalong.dart';

class _ChipbearContentService extends ContentService {
  @override
  Future<ContentItem?> getContentById(String id) async => id == 'chipbear'
      ? ContentItem(id: id, title: 'Chipbear', textFile: 'chipbear.readalong')
      : ContentItem(id: id, title: 'Other story');
}

void main() {
  testWidgets('Chipbear index opens a definition at a capitalized word', (
    tester,
  ) async {
    sl.registerSingleton<ContentService>(_ChipbearContentService());
    addTearDown(() => sl.unregister<ContentService>());
    await tester.pumpWidget(
      const MaterialApp(home: ContentPage(contentId: 'chipbear')),
    );
    await tester.pumpAndSettle();
    final finder = find
        .byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText().startsWith('Punvttv omvlkvt'),
        )
        .first;
    final render = tester.renderObject<RenderParagraph>(finder);
    final wordBox = render
        .getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 7),
        )
        .first;
    final wordCenter = render.localToGlobal(wordBox.toRect().center);
    final wordRect = wordBox.toRect().shift(render.localToGlobal(Offset.zero));
    await tester.tapAt(wordCenter);
    await tester.pumpAndSettle();
    expect(find.text('ponvttv'), findsOneWidget);
    expect(find.text('animal, game'), findsOneWidget);
    final menuRect = tester.getRect(
      find.byKey(const ValueKey('word-definition')),
    );
    expect(menuRect.left, wordRect.right + 8);
    expect(menuRect.bottom, wordRect.top - 8);
    await tester.tapAt(const Offset(790, 590));
    await tester.pumpAndSettle();
    expect(find.text('animal, game'), findsNothing);

    tester.widget<ReadAlong>(find.byType(ReadAlong)).onWordTap!(
      'Punvttv',
      const Rect.fromLTWH(780, 10, 10, 20),
    );
    await tester.pumpAndSettle();
    final edgeMenu = tester.getRect(
      find.byKey(const ValueKey('word-definition')),
    );
    expect(edgeMenu.right, lessThanOrEqualTo(772));
    expect(edgeMenu.top, greaterThanOrEqualTo(38));
  });

  testWidgets('loads the new content when the page content ID changes', (
    tester,
  ) async {
    sl.registerSingleton<ContentService>(_ChipbearContentService());
    addTearDown(() => sl.unregister<ContentService>());
    await tester.pumpWidget(
      const MaterialApp(home: ContentPage(contentId: 'chipbear')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chipbear'), findsOneWidget);
    expect(find.byType(ReadAlong), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(home: ContentPage(contentId: 'other')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Other story'), findsOneWidget);
    expect(find.byType(ReadAlong), findsNothing);
  });
}
