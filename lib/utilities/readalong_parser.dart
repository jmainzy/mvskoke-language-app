import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:xml/xml.dart';

Logger log = Logger();

/// Example usage.
///
/// ```dart
/// final xml = await File('chipbear.readalong').readAsString();
/// final story = ReadAlong.parse(xml);
///
/// for (final s in story.sentences) {
///   print('${s.start.toStringAsFixed(2)}s  ${s.text}');
///   print('           ${s.translation}');
/// }
/// ```
///
/// To highlight the current word during audio playback:
///
/// ```dart
/// ReadAlongWord? currentWord(ReadAlong story, double positionSeconds) {
///   for (final w in story.words) {
///     if (positionSeconds >= w.start && positionSeconds < w.end) return w;
///   }
///   return null;
/// }
/// ```

class ReadalongParser {
  Future<String> readFile(String filePath) async {
    // read file from assets
    log.i('Reading file from assets: $filePath');
    return await rootBundle.loadString('assets/$filePath');
  }

  Future<ReadAlong> getText(String filePath) async {
    final xmlString = await readFile(filePath);
    return ReadAlong.parse(xmlString);
  }
}

/// A sentence in the original language, plus its English translation.
class ReadAlongSentence {
  final String id;

  /// Full sentence text, including punctuation and quotes that sit
  /// outside the <w> elements.
  final String text;
  final List<ReadAlongWord> words;
  final String? translation;
  final String? translationLang;

  const ReadAlongSentence({
    required this.id,
    required this.text,
    required this.words,
    this.translation,
    this.translationLang,
  });

  double get start => words.isEmpty ? 0.0 : words.first.start;
  double get end => words.isEmpty ? 0.0 : words.last.end;

  @override
  String toString() => 'ReadAlongSentence($id, "$text" => "$translation")';
}

class ReadAlong {
  final String? version;
  final String? generator;
  final List<ReadAlongSentence> sentences;

  const ReadAlong({this.version, this.generator, required this.sentences});

  /// All words across all sentences, in order.
  Iterable<ReadAlongWord> get words => sentences.expand((s) => s.words);

  /// Parses the contents of a .readalong file.
  factory ReadAlong.parse(String xmlString) {
    final document = XmlDocument.parse(xmlString);
    final root = document.rootElement; // <read-along>

    final generator = root
        .findElements('meta')
        .where((m) => m.getAttribute('name') == 'generator')
        .map((m) => m.getAttribute('content'))
        .firstOrNull;

    // The file contains two kinds of <s> elements:
    //  1. Sentences containing <w> elements (the aligned original text).
    //  2. Translation sentences marked do-not-align="true", whose
    //     sentence-id points back at the id of the sentence they translate.
    // Note that ids are duplicated between the two kinds, so we match
    // translations to sentences through the sentence-id attribute.
    final translations = <String, XmlElement>{};
    final sentenceElements = <XmlElement>[];

    for (final s in root.findAllElements('s')) {
      if (s.getAttribute('do-not-align') == 'true') {
        final key = s.getAttribute('sentence-id') ?? s.getAttribute('id');
        if (key != null) translations[key] = s;
      } else {
        sentenceElements.add(s);
      }
    }

    final sentences = sentenceElements.map((s) {
      final id = s.getAttribute('id') ?? '';
      final tr = translations[id];
      return ReadAlongSentence(
        id: id,
        text: s.innerText.trim(),
        words: s.findElements('w').map(ReadAlongWord.fromXml).toList(),
        translation: tr?.innerText.trim(),
        translationLang: tr?.getAttribute('xml:lang'),
      );
    }).toList();

    return ReadAlong(
      version: root.getAttribute('version'),
      generator: generator,
      sentences: sentences,
    );
  }
}

/// A single aligned word with its audio timing.
class ReadAlongWord {
  final String id;
  final String text;
  final List<String> arpabet;

  /// Start time in seconds.
  final double start;

  /// Duration in seconds.
  final double duration;

  const ReadAlongWord({
    required this.id,
    required this.text,
    required this.arpabet,
    required this.start,
    required this.duration,
  });

  double get end => start + duration;

  factory ReadAlongWord.fromXml(XmlElement w) {
    final arpabet = w.getAttribute('ARPABET');
    return ReadAlongWord(
      id: w.getAttribute('id') ?? '',
      text: w.innerText,
      arpabet: arpabet == null || arpabet.trim().isEmpty
          ? const []
          : arpabet.trim().split(RegExp(r'\s+')),
      start: double.tryParse(w.getAttribute('time') ?? '') ?? 0.0,
      duration: double.tryParse(w.getAttribute('dur') ?? '') ?? 0.0,
    );
  }

  @override
  String toString() => 'ReadAlongWord($text, $start-$end)';
}
