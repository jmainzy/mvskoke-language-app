import 'dart:io';

import 'package:mvskoke_language_app/model/example.dart';
import 'package:mvskoke_language_app/model/search_result.dart';
import 'package:mvskoke_language_app/model/term.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/services.dart';

class DatabaseHelper {

  static final _databaseName = "language_database.db";
  static const _DATABASE_VERSION = 1;

  static final table = 'dictionary_table';
  static final terms_table = 'terms';
  static final defs_table = 'definitions';
  static final example_table = 'examples';
  static final search_history_table = 'search_history';

  static final columnId = '_id';
  static final columnTerm = 'term';
  static final columnDef = 'def';
  static final columnTermId = 'term_id';
  static final columnCreatedAt = "created_at";

  static final maxSearchRows = 10;

  static const RESULT_LEXEME_ONLY = 9;
  static const RESULT_LEXEME_START = 8;
  static const RESULT_LEXEME_SIMILAR = 7;
  static const RESULT_DEFINITION_ONLY = 6;
  static const RESULT_DEFINITION_SPECIAL = 5;
  static const RESULT_DEFINITION_START = 4;
  static const RESULT_DEFINITION = 3;
  static const RESULT_EXAMPLE_START = 2;
  static const RESULT_EXAMPLE = 1;
  static const RESULT_OTHER = 0;

  // make this a singleton class
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  // only have a single app-wide reference to the database
  static Database _database;
  Future<Database> get database async {
    if (_database != null) return _database;
    // lazily instantiate the db the first time it is accessed
    _database = await _initDatabase();
    return _database;
  }

  // this opens the database (and creates it if it doesn't exist)
  Future<Database> _initDatabase() async {
    var databasesPath = await getDatabasesPath();
    var path = join(databasesPath, _databaseName);

    // Check if the database exists
    var exists = await databaseExists(path);

    if (!exists) {
      print("Creating new copy from asset");
      await copyDatabase(path);
    } else {
      var db = await openDatabase(path);
      var version = await db.getVersion();
      if (version != _DATABASE_VERSION) {
        print("upgrading version " + version.toString() + " to " +
            _DATABASE_VERSION.toString());
        await deleteDatabase(path);
        await copyDatabase(path);
      }
      else {
        print("Opening existing database");
      }
    }

    return await openDatabase(path);
  }

//  _makeSearchHistoryTable(Database db) {
//    print("making search history table");
//    db.execute(
//        "CREATE TABLE IF NOT EXISTS $search_history_table("
//            + "id INTEGER PRIMARY KEY AUTOINCREMENT, "
//            + "$columnTermId INTEGER UNIQUE, "
//            + "$columnCreatedAt TEXT)"
//    );
//    db.execute("SELECT * FROM $search_history_table");
//  }

  copyDatabase(String path) async {
    print("copying from path "+path);

    // Make sure the parent directory exists
    try {
      await Directory(dirname(path)).create(recursive: true);
    } catch (_) {}

    // Copy from asset
    ByteData data = await rootBundle.load(join("assets", _databaseName));
    List<int> bytes =
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

    // Write and flush the bytes written
    await File(path).writeAsBytes(bytes, flush: true);

    // set version
    var db = await openDatabase(path, readOnly: false);
    db.setVersion(_DATABASE_VERSION);

    // make search history
    // TODO: Migrate user data
//    await _makeSearchHistoryTable(db);
  }

  // Helper methods

  // Inserts a row in the database where each key in the Map is a column name
  // and the value is the column value. The return value is the id of the
  // inserted row.
  Future<int> insert(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert(table, row);
  }

  // All of the rows are returned as a list of maps, where each map is
  // a key-value list of columns.
  Future<List<Map<String, dynamic>>> queryAllRows() async {
    Database db = await instance.database;
    return await db.query(table);
  }

