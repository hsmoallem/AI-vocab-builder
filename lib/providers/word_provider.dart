import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/word.dart';
import '../services/database_service.dart';
import '../services/translation_service.dart';

enum SortMode { newestFirst, alphabetical }
enum LoadState { idle, loading, loaded, error }

/// Outcome of importing one word during a bulk import.
enum ImportStatus { added, duplicate, failed }

class WordProvider extends ChangeNotifier {
  List<Word> _words = [];
  SortMode _sortMode = SortMode.newestFirst;
  LoadState _state = LoadState.idle;
  String? _error;
  final TranslationService _translationService = TranslationService();

  List<Word> get words => _words;
  SortMode get sortMode => _sortMode;
  LoadState get state => _state;
  String? get error => _error;
  bool get isLoading => _state == LoadState.loading;

  WordProvider() {
    loadWords();
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

  /// Regenerate the example sentence(s) for [word] using the SAME translation
  /// workflow (same `translate()` call + `• `-bulleted formatting as the Add /
  /// bulk-import flows). Keeps the stored translation; only the examples change.
  Future<void> regenerateExample(Word word, {String? level}) async {
    final result = await _translationService.translate(
      word: word.word,
      sourceLang: word.sourceLang,
      targetLang: word.targetLang,
      level: level,
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
}

/// Result of importing a single word during a bulk import.
class ImportOutcome {
  final String input; // the raw word from the pasted/loaded list
  final ImportStatus status;
  final String? savedWord; // final stored form (may include article/correction)
  final String? error; // failure reason, if any

  ImportOutcome(this.input, this.status, {this.savedWord, this.error});
}
