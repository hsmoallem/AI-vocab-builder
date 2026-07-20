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
      // v2: note + grammar_tip.  v3: archived.  v4: SM-2 SRS fields + app_state.
      // v5: saved 2nd-language translation.
      version: 5,
      onCreate: (db, version) async {
        // Fresh install — create the table with all current columns.
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
            note TEXT,
            grammar_tip TEXT,
            archived INTEGER NOT NULL DEFAULT 0,
            second_lang TEXT,
            second_translation TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            srs_interval INTEGER NOT NULL DEFAULT 0,
            srs_ease_factor REAL NOT NULL DEFAULT 2.5,
            srs_repetitions INTEGER NOT NULL DEFAULT 0,
            srs_next_due TEXT,
            srs_last_review TEXT
          )
        ''');
        // Single-row table for streak + study-day tracking.
        await db.execute('''
          CREATE TABLE app_state (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            current_streak INTEGER NOT NULL DEFAULT 0,
            longest_streak INTEGER NOT NULL DEFAULT 0,
            last_study_date TEXT
          )
        ''');
        await db.execute(
            "INSERT INTO app_state (id, current_streak, longest_streak) VALUES (1, 0, 0)");
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Migrate existing installs WITHOUT losing data. ALTER TABLE ADD COLUMN
        // only appends columns; all existing rows are preserved.
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE words ADD COLUMN note TEXT');
          await db.execute('ALTER TABLE words ADD COLUMN grammar_tip TEXT');
        }
        if (oldVersion < 3) {
          await db.execute(
              'ALTER TABLE words ADD COLUMN archived INTEGER NOT NULL DEFAULT 0');
        }
        if (oldVersion < 4) {
          // SM-2 SRS fields. All have safe defaults so pre-v4 cards become
          // eligible for review immediately (treated as new cards).
          await db.execute(
              'ALTER TABLE words ADD COLUMN srs_interval INTEGER NOT NULL DEFAULT 0');
          await db.execute(
              'ALTER TABLE words ADD COLUMN srs_ease_factor REAL NOT NULL DEFAULT 2.5');
          await db.execute(
              'ALTER TABLE words ADD COLUMN srs_repetitions INTEGER NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE words ADD COLUMN srs_next_due TEXT');
          await db.execute('ALTER TABLE words ADD COLUMN srs_last_review TEXT');

          // Bring forward any card already marked reviewed — schedule it
          // for today so the user's existing progress isn't lost.
          await db.execute(
              "UPDATE words SET srs_next_due = datetime('now') WHERE is_reviewed = 1 AND srs_next_due IS NULL");

          // Streak tracking table.
          await db.execute('''
            CREATE TABLE IF NOT EXISTS app_state (
              id INTEGER PRIMARY KEY CHECK (id = 1),
              current_streak INTEGER NOT NULL DEFAULT 0,
              longest_streak INTEGER NOT NULL DEFAULT 0,
              last_study_date TEXT
            )
          ''');
          await db.execute(
              'INSERT OR IGNORE INTO app_state (id, current_streak, longest_streak) VALUES (1, 0, 0)');
        }
        if (oldVersion < 5) {
          // Saved "also translate to" result. Null on existing rows.
          await db.execute('ALTER TABLE words ADD COLUMN second_lang TEXT');
          await db.execute(
              'ALTER TABLE words ADD COLUMN second_translation TEXT');
        }
      },
    );
  }

  /// Insert a new word. Returns the auto-incremented row ID.
  static Future<int> insertWord(Word word) async {
    final db = await database;
    return await db.insert('words', word.toMap());
  }

  /// Get all NON-archived words, ordered by the given SQL ORDER BY clause.
  /// Default: newest first (created_at DESC).
  /// Pass 'LOWER(word) ASC' for alphabetical sorting.
  static Future<List<Word>> getWords({String orderBy = 'created_at DESC'}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'words',
      where: 'archived = 0',
      orderBy: orderBy,
    );
    return List.generate(maps.length, (i) => Word.fromMap(maps[i]));
  }

  /// Get archived words only (for the Archived Words screen), newest first.
  static Future<List<Word>> getArchivedWords() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'words',
      where: 'archived = 1',
      orderBy: 'created_at DESC',
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
      where: 'archived = 0 AND (word LIKE ? OR translation LIKE ?)',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => Word.fromMap(maps[i]));
  }

  // ── SRS queries ─────────────────────────────────────────────────────

  /// Get all non-archived cards that are due (or overdue) for review.
  ///
  /// A card is due when `srs_next_due` has passed OR when it has never
  /// been scheduled (new card). The most-overdue cards come first; new
  /// cards (NULL due date) come after due cards but are still included
  /// so the UI can blend them via [getNewWords] separately if desired.
  ///
  /// Pass [limit] to cap the session size.
  static Future<List<Word>> getDueWords({int? limit}) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final List<Map<String, dynamic>> maps = await db.query(
      'words',
      where: 'archived = 0 AND (srs_next_due IS NOT NULL AND srs_next_due <= ?)',
      whereArgs: [now],
      orderBy: 'srs_next_due ASC',
      limit: limit,
    );
    return List.generate(maps.length, (i) => Word.fromMap(maps[i]));
  }

  /// Count of non-archived cards currently due. Cheap query for badges.
  static Future<int> getDueCount() async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM words '
      'WHERE archived = 0 AND srs_next_due IS NOT NULL AND srs_next_due <= ?',
      [now],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  /// Reset SRS for all non-archived cards — clear due dates, intervals,
  /// ease factors so every card becomes "new" again.
  static Future<void> resetAllSrs() async {
    final db = await database;
    await db.rawUpdate('''
      UPDATE words
      SET srs_next_due = NULL,
          srs_last_review = NULL,
          srs_interval = 0,
          srs_ease_factor = 2.5,
          srs_repetitions = 0,
          is_reviewed = 0
      WHERE archived = 0
    ''');
  }

  /// Get non-archived cards that have never been scheduled (new cards).
  /// Ordered oldest-first so the user sees the cards they added earliest.
  static Future<List<Word>> getNewWords({int? limit}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'words',
      where: 'archived = 0 AND srs_next_due IS NULL',
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return List.generate(maps.length, (i) => Word.fromMap(maps[i]));
  }

  /// Count of non-archived new (unscheduled) cards.
  static Future<int> getNewCount() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM words '
      'WHERE archived = 0 AND srs_next_due IS NULL',
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  // ── Streak / study-day tracking (app_state table) ───────────────────

  /// Immutable snapshot of the user's streak.
  static const StreakSnapshot zeroStreak =
      StreakSnapshot(current: 0, longest: 0, lastStudyDate: null);

  /// Read the streak row. Returns [zeroStreak] if missing (defensive).
  static Future<StreakSnapshot> getStreak() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT current_streak, longest_streak, last_study_date FROM app_state WHERE id = 1',
    );
    if (rows.isEmpty) return zeroStreak;
    final row = rows.first;
    return StreakSnapshot(
      current: (row['current_streak'] as int?) ?? 0,
      longest: (row['longest_streak'] as int?) ?? 0,
      lastStudyDate: row['last_study_date'] as String?,
    );
  }

  /// Record that the user studied today. Idempotent within the same day.
  ///
  /// Rules:
  ///   - First ever study → current = 1, longest = 1.
  ///   - Last study was yesterday → current += 1, longest = max(longest, current).
  ///   - Last study was today → no change.
  ///   - Otherwise (gap > 1 day) → current = 1.
  ///
  /// Returns the updated snapshot.
  static Future<StreakSnapshot> recordStudyDay() async {
    final db = await database;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayIso = _isoDate(today);

    final current = await getStreak();
    if (current.lastStudyDate == todayIso) return current; // already counted

    final int newCurrent;
    if (current.lastStudyDate == null) {
      newCurrent = 1;
    } else {
      final last = DateTime.tryParse(current.lastStudyDate!)?.toLocal();
      if (last == null) {
        newCurrent = 1;
      } else {
        final lastMidnight = DateTime(last.year, last.month, last.day);
        final dayDiff = today.difference(lastMidnight).inDays;
        if (dayDiff == 1) {
          newCurrent = current.current + 1;
        } else {
          // Gap > 1 day — streak broken, restart at 1.
          newCurrent = 1;
        }
      }
    }
    final newLongest = newCurrent > current.longest ? newCurrent : current.longest;

    await db.update(
      'app_state',
      {
        'current_streak': newCurrent,
        'longest_streak': newLongest,
        'last_study_date': todayIso,
      },
      where: 'id = 1',
    );

    return StreakSnapshot(
      current: newCurrent,
      longest: newLongest,
      lastStudyDate: todayIso,
    );
  }

  /// Format a [DateTime] as a stable `yyyy-MM-dd` string (date only).
  /// Used for streak comparisons where time-of-day must be ignored.
  static String _isoDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }
}

/// Immutable streak snapshot returned by [DatabaseService.getStreak] and
/// [DatabaseService.recordStudyDay]. [lastStudyDate] is a `yyyy-MM-dd`
/// string (or null if the user has never studied).
class StreakSnapshot {
  final int current;
  final int longest;
  final String? lastStudyDate;

  const StreakSnapshot({
    required this.current,
    required this.longest,
    required this.lastStudyDate,
  });

  /// True if [lastStudyDate] is today's date string.
  bool get studiedToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final m = today.month.toString().padLeft(2, '0');
    final d = today.day.toString().padLeft(2, '0');
    return lastStudyDate == '${today.year}-$m-$d';
  }
}
