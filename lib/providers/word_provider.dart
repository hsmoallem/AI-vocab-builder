import 'package:flutter/foundation.dart';
import '../models/word.dart';
import '../services/database_service.dart';

enum SortMode { newestFirst, alphabetical }

class WordProvider extends ChangeNotifier {
  List<Word> _words = [];
  SortMode _sortMode = SortMode.newestFirst;

  List<Word> get words => _words;
  SortMode get sortMode => _sortMode;

  WordProvider() {
    loadWords();
  }

  Future<void> loadWords() async {
    String orderBy = _sortMode == SortMode.alphabetical
        ? 'LOWER(text) ASC'
        : 'created_at DESC';
    _words = await DatabaseService.getWords(orderBy: orderBy);
    notifyListeners();
  }

  void setSortMode(SortMode mode) {
    _sortMode = mode;
    loadWords();
  }

  Future<void> addWord(Word word) async {
    await DatabaseService.insertWord(word);
    await loadWords();
  }

  Future<void> deleteWord(int id) async {
    await DatabaseService.deleteWord(id);
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