  Future<List<SearchResult>> getAllEntries() async {

    final Database db = await database;
    final sql = 'SELECT * FROM terms '
        + 'JOIN definitions ON terms.id = definitions.term_id '
        + 'LEFT JOIN examples ON definitions.id = examples.def_id '
        + 'GROUP BY term_id '
        + 'ORDER BY terms.lexeme ASC';
    final List<Map<String, dynamic>> maps = await db.rawQuery(sql);

    // Convert the List<Map<String, dynamic> into a List<SearchResult>.
    return List.generate(maps.length, (i) {
      return SearchResult(
          id: maps[i]['term_id'],
          lexeme: maps[i]['lexeme'],
          phonetics: maps[i]['phonetics'],
          soundFile: maps[i]['term_sound_file'],
          definition: maps[i]['definition'],
          exampleTarget: maps[i]['exampleTarget'],
          exampleSource: maps[i]['exampleSource'],
          rank: maps[i]['rank'],
          defRank: maps[i]['defRank']
      );
    });
  }

  Future<List<SearchResult>> querySearch(String searchTerm) async {
    // Get a reference to the database.
    final Database db = await database;
    var args = List.filled(19, searchTerm);
    args[5] = "\"$searchTerm\"";
    args[6] = "\"$searchTerm\"";
    final sql = 'SELECT term_id, lexeme, phonetics, terms.soundFile AS term_sound_file, definitions.definition, examples.soundFile AS ex_sound_file, examples.exampleTarget, examples.exampleSource, '
              + 'CASE '
              + 'WHEN lexeme = ? THEN $RESULT_LEXEME_ONLY '
              + 'WHEN lexeme LIKE ? || "%" THEN $RESULT_LEXEME_START '
              + 'WHEN lexeme LIKE "%" || ? || "%" THEN $RESULT_LEXEME_SIMILAR '
              + 'WHEN definition = ? || "." THEN $RESULT_DEFINITION_ONLY '
              // this one is special case to include quotes ""
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
              + 'WHERE lexeme LIKE "%" || ? || "%" OR definition LIKE "%" || ? || "%" OR exampleTarget LIKE "%" || ? || "%" OR exampleSource LIKE "%" || ? || "%"'
              + 'GROUP BY term_id '
              + 'ORDER BY rank DESC, defRank ASC, term_id ASC';
    final List<Map<String, dynamic>> maps = await db.rawQuery(sql, args);
    
    // Convert the List<Map<String, dynamic> into a List<SearchResult>.
    return List.generate(maps.length, (i) {
      return SearchResult(
        id: maps[i]['term_id'],
        lexeme: maps[i]['lexeme'],
        phonetics: maps[i]['phonetics'],
        soundFile: maps[i]['term_sound_file'],
        definition: maps[i]['definition'],
        exampleTarget: maps[i]['exampleTarget'],
        exampleSource: maps[i]['exampleSource'],
        rank: maps[i]['rank'],
        defRank: maps[i]['defRank']
      );
    });
  }

  Future<List<SearchResult>> querySimilarTerm(String searchTerm) async {
    // strip parenthesis
    if (searchTerm.contains("(")) {
      searchTerm = searchTerm.substring(0,searchTerm.indexOf("("));
    }

    // Get a reference to the database.
    final Database db = await database;
    final sql = 'SELECT term_id, lexeme, phonetics, terms.soundFile AS term_sound_file, definitions.definition, examples.soundFile AS ex_sound_file, '
              + 'CASE '
              + 'WHEN lexeme = "$searchTerm" THEN 1 '
              + 'WHEN lexeme LIKE "$searchTerm%" THEN 2 '
              + 'ELSE 0 '
              + 'END '
              + 'AS rank '
              + 'FROM terms '
              + 'JOIN definitions ON terms.id = definitions.term_id '
              + 'LEFT JOIN examples ON definitions.id = examples.def_id '
              + 'WHERE lexeme LIKE "$searchTerm%" '
              + 'ORDER BY rank ASC';
    final List<Map<String, dynamic>> maps = await db.rawQuery(sql);
    
    // Convert the List<Map<String, dynamic> into a List<SearchResult>.
    return List.generate(maps.length, (i) {
      return SearchResult(
        id: maps[i]['term_id'],
        lexeme: maps[i]['lexeme'],
        phonetics: maps[i]['phonetics'],
        soundFile: maps[i]['term_sound_file'],
        definition: maps[i]['definition'],
      );
    });
  }

