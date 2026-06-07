import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/word.dart';

class DatabaseService {
  static DatabaseService? _instance;
  late Isar _isar;

  DatabaseService._();

  static DatabaseService get instance {
    _instance ??= DatabaseService._();
    return _instance!;
  }

  Isar get isar => _isar;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [WordSchema],
      directory: dir.path,
    );
  }

  // ── Word CRUD ──

  Future<int> addWord(Word word) async {
    word.updatedAt = DateTime.now();
    return _isar.writeTxn(() => _isar.words.put(word));
  }

  Future<List<Word>> getAllWords({String? searchQuery}) async {
    final query = _isar.words.where();
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      query.filter().wordContains(q).or().translationContains(q);
    }
    return query.sortByCreatedAtDesc().findAll();
  }

  Future<Word?> getWord(int id) async {
    return _isar.words.get(id);
  }

  Future<void> updateWord(Word word) async {
    word.updatedAt = DateTime.now();
    await _isar.writeTxn(() => _isar.words.put(word));
  }

  Future<void> deleteWord(int id) async {
    await _isar.writeTxn(() => _isar.words.delete(id));
  }

  Future<List<Word>> getUnreviewedWords() async {
    return _isar.words
        .filter()
        .isReviewedEqualTo(false)
        .sortByCreatedAtDesc()
        .findAll();
  }

  Future<int> getUnreviewedCount() async {
    return _isar.words.filter().isReviewedEqualTo(false).count();
  }

  Future<int> getWordCount() async {
    return _isar.words.count();
  }

  Future<void> close() async {
    await _isar.close();
  }
}
