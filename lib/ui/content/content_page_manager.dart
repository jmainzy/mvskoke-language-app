import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart' show AudioSource;
import 'package:logger/logger.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mvskoke_language_app/models/content_item.dart';
import 'package:mvskoke_language_app/models/media_item.dart';
import 'package:mvskoke_language_app/models/word.dart';
import 'package:mvskoke_language_app/services/content_service.dart';
import 'package:mvskoke_language_app/services/service_locator.dart';
import 'package:mvskoke_language_app/services/store_service.dart';
import 'package:mvskoke_language_app/ui/components/video_player.dart';
import 'package:mvskoke_language_app/utilities/utils.dart';
import 'package:readalong/readalong.dart' show PlayerState, ProcessingState;

Logger log = Logger();

class ContentPageManager extends ChangeNotifier {
  final contentService = sl<ContentService>();
  String title = '';
  String contentId = '';
  MediaObject? mediaItem;
  AudioSource? audioSource;
  Map<String, Word> _wordIndex = const {};
  VimeoPlaybackController? _vimeoPlaybackController;
  StreamSubscription<Duration>? _videoPositionSubscription;
  StreamSubscription<PlayerState>? _videoStateSubscription;
  Timer? _progressSaveTimer;
  Duration? _latestVideoPosition;
  bool _disposed = false;
  late Future<ContentItem?> contentItemFuture;
  VimeoPlaybackController? get playbackController => _vimeoPlaybackController;
  List<String> indexedWords = [];

  Future<ContentItem?> getContentItem(String contentId) async {
    final item = await contentService.getContentById(contentId);
    if (_disposed) return null;
    title = item?.title ?? '';
    this.contentId = contentId;

    if (item?.textFile case final textFile?) {
      final extension = RegExp(r'\.[^./\\]+$').firstMatch(textFile);
      if (extension == null) {
        throw FormatException('Text file has no extension: $textFile');
      }
      final indexFile = '${textFile.substring(0, extension.start)}_index.json';
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      if (_disposed) return null;
      if (manifest.listAssets().contains('assets/readalongs/$indexFile')) {
        _wordIndex = await getWordIndex(indexFile);
        if (_disposed) return null;
        indexedWords = _wordIndex.keys.toList();
      } else {
        log.i('No word index found for $textFile');
      }
    }

    if (item?.mediaId != null && item!.mediaId!.isNotEmpty) {
      mediaItem = await contentService.getMediaById(item.mediaId!);
      if (_disposed) return null;
      if (mediaItem?.mediaType == MediaType.video) {
        final uri = mediaItem?.uri;
        if (uri != null && Utils.getVimeoEmbedUrl(uri) != null) {
          final progress = sl<StoreService>().getVideoProgress(item.id);
          _latestVideoPosition = progress?.position ?? Duration.zero;
          _vimeoPlaybackController = VimeoPlaybackController(
            initialPosition: _latestVideoPosition!,
          );
          _videoPositionSubscription = _vimeoPlaybackController!.positionStream
              .listen(_handleVideoPosition);
          _videoStateSubscription = _vimeoPlaybackController!.stateStream
              .listen((state) {
                if (state.processingState == ProcessingState.completed ||
                    !state.playing) {
                  unawaited(saveVideoProgress());
                }
              });
        } else {
          throw UnsupportedError(
            'Video playback requires a valid Vimeo URL: $uri',
          );
        }
      } else {
        audioSource = await contentService.getAudioSource(item.mediaId!);
        if (_disposed) return null;
      }
    }
    notifyListeners();
    return item;
  }

  Future<Map<String, Word>> getWordIndex(String indexFile) async {
    final source = await rootBundle.loadString('assets/readalongs/$indexFile');
    if (_disposed) return {};
    final words = jsonDecode(source);
    if (words is! Map<String, dynamic>) {
      throw const FormatException('Word index must be an object.');
    }
    final definitions = <String, Word>{};
    for (final word in words.entries) {
      final entry = word.value;
      if (entry is! Map<String, dynamic> ||
          !entry.containsKey('headword') ||
          (entry['headword'] != null && entry['headword'] is! String) ||
          entry['entries'] is! Map<String, dynamic> ||
          (entry['definition'] != null && entry['definition'] is! String)) {
        throw const FormatException(
          'Each word index entry must contain a headword, entries object, '
          'and optional string definition.',
        );
      }
      final wordDefinitions = <String>[];
      for (final value in (entry['entries'] as Map<String, dynamic>).values) {
        if (value is! List ||
            value.any((definition) => definition is! String)) {
          throw const FormatException(
            'Each dictionary entry must contain a list of definitions.',
          );
        }
        wordDefinitions.addAll(
          value.cast<String>().where((text) => text.trim().isNotEmpty),
        );
      }
      final definition = entry['definition'] as String?;
      if (wordDefinitions.isNotEmpty ||
          (definition != null && definition.trim().isNotEmpty)) {
        definitions[word.key.toLowerCase()] = Word(
          headword: entry['headword'] as String? ?? word.key,
          entries: {
            for (var e in (entry['entries'] as Map<String, dynamic>).entries)
              e.key: (e.value as List).cast<String>(),
          },
          definition: definition,
        );
      }
    }
    return definitions;
  }

  Word? getWord(String word) {
    return _wordIndex[word.trim().toLowerCase()];
  }

  void _handleVideoPosition(Duration position) {
    _latestVideoPosition = position;
    _progressSaveTimer ??= Timer(const Duration(seconds: 5), () {
      _progressSaveTimer = null;
      unawaited(saveVideoProgress());
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _progressSaveTimer?.cancel();
    unawaited(_videoPositionSubscription?.cancel());
    unawaited(_videoStateSubscription?.cancel());
    unawaited(saveVideoProgress());
    unawaited(_vimeoPlaybackController?.dispose());
    super.dispose();
  }

  Future<void> saveVideoProgress() async {
    final controller = _vimeoPlaybackController;
    final position = _latestVideoPosition;
    if (controller == null ||
        position == null ||
        mediaItem?.mediaType != MediaType.video) {
      return;
    }

    try {
      await sl<StoreService>().saveVideoProgress(
        contentId,
        position: position,
        duration: controller.duration,
      );
    } catch (error, stackTrace) {
      log.e(
        'Unable to save video progress',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