  Future<List<Term>> getDefinitionForId(int termId) async {
    // Get a reference to the database.
    final Database db =  await database;
    // Query the table for all The Terms.
    final sql = 'SELECT term_id, definitions.id AS def_id, pos, definition, rt '
              + 'FROM definitions '
              + 'WHERE term_id = $termId';
    final List<Map<String, dynamic>> maps = await db.rawQuery(sql);

    // Convert the List<Map<String, dynamic> into a List<Term>.
    List<Term> detail = List.generate(maps.length, (i) {
      return Term(
        defId: maps[i]['def_id'],
        pos: maps[i]['pos'],
        definition: maps[i]['definition'],
        relatedTerm: maps[i]['rt'],
      );
    });

    List<Term> result = await processResult(detail);
    return result;
  }

  Future<List<Term>> processResult(List<Term> list) async {
    final Database db =  await database;
    for (Term detail in list) {
      List<Map<String, dynamic>> maps = await db.query(example_table, where: "def_id = ?", whereArgs: [detail.defId]);
      List<Example> examples = List.generate(maps.length, (i) {
        return Example(
          exampleTarget: maps[i]['exampleTarget'],
          exampleSource: maps[i]['exampleSource'],
          soundFile: maps[i]['soundFile'],
        );
      }).toList();

      detail.addExample(examples);
    }
    return list;
  }

  Future<void> insertSearchHistory(int termId) async {
    // Get a reference to the database.
    final Database db = await database;
    print('DATETIME: ' + DateTime.now().millisecondsSinceEpoch.toString());
    // row to insert
    Map<String, dynamic> row = {
      columnTermId : termId,
      columnCreatedAt: DateTime.now().millisecondsSinceEpoch.toString()
    };
    await db.insert(
      search_history_table,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<SearchResult>> querySearchHistory() async {
    // Get a reference to the database.
    final Database db = await database;
    final sql = 'SELECT terms.id, lexeme, phonetics, terms.soundFile AS term_sound_file, definition, examples.exampleTarget, examples.exampleSource, created_at '
          + 'FROM search_history '
          + 'LEFT JOIN terms ON terms.id = search_history.term_id '
          + 'JOIN definitions ON definitions.term_id = search_history.term_id '
          + 'LEFT JOIN examples ON definitions.id = examples.def_id '
          + 'GROUP BY search_history.term_id '
          + 'ORDER BY created_at DESC '
          + 'LIMIT $maxSearchRows';
    final List<Map<String, dynamic>> maps = await db.rawQuery(sql);
    
    // Convert the List<Map<String, dynamic> into a List<SearchResult>.
    return List.generate(maps.length, (i) {
//      print('id ${maps[i]['id']} lexeme ${maps[i]['lexeme']} created_at ${maps[i]['created_at']}');
      return SearchResult(
        id: maps[i]['id'],
        lexeme: maps[i]['lexeme'],
        phonetics: maps[i]['phonetics'],
        soundFile: maps[i]['term_sound_file'],
        definition: maps[i]['definition'],
        exampleTarget: maps[i]['exampleTarget'],
        exampleSource: maps[i]['exampleSource']
      );
    });
  }

  //For debug only
  Future<List<String>> searchHistoryTerms() async {
    // Get a reference to the database.
    final Database db = await database;

    final sql = 'SELECT term_id, created_at FROM search_history ORDER BY datetime(created_at) DESC';
    final List<Map<String, dynamic>> maps = await db.rawQuery(sql);

    return List.generate(maps.length, (i) {
      return maps[i]['term_id'].toString() + " | " + maps[i]['created_at'].toString();
    });
  }
}