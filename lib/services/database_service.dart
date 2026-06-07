/// ─── Database Service — SQLite via sqflite ──────────────────────────
///
/// Handles all local persistence for vocabulary words.
/// Uses a lazy singleton pattern — the database file is created on
/// first access, not at app startup.
///
/// ## Why sqflite (not Isar, not Hive, not Drift)
///
/// **Isar** (original choice — REMOVED):
///   Isar 3.1.0 was selected initially for its reactive queries and
///   fast NoSQL performance. However, it is now UNMAINTAINED and its
///   generated `.g.dart` files are incompatible with Android Gradle
///   Plugin 9.x. Builds failed with `groovy.xml.QName` errors that
///   could not be resolved without downgrading AGP — which would
///   break other plugins requiring compileSdk 36.
///
/// **Hive:**
///   Considered but rejected — box-based API is less suited to
///   relational queries (search, sort, filter by language).
///
/// **Drift:**
///   Powerful but requires code generation (build_runner).
///   Overkill for a ~10-field single-table schema.
///
/// **sqflite** (current choice):
///   Mature Flutter SQLite plugin. Zero code generation.
///   Standard SQL queries. Works with every AGP version.
///   Used by thousands of production Flutter apps.
///
/// ## Schema versioning
///   Currently at version 1 with no `onUpgrade` handler.
///   During development, uninstall the app to reset the database.
///   In production, add migration logic in `onUpgrade`.
///
/// ## Static vs instance
///   All methods are static because there is exactly one database
///   instance for the entire app. This avoids passing service
///   references through widget trees.

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/word.dart';

class DatabaseService {
  static Database? _database;

  /// Lazy singleton — creates the DB on first access only.
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize the SQLite database file and create the schema.
  /// Uses `getDatabasesPath()` for platform-correct storage location.
  static Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'vocab_builder.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Create the words table with all 10 columns.
        // `is_reviewed` defaults to 0 (false) — words start unreviewed.
        await db.execute('''
          CREATE TABLE words (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word TEXT NOT NULL,
            translation TEXT NOT NULL,
            example_source TEXT,
            example_target TEXT,
            source_lang TEXT NOT NULL,
            target_lang TEXT NOT NULL,
            is_reviewed INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  /// Insert a new word. Returns the auto-incremented row ID.
  static Future<int> insertWord(Word word) async {
    final db = await database;
    return await db.insert('words', word.toMap());
  }

  /// Get all words, ordered by the given SQL ORDER BY clause.
  /// Default: newest first (created_at DESC).
  /// Pass 'LOWER(word) ASC' for alphabetical sorting.
  static Future<List<Word>> getWords({String orderBy = 'created_at DESC'}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'words',
      orderBy: orderBy,
    );
    return List.generate(maps.length, (i) => Word.fromMap(maps[i]));
  }

  /// Get a single word by its primary key. Returns null if not found.
  static Future<Word?> getWord(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'words',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) return Word.fromMap(maps.first);
    return null;
  }

  /// Update an existing word. Matches by id.
  static Future<int> updateWord(Word word) async {
    final db = await database;
    return await db.update(
      'words',
      word.toMap(),
      where: 'id = ?',
      whereArgs: [word.id],
    );
  }

  /// Delete a word by its primary key.
  static Future<int> deleteWord(int id) async {
    final db = await database;
    return await db.delete(
      'words',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Search words by partial match on word OR translation.
  /// Uses SQL LIKE with % wildcards for substring matching.
  /// Results are ordered newest-first.
  static Future<List<Word>> searchWords(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'words',
      where: 'word LIKE ? OR translation LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => Word.fromMap(maps[i]));
  }
}
