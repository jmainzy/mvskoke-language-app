import 'package:mvskoke_language_app/bus/databaseHelper.dart';

class SearchResult {
  final int id;
  final String lexeme;
  final String phonetics;
  final String soundFile;
  final String definition;
  final String exampleTarget; //xn
  final String exampleSource; //xn
  final int rank; // priority or term i.e. lexeme
  final int defRank; //priority of definition

  SearchResult({
    this.id,
    this.lexeme,
    this.phonetics,
    this.soundFile,
    this.definition,
    this.exampleTarget,
    this.exampleSource,
    this.rank,
    this.defRank
  });

  List<String> getResultLines() {
    var lines = List<String>();
    switch(rank) {
      case DatabaseHelper.RESULT_LEXEME_SIMILAR:
      case DatabaseHelper.RESULT_LEXEME_START:
      case DatabaseHelper.RESULT_LEXEME_ONLY:
        lines = _getDefinitions();
        break;
      case DatabaseHelper.RESULT_DEFINITION_ONLY:
      case DatabaseHelper.RESULT_DEFINITION_SPECIAL:
      case DatabaseHelper.RESULT_DEFINITION_START:
      case DatabaseHelper.RESULT_DEFINITION:
        lines = _getDefinitions();
        break;
      case DatabaseHelper.RESULT_EXAMPLE_START:
      case DatabaseHelper.RESULT_EXAMPLE:
        lines = _getExamples();
        break;
      default:
        lines = _getDefinitions();
    }
    // if (lines.isEmpty) {
    //   lines = _getOtherLines();
    // }
    return lines;
  }

  List<String> _getDefinitions() {
    List<String> defs = List<String>();
    if (definition!=null && definition.trim().isNotEmpty) {
      defs.add(definition);
    }
    return defs;
  }

  List<String> _getExamples() {
    List<String> exs = List<String>();
    if (exampleTarget!=null && exampleTarget.trim().isNotEmpty) {
      exs.add(exampleTarget);
    }
    if (exampleSource!=null && exampleSource.trim().isNotEmpty) {
      exs.add(exampleSource);
    }
    return exs;
  }

  // Implement toString to make it easier to see information about
  // each item when using the print statement.
  @override
  String toString() {
    return 'SearchResult{'
        'id: $id, '
        'term: $lexeme, '
        'phonetics: $phonetics, '
        'soundFile: $soundFile, '
        'definition: $definition, '
        'exampleTarget: $exampleTarget, '
        'rank: $rank, '
        'defRank: $defRank}';
  }
}