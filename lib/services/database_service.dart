import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/word.dart';

class DatabaseService {
  static DatabaseService? _instance;
  late Database _db;

  DatabaseService._();

  static DatabaseService get instance {
    _instance ??= DatabaseService._();
    return _instance!;
  }

  Database get db => _db;

  Future<void> init() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'vocab_builder.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE words (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word TEXT NOT NULL,
            translation TEXT NOT NULL DEFAULT '',
            example_source TEXT NOT NULL DEFAULT '',
            example_target TEXT NOT NULL DEFAULT '',
            source_lang TEXT NOT NULL DEFAULT 'de',
            target_lang TEXT NOT NULL DEFAULT 'en',
            is_reviewed INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        // Index for fast search
        await db.execute(
            'CREATE INDEX idx_words_word ON words(word)');
        await db.execute(
            'CREATE INDEX idx_words_translation ON words(translation)');
      },
    );
  }

  // ── Word CRUD ──

  Future<int> addWord(Word word) async {
    word.updatedAt = DateTime.now();
    word.createdAt = DateTime.now();
    return _db.insert('words', word.toMap());
  }

  Future<List<Word>> getAllWords({String? searchQuery}) async {
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final q = '%${searchQuery.toLowerCase()}%';
      final rows = await _db.query(
        'words',
        where: 'LOWER(word) LIKE ? OR LOWER(translation) LIKE ? OR LOWER(example_source) LIKE ?',
        whereArgs: [q, q, q],
        orderBy: 'created_at DESC',
      );
      return rows.map((row) => Word.fromMap(row)).toList();
    }

    final rows = await _db.query('words', orderBy: 'created_at DESC');
    return rows.map((row) => Word.fromMap(row)).toList();
  }

  Future<Word?> getWord(int id) async {
    final rows = await _db.query('words', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Word.fromMap(rows.first);
  }

  Future<void> updateWord(Word word) async {
    word.updatedAt = DateTime.now();
    await _db.update(
      'words',
      word.toMap(),
      where: 'id = ?',
      whereArgs: [word.id],
    );
  }

  Future<void> deleteWord(int id) async {
    await _db.delete('words', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Word>> getUnreviewedWords() async {
    final rows = await _db.query(
      'words',
      where: 'is_reviewed = 0',
      orderBy: 'created_at DESC',
    );
    return rows.map((row) => Word.fromMap(row)).toList();
  }

  Future<int> getUnreviewedCount() async {
    final result = await _db.rawQuery(
        'SELECT COUNT(*) as count FROM words WHERE is_reviewed = 0');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getWordCount() async {
    final result = await _db.rawQuery('SELECT COUNT(*) as count FROM words');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> close() async {
    await _db.close();
  }
}
