import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/word.dart';
import '../services/database_service.dart';
import '../services/translation_service.dart';
import '../services/srs_service.dart';

enum SortMode { newestFirst, alphabetical }
enum LoadState { idle, loading, loaded, error }

/// Outcome of importing one word during a bulk import.
enum ImportStatus { added, duplicate, failed }

/// Result returned by [WordProvider.processReview]. Carries the new due
/// count + streak snapshot so the UI can update badges without re-querying.
class ReviewResult {
  final int remainingDue;
  final StreakSnapshot streak;
  const ReviewResult({required this.remainingDue, required this.streak});
}

class WordProvider extends ChangeNotifier {
  List<Word> _words = [];
  SortMode _sortMode = SortMode.newestFirst;
  LoadState _state = LoadState.idle;
  String? _error;
  final TranslationService _translationService = TranslationService();

  // ── SRS session state ──────────────────────────────────────────────
  // Cached due/new-card counts drive the home-screen badge. Refreshed on
  // app start, after every review, and after archive/restore/import.
  List<Word> _dueWords = [];
  List<Word> _newWords = [];
  int _dueCount = 0;
  int _newCount = 0;
  StreakSnapshot _streak = DatabaseService.zeroStreak;

  List<Word> get words => _words;
  SortMode get sortMode => _sortMode;
  LoadState get state => _state;
  String? get error => _error;
  bool get isLoading => _state == LoadState.loading;

  /// Words currently due or overdue for review (cached).
  List<Word> get dueWords => List.unmodifiable(_dueWords);
  /// New (unscheduled) cards available to introduce (cached).
  List<Word> get newWords => List.unmodifiable(_newWords);
  /// Count of due cards — drives the home-screen flashcard badge.
  int get dueCount => _dueCount;
  /// Count of new (unscheduled) cards.
  int get newCount => _newCount;
  /// Current streak snapshot (cached).
  StreakSnapshot get streak => _streak;

  WordProvider() {
    loadWords();
    refreshSrs();
  }

  /// Reload due/new counts and streak from the DB. Cheap; safe to call
  /// after any mutation (review, archive, add, restore).
  Future<void> refreshSrs() async {
    final due = await DatabaseService.getDueCount();
    final fresh = await DatabaseService.getNewCount();
    final streak = await DatabaseService.getStreak();
    _dueCount = due;
    _newCount = fresh;
    _streak = streak;
    notifyListeners();
  }

  /// Load the full due + new card lists for a review session.
  ///
  /// Due cards come first (most-overdue first), then new cards. New cards
  /// are capped at [maxNewCards] per session so the user is not flooded
  /// with cards they have never seen.
  Future<void> loadDueWords({int maxNewCards = 30}) async {
    _dueWords = await DatabaseService.getDueWords();
    _newWords = await DatabaseService.getNewWords(limit: maxNewCards);
    _dueCount = _dueWords.length;
    _newCount = _newWords.length;
    notifyListeners();
  }

  /// Get the streak snapshot (re-queried).
  Future<StreakSnapshot> fetchStreak() async {
    _streak = await DatabaseService.getStreak();
    return _streak;
  }

  Future<void> loadWords() async {
    _state = LoadState.loading;
    notifyListeners();

    try {
      String orderBy = _sortMode == SortMode.alphabetical
          ? 'LOWER(word) ASC'
          : 'created_at DESC';
      _words = await DatabaseService.getWords(orderBy: orderBy);
      _state = LoadState.loaded;
      _error = null;
    } catch (e) {
      _state = LoadState.error;
      _error = e.toString();
    }

    notifyListeners();
  }

  void setSortMode(SortMode mode) {
    _sortMode = mode;
    loadWords();
  }

  /// Translate a word using DeepSeek AI
  Future<TranslationResult> translateWord(
    String word, {
    required String from,
    required String to,
    String? level,
  }) async {
    return await _translationService.translate(
      word: word,
      sourceLang: from,
      targetLang: to,
      level: level,
      firebaseUid: FirebaseAuth.instance.currentUser?.uid,
    );
  }

