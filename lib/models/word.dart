/// ─── Word Data Model ────────────────────────────────────────────────
///
/// Represents a vocabulary word stored in the local SQLite database.
/// Each word has a source language, target language translation,
/// example sentences in both languages, and review tracking.
///
/// ## Why this model structure
/// - **Flat, not nested:** The database is SQLite, not a document store.
///   Multiple meanings are stored as comma-separated values in `translation`
///   rather than a separate table — simpler for this app's scale.
/// - **Timestamps:** `createdAt` and `updatedAt` enable sort-by-newest
///   and future sync conflict resolution.
/// - **isReviewed:** Boolean flag for the flashcards feature — tracks
///   whether the user has flipped the card at least once.
///
/// ## Safe parsing in fromMap
/// The `parseDate` helper catches malformed date strings and returns
/// `DateTime.now()` instead of crashing. This was added after discovering
/// that manual DB edits could introduce invalid timestamp formats.

class Word {
  int? id;
  String word;
  String translation;
  String exampleSource;
  String exampleTarget;
  String sourceLang;
  String targetLang;
  bool isReviewed;
  DateTime createdAt;
  DateTime updatedAt;

  Word({
    this.id,
    required this.word,
    required this.translation,
    required this.exampleSource,
    required this.exampleTarget,
    required this.sourceLang,
    required this.targetLang,
    this.isReviewed = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Create from a database row map.
  /// All fields are null-safe — missing or null values become
  /// empty strings or defaults rather than throwing.
  factory Word.fromMap(Map<String, dynamic> map) {
    // Helper: safely parse ISO 8601 date strings.
    // Returns DateTime.now() on any parse failure to avoid crashes
    // from malformed data (e.g. manual DB edits).
    DateTime parseDate(String? val) {
      if (val == null) return DateTime.now();
      try {
        return DateTime.parse(val);
      } catch (_) {
        return DateTime.now();
      }
    }

    return Word(
      id: map['id'] as int?,
      word: (map['word'] as String?) ?? '',
      translation: (map['translation'] as String?) ?? '',
      exampleSource: (map['example_source'] as String?) ?? '',
      exampleTarget: (map['example_target'] as String?) ?? '',
      sourceLang: (map['source_lang'] as String?) ?? '',
      targetLang: (map['target_lang'] as String?) ?? '',
      isReviewed: (map['is_reviewed'] as int?) == 1,
      createdAt: parseDate(map['created_at'] as String?),
      updatedAt: parseDate(map['updated_at'] as String?),
    );
  }

  /// Convert to a map for database storage.
  /// Excludes `id` when null — SQLite auto-increments on insert,
  /// but needs the id on update.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'word': word,
      'translation': translation,
      'example_source': exampleSource,
      'example_target': exampleTarget,
      'source_lang': sourceLang,
      'target_lang': targetLang,
      'is_reviewed': isReviewed ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Create a copy with optional field changes.
  /// Used by the provider to toggle review status without
  /// mutating the original object (immutable update pattern).
  Word copyWith({
    int? id,
    String? word,
    String? translation,
    String? exampleSource,
    String? exampleTarget,
    String? sourceLang,
    String? targetLang,
    bool? isReviewed,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Word(
      id: id ?? this.id,
      word: word ?? this.word,
      translation: translation ?? this.translation,
      exampleSource: exampleSource ?? this.exampleSource,
      exampleTarget: exampleTarget ?? this.exampleTarget,
      sourceLang: sourceLang ?? this.sourceLang,
      targetLang: targetLang ?? this.targetLang,
      isReviewed: isReviewed ?? this.isReviewed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
