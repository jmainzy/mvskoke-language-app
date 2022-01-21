# Mvskoke Language App

Dictionary for the Mvskoke Language

This is a proof-of-concept mobile component to the Mvskoke Web App.  See the web version here: [Mvskoke Web App](https://github.com/jmainzy/mvskoke-web-app/)

This app is built with Flutter interacting with a local SQLite database.  Future plan is to integrate it with [creekdictionary.com](https://github.com/muscogee-language-foundation/creekdictionary.com) using the [Mvskoke Language API](https://github.com/muscogee-language-foundation/mvskoke-language-api), to allow for more robust searching.

## Demo

### Words and Definitions
<img src="https://github.com/jmainzy/mvskoke-language-app/blob/master/demo.gif" width="300">

### Search
<img src="https://github.com/jmainzy/mvskoke-language-app/blob/master/demo-search.gif" width="300">

## Features
- Word List
- Instant Search with highlighting
- Definitions
- About Page

## Data
The dictionary data was originally scraped using python from the [English and Muskokee Dictionary - Loughridge and Hodge, 1914](https://library.si.edu/digital-library/book/englishmuskokeed00loug)
Plans are to update using the shared database from [creekdictionary.com](https://github.com/muscogee-language-foundation/creekdictionary.com), which hosts a community-maintained and validated data set.

## Search
The search feature uses a `LIKE` and `CASE` with SQLite for a simple ranked local search.
Ideally in the future, it will interact with the [Mvskoke Language REST API](https://github.com/muscogee-language-foundation/mvskoke-language-api) for a more robust search.

i.e.
```
    final sql = 'SELECT terms.id as term_id, lexeme, phonetics, terms.soundFile AS term_sound_file, definitions.definition, examples.soundFile AS ex_sound_file, examples.exampleTarget, examples.exampleSource, tags.tag as tag, '
              + 'CASE '
              + 'WHEN lexeme = ? THEN $RESULT_LEXEME_ONLY '
              + 'WHEN lexeme LIKE ? || "%" THEN $RESULT_LEXEME_START '
              + 'WHEN tag = ? THEN $RESULT_TAG '
              + 'WHEN tag LIKE ? || "%" THEN $RESULT_TAG_START '
              + 'WHEN lexeme LIKE "%" || ? || "%" THEN $RESULT_LEXEME_SIMILAR '
              + 'WHEN definition = ? || "." THEN $RESULT_DEFINITION_ONLY '
              + 'WHEN definition LIKE "%" || ? || "%" THEN $RESULT_DEFINITION_SPECIAL '
              + 'WHEN definition LIKE ? || "%" THEN $RESULT_DEFINITION_START '
              + 'WHEN definition LIKE "%" || ? || "%" THEN $RESULT_DEFINITION '
              + 'WHEN exampleTarget LIKE ? || "%" OR exampleSource LIKE ? || "%" THEN $RESULT_EXAMPLE_START '
              + 'WHEN exampleTarget LIKE "%" || ? || "%" OR exampleSource LIKE "%" || ? || "%" THEN $RESULT_EXAMPLE '
              + 'ELSE 0 '
              + 'END '
              + 'AS rank,'
              + 'CASE '
              + 'WHEN lexeme LIKE "%" || ? || "%" '
              + 'THEN instr(lexeme, "%" || ? || "%") '
              + 'WHEN definition LIKE "%" || ? || "%" '
              + 'THEN instr(definition, ?) '
              + 'END '
              + 'AS defRank '
              + 'FROM terms '
              + 'JOIN definitions ON terms.id = definitions.term_id '
              + 'LEFT JOIN examples ON definitions.id = examples.def_id '
              + 'JOIN tags ON terms.id = tags.term_id '
              + 'WHERE lexeme LIKE "%" || ? || "%" OR tag LIKE "%" || ? || "%" OR definition LIKE "%" || ? || "%" OR exampleTarget LIKE "%" || ? || "%" OR exampleSource LIKE "%" || ? || "%"'
              + 'GROUP BY terms.id '
              + 'ORDER BY rank DESC, defRank ASC, terms.id ASC';
```

## Installation

- [Get Started with Flutter](https://docs.flutter.dev/get-started/install)
- Clone and install with `flutter run`

## Contribution

Fork and PR!
Email me at julia@muscogeelanguage.org for collaboration.