  /// Add a new word with all fields
  Future<bool> addWord({
    required String word,
    required String translation,
    required String exampleSource,
    required String exampleTarget,
    required String sourceLang,
    required String targetLang,
  }) async {
    final w = Word(
      word: word,
      translation: translation,
      exampleSource: exampleSource,
      exampleTarget: exampleTarget,
      sourceLang: sourceLang,
      targetLang: targetLang,
    );
    await DatabaseService.insertWord(w);
    await loadWords();
    return true;
  }

  /// Translate ONE word and persist it as part of a bulk import.
  ///
  /// This deliberately reuses the exact same translation + example-generation
  /// workflow as the single-word Add flow (see [AddWordDialog]): the same
  /// `translate()` call, the same corrected-spelling replacement, the same
  /// German-article prefix rule, and the same meaning/example formatting.
  ///
  /// It does NOT reload the word list — the caller reloads once after the whole
  /// batch (avoids an O(n²) reload per word). Never throws: failures come back
  /// as an [ImportOutcome] with [ImportStatus.failed].
  Future<ImportOutcome> importWord({
    required String input,
    required String from,
    required String to,
    String? level,
  }) async {
    final word = input.trim();
    if (word.isEmpty) {
      return ImportOutcome(input, ImportStatus.failed, error: 'Empty line');
    }
    try {
      final result = await _translationService.translate(
        word: word,
        sourceLang: from,
        targetLang: to,
        level: level,
        firebaseUid: FirebaseAuth.instance.currentUser?.uid,
      );

      // Corrected spelling — replace the typed word with the server's fix.
      String finalWord = word;
      final corrected = result.corrected?.trim();
      if (corrected != null &&
          corrected.isNotEmpty &&
          corrected.toLowerCase() != word.toLowerCase()) {
        finalWord = corrected;
      }

      // Prepend the article (der/die/das) ONLY when the source is German.
      final article =
          result.meanings.isNotEmpty ? result.meanings.first.article : null;
      if (from == 'de' &&
          article != null &&
          article.isNotEmpty &&
          !finalWord.startsWith(article)) {
        finalWord = '$article $finalWord';
      }

      // Build stored fields exactly like the Add dialog's _save().
      final translation = result.meanings
          .where((m) => m.text.trim().isNotEmpty)
          .map((m) => m.text.trim())
          .join(', ');
      final exampleSource = result.meanings
          .where((m) => m.exampleSource.trim().isNotEmpty)
          .map((m) => '• ${m.exampleSource.trim()}')
          .join('\n');
      final exampleTarget = result.meanings
          .where((m) => m.exampleTarget.trim().isNotEmpty)
          .map((m) => '• ${m.exampleTarget.trim()}')
          .join('\n');

      if (translation.isEmpty) {
        return ImportOutcome(input, ImportStatus.failed,
            error: 'No translation returned');
      }

      await DatabaseService.insertWord(Word(
        word: finalWord,
        translation: translation,
        exampleSource: exampleSource,
        exampleTarget: exampleTarget,
        sourceLang: from,
        targetLang: to,
      ));
      return ImportOutcome(input, ImportStatus.added, savedWord: finalWord);
    } catch (e) {
      return ImportOutcome(input, ImportStatus.failed, error: e.toString());
    }
  }

  /// Add a word from a [Word] object (used by cloud restore).
  Future<bool> addWordObject(Word word) async {
    // Don't carry over the old ID — let SQLite assign a new one.
    final w = Word(
      word: word.word,
      translation: word.translation,
      exampleSource: word.exampleSource,
      exampleTarget: word.exampleTarget,
      sourceLang: word.sourceLang,
      targetLang: word.targetLang,
      note: word.note,
      grammarTip: word.grammarTip,
      archived: word.archived,
    );
    await DatabaseService.insertWord(w);
    await loadWords();
    return true;
  }

  Future<void> deleteWord(int id) async {
    await DatabaseService.deleteWord(id);
    await loadWords();
  }

  Future<void> toggleReview(Word word) async {
    final updated = word.copyWith(isReviewed: !word.isReviewed);
    await DatabaseService.updateWord(updated);
    await loadWords();
  }

  Future<void> updateWord(Word word) async {
    await DatabaseService.updateWord(word);
    await loadWords();
  }

