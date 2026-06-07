import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/word.dart';

class DatabaseService {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'vocab_builder.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
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

  static Future<int> insertWord(Word word) async {
    final db = await database;
    return await db.insert('words', word.toMap());
  }

  static Future<List<Word>> getWords({String orderBy = 'created_at DESC'}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'words',
      orderBy: orderBy,
    );
    return List.generate(maps.length, (i) => Word.fromMap(maps[i]));
  }

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

  static Future<int> updateWord(Word word) async {
    final db = await database;
    return await db.update(
      'words',
      word.toMap(),
      where: 'id = ?',
      whereArgs: [word.id],
    );
  }

  static Future<int> deleteWord(int id) async {
    final db = await database;
    return await db.delete(
      'words',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

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
