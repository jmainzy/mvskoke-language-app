class Word {
  final String headword;
  final Map<String, List<String>> entries;
  final String? definition;

  Word({required this.headword, required this.entries, this.definition});
}