  /// Save a free-text note on a word. Pass '' to clear it.
  Future<void> updateNote(Word word, String note) async {
    await DatabaseService.updateWord(word.copyWith(note: note));
    await loadWords();
  }

  /// Persist the "also translate to" result on a card so it reappears on reopen.
  Future<void> updateSecondTranslation(
      Word word, String lang, String translation) async {
    await DatabaseService.updateWord(word.copyWith(
        secondLang: lang, secondTranslation: translation));
    await loadWords();
  }

  /// Archive a word — hides it from Saved Words AND the flashcard deck.
  Future<void> archiveWord(Word word) async {
    await DatabaseService.updateWord(word.copyWith(archived: true));
    await loadWords();
    await refreshSrs();
  }

  /// Restore an archived word so it shows again.
  Future<void> unarchiveWord(Word word) async {
    await DatabaseService.updateWord(word.copyWith(archived: false));
    await loadWords();
    await refreshSrs();
  }

  /// Archived words (for the Archived Words screen).
  Future<List<Word>> archivedWords() => DatabaseService.getArchivedWords();

  /// Regenerate the example sentence(s) for [word] using the SAME translation
  /// workflow (same `translate()` call + `• `-bulleted formatting as the Add /
  /// bulk-import flows). Keeps the stored translation; only the examples change.
  Future<void> regenerateExample(Word word, {String? level}) async {
    // Collect the current example sentence(s) (strip "• " bullets) so the server
    // produces a brand-new example in a different context, not a reworded copy.
    final avoid = <String>[];
    for (final line in '${word.exampleSource}\n${word.exampleTarget}'.split('\n')) {
      final t = line.replaceFirst(RegExp(r'^[•\-\s]+'), '').trim();
      if (t.isNotEmpty) avoid.add(t);
    }
    final result = await _translationService.translate(
      word: word.word,
      sourceLang: word.sourceLang,
      targetLang: word.targetLang,
      level: level,
      avoid: avoid.isEmpty ? null : avoid,
      firebaseUid: FirebaseAuth.instance.currentUser?.uid,
    );
    final exampleSource = result.meanings
        .where((m) => m.exampleSource.trim().isNotEmpty)
        .map((m) => '• ${m.exampleSource.trim()}')
        .join('\n');
    final exampleTarget = result.meanings
        .where((m) => m.exampleTarget.trim().isNotEmpty)
        .map((m) => '• ${m.exampleTarget.trim()}')
        .join('\n');
    // Only overwrite when we actually got fresh examples back.
    if (exampleSource.isEmpty && exampleTarget.isEmpty) return;
    await DatabaseService.updateWord(word.copyWith(
      exampleSource: exampleSource,
      exampleTarget: exampleTarget,
    ));
    await loadWords();
  }

  /// Fetch an AI grammar/usage tip for [word] and persist it. Returns the tip
  /// ('' when there's nothing noteworthy — stored so the UI knows it was tried).
  Future<String> generateGrammarTipFor(Word word, {String? level}) async {
    final tip = await _translationService.generateGrammarTip(
      word: word.word,
      sourceLang: word.sourceLang,
      targetLang: word.targetLang,
      level: level,
      firebaseUid: FirebaseAuth.instance.currentUser?.uid,
    );
    await DatabaseService.updateWord(word.copyWith(grammarTip: tip));
    await loadWords();
    return tip;
  }

