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
  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['id'] as int?,
      word: map['word'] as String,
      translation: map['translation'] as String,
      exampleSource: (map['example_source'] as String?) ?? '',
      exampleTarget: (map['example_target'] as String?) ?? '',
      sourceLang: map['source_lang'] as String,
      targetLang: map['target_lang'] as String,
      isReviewed: (map['is_reviewed'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Convert to a map for database storage.
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
