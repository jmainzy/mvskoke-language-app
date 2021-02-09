

import 'example.dart';

class Term {
  final int defId;
  final String pos;
  final String definition; //gn
  final String soundFile; //sf
  final String relatedTerm; //rt
  List<Example> examples = List<Example>();

  Term({this.defId, this.pos, this.definition, this.soundFile, this.relatedTerm});

  // Implement toString to make it easier to see information about
  // each dog when using the print statement.
  @override
  String toString() {
    return 'SearchDetail{pos: $pos, definition: $definition, soundFile: $soundFile}, relatedTerm: $relatedTerm';
  }

  void addExample(List<Example> examples) {
    this.examples= examples;
  }
}