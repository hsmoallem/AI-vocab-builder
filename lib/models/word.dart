import 'package:isar/isar.dart';

part 'word.g.dart';

@collection
class Word {
  Id id = Isar.autoIncrement;

  @Index(unique: false)
  late String word;

  late String translation;
  late String exampleSource;
  late String exampleTarget;
  late String sourceLang;
  late String targetLang;

  @Index()
  bool isReviewed = false;

  late DateTime createdAt;
  late DateTime updatedAt;

  Word();

  factory Word.create({
    required String word,
    required String translation,
    required String exampleSource,
    required String exampleTarget,
    required String sourceLang,
    required String targetLang,
  }) {
    return Word()
      ..word = word
      ..translation = translation
      ..exampleSource = exampleSource
      ..exampleTarget = exampleTarget
      ..sourceLang = sourceLang
      ..targetLang = targetLang
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();
  }
}
