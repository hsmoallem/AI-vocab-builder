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
  // Free-text note the user can attach to a card (nullable — added in DB v2).
  String? note;
  // AI grammar/usage tip, generated on demand (nullable — added in DB v2).
  String? grammarTip;
  // Archived words are hidden from Saved Words + flashcards (added in DB v3).
  bool archived;
  // Optional "also translate to" result the user saved on the card (DB v5):
  // the extra language code and its translation, shown again on reopen.
  String? secondLang;
  String? secondTranslation;
  DateTime createdAt;
  DateTime updatedAt;

  // ── SRS fields (SM-2 algorithm — added in DB v4) ──────────────────
  // Defaults make a brand-new card "fresh and unscheduled": it has never
  // been studied, has the standard SM-2 easiness (2.5), and is immediately
  // eligible for the next review session.
  /// Days until next review. 0 = learning state (due immediately).
  int srsInterval;
  /// SM-2 easiness factor. Starts at 2.5, floored at 1.3.
  double srsEaseFactor;
  /// Consecutive successful reviews. Resets to 0 on "Again".
  int srsRepetitions;
  /// When the card is next due. null = never scheduled (new card).
  DateTime? srsNextDue;
  /// When the card was last reviewed. null = never reviewed.
  DateTime? srsLastReview;

  Word({
    this.id,
    required this.word,
    required this.translation,
    required this.exampleSource,
    required this.exampleTarget,
    required this.sourceLang,
    required this.targetLang,
    this.isReviewed = false,
    this.note,
    this.grammarTip,
    this.article,
    this.plural,
    this.feminineForm,
    this.masculineForm,
    this.partOfSpeech,
    this.infinitive,
    this.pastTense,
    this.pastParticiple,
    this.auxiliaryVerb,
    this.verbType,
    this.isReflexive = false,
    this.isSeparable = false,
    this.posPrepositions,
    this.archived = false,
    this.secondLang,
    this.secondTranslation,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.srsInterval = 0,
    this.srsEaseFactor = 2.5,
    this.srsRepetitions = 0,
    this.srsNextDue,
    this.srsLastReview,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Convenience: is this card due (or overdue) for review right now?
  ///
  /// A card is due when its scheduled time has passed, OR when it has
  /// never been scheduled (new card). Archived cards are never due.
  bool get isDue {
    if (archived) return false;
    final due = srsNextDue;
    if (due == null) return true; // new card
    return due.isBefore(DateTime.now());
  }

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

    // Nullable variant for SRS timestamps: a NULL column MUST stay null.
    // `srs_next_due == null` is how a card is identified as "new" / never
    // scheduled (and drives the "Studied" badge + a reset). Coercing null to
    // now() — as parseDate does — would make every card look scheduled/studied.
    DateTime? parseNullableDate(String? val) {
      if (val == null) return null;
      try {
        return DateTime.parse(val);
      } catch (_) {
        return null;
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
      // Nullable columns (added in DB v2) — absent on pre-v2 rows, which is fine.
      note: map['note'] as String?,
      grammarTip: map['grammar_tip'] as String?,
      article: map['article'] as String?,
      plural: map['plural'] as String?,
      feminineForm: map['feminine_form'] as String?,
      masculineForm: map['masculine_form'] as String?,
      partOfSpeech: map['part_of_speech'] as String?,
      infinitive: map['infinitive'] as String?,
      pastTense: map['past_tense'] as String?,
      pastParticiple: map['past_participle'] as String?,
      auxiliaryVerb: map['auxiliary_verb'] as String?,
      verbType: map['verb_type'] as String?,
      isReflexive: (map['is_reflexive'] as int?) == 1,
      isSeparable: (map['is_separable'] as int?) == 1,
      posPrepositions: map['pos_prepositions'] as String?,
      archived: (map['archived'] as int?) == 1,
      // Saved 2nd-language translation (DB v5) — null on pre-v5 rows.
      secondLang: map['second_lang'] as String?,
      secondTranslation: map['second_translation'] as String?,
      createdAt: parseDate(map['created_at'] as String?),
      updatedAt: parseDate(map['updated_at'] as String?),
      // SRS fields (DB v4). Absent on pre-v4 rows → defaults via the model.
      srsInterval: (map['srs_interval'] as int?) ?? 0,
      srsEaseFactor: (map['srs_ease_factor'] as num?)?.toDouble() ?? 2.5,
      srsRepetitions: (map['srs_repetitions'] as int?) ?? 0,
      srsNextDue: parseNullableDate(map['srs_next_due'] as String?),
      srsLastReview: parseNullableDate(map['srs_last_review'] as String?),
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
      'note': note,
      'grammar_tip': grammarTip,
      'article': article,
      'plural': plural,
      'feminine_form': feminineForm,
      'masculine_form': masculineForm,
      'part_of_speech': partOfSpeech,
      'infinitive': infinitive,
      'past_tense': pastTense,
      'past_participle': pastParticiple,
      'auxiliary_verb': auxiliaryVerb,
      'verb_type': verbType,
      'is_reflexive': isReflexive ? 1 : 0,
      'is_separable': isSeparable ? 1 : 0,
      'pos_prepositions': posPrepositions,
      'archived': archived ? 1 : 0,
      'second_lang': secondLang,
      'second_translation': secondTranslation,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'srs_interval': srsInterval,
      'srs_ease_factor': srsEaseFactor,
      'srs_repetitions': srsRepetitions,
      'srs_next_due': srsNextDue?.toIso8601String(),
      'srs_last_review': srsLastReview?.toIso8601String(),
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
    String? note,
    String? grammarTip,
    String? article,
    String? plural,
    String? feminineForm,
    String? masculineForm,
    String? partOfSpeech,
    String? infinitive,
    String? pastTense,
    String? pastParticiple,
    String? auxiliaryVerb,
    String? verbType,
    bool? isReflexive,
    bool? isSeparable,
    String? posPrepositions,
    bool? archived,
    String? secondLang,
    String? secondTranslation,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? srsInterval,
    double? srsEaseFactor,
    int? srsRepetitions,
    DateTime? srsNextDue,
    DateTime? srsLastReview,
    // Sentinel-aware optionals: pass [clearSrsNextDue] / [clearSrsLastReview]
    // to set the field back to null (copyWith's usual `??` pattern can't
    // distinguish "leave unchanged" from "explicitly null").
    bool clearSrsNextDue = false,
    bool clearSrsLastReview = false,
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
      note: note ?? this.note,
      grammarTip: grammarTip ?? this.grammarTip,
      article: article ?? this.article,
      plural: plural ?? this.plural,
      feminineForm: feminineForm ?? this.feminineForm,
      masculineForm: masculineForm ?? this.masculineForm,
      partOfSpeech: partOfSpeech ?? this.partOfSpeech,
      infinitive: infinitive ?? this.infinitive,
      pastTense: pastTense ?? this.pastTense,
      pastParticiple: pastParticiple ?? this.pastParticiple,
      auxiliaryVerb: auxiliaryVerb ?? this.auxiliaryVerb,
      verbType: verbType ?? this.verbType,
      isReflexive: isReflexive ?? this.isReflexive,
      isSeparable: isSeparable ?? this.isSeparable,
      posPrepositions: posPrepositions ?? this.posPrepositions,
      archived: archived ?? this.archived,
      secondLang: secondLang ?? this.secondLang,
      secondTranslation: secondTranslation ?? this.secondTranslation,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      srsInterval: srsInterval ?? this.srsInterval,
      srsEaseFactor: srsEaseFactor ?? this.srsEaseFactor,
      srsRepetitions: srsRepetitions ?? this.srsRepetitions,
      srsNextDue: clearSrsNextDue ? null : (srsNextDue ?? this.srsNextDue),
      srsLastReview:
          clearSrsLastReview ? null : (srsLastReview ?? this.srsLastReview),
    );
  }
}