  /// Remove duplicate words (same text + same language pair, case-insensitive),
  /// keeping the OLDEST of each group. Returns how many were removed.
  Future<int> removeDuplicates() async {
    final seen = <String>{};
    final toDelete = <int>[];
    // Oldest first (lowest id) so the first-added occurrence is the keeper.
    final sorted = [..._words]..sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));
    for (final w in sorted) {
      final key =
          '${w.word.trim().toLowerCase()}|${w.sourceLang}|${w.targetLang}';
      if (!seen.add(key) && w.id != null) {
        toDelete.add(w.id!);
      }
    }
    for (final id in toDelete) {
      await DatabaseService.deleteWord(id);
    }
    if (toDelete.isNotEmpty) await loadWords();
    return toDelete.length;
  }

  Future<List<Word>> searchWords(String query) async {
    if (query.trim().isEmpty) {
      await loadWords();
      return _words;
    }
    return await DatabaseService.searchWords(query);
  }

  // ── SRS / review session ───────────────────────────────────────────

  /// Apply one review rating to [word] and persist the new SRS state.
  ///
  /// Steps:
  ///   1. Run the pure SM-2 calc via [SrsService.next].
  ///   2. Persist the new state (and mark the word reviewed).
  ///   3. Record today as a study day for streak tracking.
  ///   4. Refresh due/new counts + streak snapshot.
  ///   5. Update the cached [words] list in place.
  ///
  /// Returns a [ReviewResult] with the remaining due count and the
  /// (possibly updated) streak, so the UI can react without re-querying.
  Future<ReviewResult> processReview(Word word, Rating rating) async {
    final next = SrsService.next(
      repetitions: word.srsRepetitions,
      easeFactor: word.srsEaseFactor,
      interval: word.srsInterval,
      rating: rating,
    );

    final updated = word.copyWith(
      isReviewed: true,
      srsInterval: next.intervalDays,
      srsEaseFactor: next.easeFactor,
      srsRepetitions: next.repetitions,
      srsNextDue: next.nextDue,
      srsLastReview: next.lastReview,
      updatedAt: DateTime.now(),
    );

    await DatabaseService.updateWord(updated);

    // Update the cached word in _words so the UI shows new SRS state.
    final idx = _words.indexWhere((w) => w.id == word.id);
    if (idx >= 0) _words[idx] = updated;

    // Streak recording (idempotent within the same day).
    _streak = await DatabaseService.recordStudyDay();

    _dueCount = await DatabaseService.getDueCount();
    notifyListeners();

    return ReviewResult(remainingDue: _dueCount, streak: _streak);
  }

  /// Reset a word's SRS state — marks it as never studied so it appears
  /// as a "new" card in the next study session.
  Future<void> resetSrs(Word word) async {
    final db = await DatabaseService.database;
    await db.rawUpdate('''
      UPDATE words
      SET srs_next_due = NULL,
          srs_last_review = NULL,
          srs_interval = 0,
          srs_ease_factor = 2.5,
          srs_repetitions = 0
      WHERE id = ?
    ''', [word.id]);
    // Reload to get the updated word
    final idx = _words.indexWhere((w) => w.id == word.id);
    if (idx >= 0) {
      _words[idx] = _words[idx].copyWith(
        srsInterval: 0,
        srsEaseFactor: 2.5,
        srsRepetitions: 0,
        clearSrsNextDue: true,
        clearSrsLastReview: true,
      );
    }
    notifyListeners();
  }

  /// Reset SRS for all non-archived words — marks every card as "new"
  /// so all cards are available for fresh study.
  Future<void> resetAllSrs() async {
    await DatabaseService.resetAllSrs();
    await loadWords();
    _dueCount = 0;
    _newCount = _words.length;
    notifyListeners();
  }

  /// Combine due + new cards into a single ordered session deck.
  ///
  /// Due cards come first (most-overdue first), then new cards (oldest
  /// first). The total deck size is capped at [maxCards] — due cards get
  /// priority, and new cards fill the remaining slots up to the limit.
  Future<List<Word>> buildSessionDeck({int maxCards = 30}) async {
    // Load all due and new cards, then slice to maxCards total.
    _dueWords = await DatabaseService.getDueWords();
    _newWords = await DatabaseService.getNewWords(); // get all, slice below
    _dueCount = _dueWords.length;
    _newCount = _newWords.length;
    notifyListeners();

    final deck = <Word>[];
    // Due cards first (capped at maxCards)
    deck.addAll(_dueWords.take(maxCards));
    // Fill remaining with new cards
    final remaining = maxCards - deck.length;
    if (remaining > 0) {
      deck.addAll(_newWords.take(remaining));
    }
    return deck;
  }
}

/// Result of importing a single word during a bulk import.
class ImportOutcome {
  final String input; // the raw word from the pasted/loaded list
  final ImportStatus status;
  final String? savedWord; // final stored form (may include article/correction)
  final String? error; // failure reason, if any

  ImportOutcome(this.input, this.status, {this.savedWord, this.error});
}
