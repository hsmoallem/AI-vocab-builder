import 'package:flutter/material.dart';
import '../models/word.dart';
import '../services/database_service.dart';
import '../services/translation_service.dart';

class WordProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;
  final TranslationService _translator = TranslationService();

  List<Word> _words = [];
  bool _isLoading = false;
  String? _error;

  List<Word> get words => _words;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get wordCount => _words.length;
  int get unreviewedCount => _words.where((w) => !w.isReviewed).length;

  Future<void> loadWords({String? searchQuery}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _words = await _db.getAllWords(searchQuery: searchQuery);
    } catch (e) {
      _error = 'Failed to load words: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addWord({
    required String word,
    required String translation,
    required String exampleSource,
    required String exampleTarget,
    required String sourceLang,
    required String targetLang,
  }) async {
    try {
      final w = Word(
        word: word,
        translation: translation,
        exampleSource: exampleSource,
        exampleTarget: exampleTarget,
        sourceLang: sourceLang,
        targetLang: targetLang,
      );
      await _db.addWord(w);
      await loadWords();
      return true;
    } catch (e) {
      _error = 'Failed to save word: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> deleteWord(int id) async {
    await _db.deleteWord(id);
    await loadWords();
  }

  Future<void> toggleReviewed(Word word) async {
    word.isReviewed = !word.isReviewed;
    await _db.updateWord(word);
    await loadWords();
  }

  Future<void> updateWord(Word word) async {
    await _db.updateWord(word);
    await loadWords();
  }

  Future<TranslationResult> translateWord(String word, {String from = 'de', String to = 'en'}) async {
    return _translator.translate(word: word, sourceLang: from, targetLang: to);
  }

  Future<bool> isApiKeyConfigured() async {
    return _translator.isConfigured();
  }

  Future<void> setApiKey(String key) async {
    await _translator.setApiKey(key);
  }

  List<Word> get unreviewedWords => _words.where((w) => !w.isReviewed).toList();
}
