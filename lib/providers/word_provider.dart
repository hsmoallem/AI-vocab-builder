import 'package:flutter/foundation.dart';
import '../models/word.dart';
import '../services/database_service.dart';
import '../services/translation_service.dart';

enum SortMode { newestFirst, alphabetical }

class WordProvider extends ChangeNotifier {
  List<Word> _words = [];
  SortMode _sortMode = SortMode.newestFirst;
  final TranslationService _translationService = TranslationService();

  List<Word> get words => _words;
  SortMode get sortMode => _sortMode;

  WordProvider() {
    loadWords();
  }

  Future<void> loadWords() async {
    String orderBy = _sortMode == SortMode.alphabetical
        ? 'LOWER(word) ASC'
        : 'created_at DESC';
    _words = await DatabaseService.getWords(orderBy: orderBy);
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
  }) async {
    return await _translationService.translate(
      word: word,
      sourceLang: from,
      targetLang: to,
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

  Future<List<Word>> searchWords(String query) async {
    if (query.trim().isEmpty) {
      await loadWords();
      return _words;
    }
    return await DatabaseService.searchWords(query);
  }
}
