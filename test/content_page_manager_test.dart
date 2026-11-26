import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mvskoke_language_app/models/content_item.dart';
import 'package:mvskoke_language_app/models/media_item.dart';
import 'package:mvskoke_language_app/services/content_service.dart';
import 'package:mvskoke_language_app/services/service_locator.dart';
import 'package:mvskoke_language_app/services/store_service.dart';
import 'package:mvskoke_language_app/ui/content/content_page_manager.dart';
import 'package:mvskoke_language_app/ui/content/word_widget.dart';

class _ContentService extends ContentService {
  _ContentService(this.item);

  final Future<ContentItem?> item;

  @override
  Future<ContentItem?> getContentById(String id) => item;

  @override
  Future<MediaObject?> getMediaById(String id) async => MediaObject(
    id: id,
    title: 'Video',
    uri: 'https://vimeo.com/253875203',
    performer: null,
    copyright: '',
    lastUpdate: null,
    mediaType: MediaType.video,
  );
}

class _StoreService implements StoreService {
  final saved = <Duration>[];

  @override
  VideoProgress? getVideoProgress(String contentId) =>
      const VideoProgress(position: Duration(seconds: 10), duration: null);

  @override
  Future<void> saveVideoProgress(
    String contentId, {
    required Duration position,
    required Duration? duration,
  }) async {
    saved.add(position);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    if (sl.isRegistered<ContentService>()) {
      await sl.unregister<ContentService>();
    }
    if (sl.isRegistered<StoreService>()) {
      await sl.unregister<StoreService>();
    }
  });

  test(
    'loads definitions from all entries and omits unavailable words',
    () async {
      sl.registerSingleton<ContentService>(
        _ContentService(
          Future.value(
            ContentItem(
              id: 'chipbear',
              title: 'Chipbear',
              textFile: 'chipbear.readalong',
            ),
          ),
        ),
      );
      final manager = ContentPageManager();
      addTearDown(manager.dispose);
      var notifications = 0;
      manager.addListener(() => notifications++);
      await manager.getContentItem('chipbear');

      expect(notifications, 1);
      expect(manager.getWord(' PUNVTTV ')?.entries.values.expand((e) => e), [
        'animal, game',
      ]);
      expect(manager.getWord('nettv')?.entries.values.expand((e) => e), [
        'day, date',
        'day of death, final day',
      ]);
      expect(manager.getWord('tepakat'), isNull);
      expect(manager.getWord('estowē'), isNull);
      expect(manager.indexedWords, contains('punvttv'));
      expect(manager.indexedWords, isNot(contains('tepakat')));
      expect(manager.indexedWords, isNot(contains('estowē')));
    },
  );

  test('rejects malformed definition lists', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler('flutter/assets', (message) async {
      final bytes = Uint8List.fromList(
        utf8.encode(
          '{"word":{"headword":"word","entries":{"id":["definition",42]}}}',
        ),
      );
      return ByteData.sublistView(bytes);
    });
    addTearDown(() => messenger.setMockMessageHandler('flutter/assets', null));
    sl.registerSingleton<ContentService>(
      _ContentService(Future.value(ContentItem(id: 'bad', title: 'Bad index'))),
    );
    final manager = ContentPageManager();
    addTearDown(manager.dispose);
    await expectLater(
      manager.getWordIndex('invalid-test-index.json'),
      throwsFormatException,
    );
  });

  testWidgets('loads and displays an override definition without an entry ID', (
    tester,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler('flutter/assets', (message) async {
      final bytes = Uint8List.fromList(
        utf8.encode(
          '{"word":{"headword":"root","entries":{},"definition":"custom meaning"}}',
        ),
      );
      return ByteData.sublistView(bytes);
    });
    addTearDown(() => messenger.setMockMessageHandler('flutter/assets', null));
    sl.registerSingleton<ContentService>(
      _ContentService(
        Future.value(ContentItem(id: 'override', title: 'Override')),
      ),
    );
    final manager = ContentPageManager();
    addTearDown(manager.dispose);
    final index = await manager.getWordIndex('override-test.json');
    final word = index['word'];
    expect(word?.entries, isEmpty);
    await tester.pumpWidget(MaterialApp(home: WordWidget(word: word!)));
    expect(find.text('root'), findsOneWidget);
    expect(find.text('custom meaning'), findsOneWidget);
  });

  test('saves video progress on pause and disposal', () async {
    final store = _StoreService();
    sl.registerSingleton<StoreService>(store);
    sl.registerSingleton<ContentService>(
      _ContentService(
        Future.value(ContentItem(id: 'video', title: 'Video', mediaId: 'v')),
      ),
    );
    final manager = ContentPageManager();
    await manager.getContentItem('video');
    final controller = manager.playbackController!;
    expect(controller.position, const Duration(seconds: 10));
    controller.handlePosition(12);
    controller.handlePause();
    expect(store.saved, contains(const Duration(seconds: 12)));
    controller.handlePosition(15);
    manager.dispose();
    expect(store.saved.last, const Duration(seconds: 15));
  });

  for (final textFile in ['mus16051.eaf', 'mus16019.eaf']) {
    test('loads the JSON index and video for $textFile', () async {
      sl.registerSingleton<StoreService>(_StoreService());
      sl.registerSingleton<ContentService>(
        _ContentService(
          Future.value(
            ContentItem(
              id: 'video',
              title: 'Video',
              textFile: textFile,
              mediaId: 'v',
            ),
          ),
        ),
      );
      final manager = ContentPageManager();
      addTearDown(manager.dispose);
      final item = await manager.getContentItem('video');
      expect(item?.textFile, textFile);
      expect(manager.indexedWords, isNotEmpty);
      expect(manager.playbackController, isNotNull);
    });
  }

  test('continues loading a story without an index asset', () async {
    sl.registerSingleton<ContentService>(
      _ContentService(
        Future.value(
          ContentItem(
            id: 'unindexed',
            title: 'Unindexed',
            textFile: 'unindexed.eaf',
          ),
        ),
      ),
    );
    final manager = ContentPageManager();
    addTearDown(manager.dispose);
    expect(await manager.getContentItem('unindexed'), isNotNull);
    expect(manager.indexedWords, isEmpty);
  });

  test(
    'does not initialize media after disposal during a pending load',
    () async {
      final pending = Completer<ContentItem?>();
      sl.registerSingleton<ContentService>(_ContentService(pending.future));
      final manager = ContentPageManager();
      final load = manager.getContentItem('video');
      manager.dispose();
      pending.complete(ContentItem(id: 'video', title: 'Video', mediaId: 'v'));
      expect(await load, isNull);
      expect(manager.playbackController, isNull);
    },
  );
}
