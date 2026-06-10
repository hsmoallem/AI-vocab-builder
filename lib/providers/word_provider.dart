import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/word.dart';
import '../services/database_service.dart';
import '../services/translation_service.dart';

enum SortMode { newestFirst, alphabetical }
enum LoadState { idle, loading, loaded, error }

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
  }) async {
    return await _translationService.translate(
      word: word,
      sourceLang: from,
      targetLang: to,
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
