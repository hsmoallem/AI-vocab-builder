import 'package:flutter_test/flutter_test.dart';
import 'package:ai_vocab_builder/models/word.dart';

void main() {
  group('Word model', () {
    late Word word;

    setUp(() {
      word = Word(
        id: 1,
        word: 'Bar',
        translation: 'money, bar',
        exampleSource: 'Ich habe kein Bar.',
        exampleTarget: 'I have no cash.',
        sourceLang: 'de',
        targetLang: 'en',
        isReviewed: false,
        createdAt: DateTime(2026, 6, 7, 12, 0),
        updatedAt: DateTime(2026, 6, 7, 12, 0),
      );
    });

    test('creates with all fields', () {
      expect(word.id, 1);
      expect(word.word, 'Bar');
      expect(word.translation, 'money, bar');
      expect(word.exampleSource, 'Ich habe kein Bar.');
      expect(word.exampleTarget, 'I have no cash.');
      expect(word.sourceLang, 'de');
      expect(word.targetLang, 'en');
      expect(word.isReviewed, false);
    });

    test('defaults createdAt to now when not provided', () {
      final w = Word(
        word: 'test',
        translation: 'test',
        exampleSource: '',
        exampleTarget: '',
        sourceLang: 'de',
        targetLang: 'en',
      );
      expect(w.createdAt, isA<DateTime>());
      expect(w.updatedAt, isA<DateTime>());
    });

    test('defaults isReviewed to false', () {
      final w = Word(
        word: 'test',
        translation: 'test',
        exampleSource: '',
        exampleTarget: '',
        sourceLang: 'de',
        targetLang: 'en',
      );
      expect(w.isReviewed, false);
    });

    test('toMap produces correct map', () {
      final map = word.toMap();
      expect(map['id'], 1);
      expect(map['word'], 'Bar');
      expect(map['translation'], 'money, bar');
      expect(map['example_source'], 'Ich habe kein Bar.');
      expect(map['example_target'], 'I have no cash.');
      expect(map['source_lang'], 'de');
      expect(map['target_lang'], 'en');
      expect(map['is_reviewed'], 0);
      expect(map['created_at'], '2026-06-07T12:00:00.000');
      expect(map['updated_at'], '2026-06-07T12:00:00.000');
    });

    test('toMap excludes null id', () {
      final w = Word(
        word: 'test',
        translation: 'test',
        exampleSource: '',
        exampleTarget: '',
        sourceLang: 'de',
        targetLang: 'en',
      );
      final map = w.toMap();
      expect(map.containsKey('id'), false);
    });

    test('fromMap parses all fields', () {
      final map = {
        'id': 1,
        'word': 'Bar',
        'translation': 'money',
        'example_source': 'Ich habe Bar.',
        'example_target': 'I have cash.',
        'source_lang': 'de',
        'target_lang': 'en',
        'is_reviewed': 1,
        'created_at': '2026-06-07T12:00:00.000',
        'updated_at': '2026-06-07T12:00:00.000',
      };
      final w = Word.fromMap(map);
      expect(w.id, 1);
      expect(w.word, 'Bar');
      expect(w.translation, 'money');
      expect(w.exampleSource, 'Ich habe Bar.');
      expect(w.exampleTarget, 'I have cash.');
      expect(w.isReviewed, true);
      expect(w.createdAt, DateTime(2026, 6, 7, 12, 0));
    });

    test('fromMap handles nulls and missing fields gracefully', () {
      final map = <String, dynamic>{
        'id': 1,
      };
      final w = Word.fromMap(map);
      expect(w.word, '');
      expect(w.translation, '');
      expect(w.exampleSource, '');
      expect(w.exampleTarget, '');
      expect(w.sourceLang, '');
      expect(w.targetLang, '');
      expect(w.isReviewed, false);
      expect(w.createdAt, isA<DateTime>());
      expect(w.updatedAt, isA<DateTime>());
    });

    test('fromMap handles malformed dates', () {
      final map = {
        'id': 1,
        'word': 'test',
        'translation': 'test',
        'example_source': '',
        'example_target': '',
        'source_lang': 'de',
        'target_lang': 'en',
        'is_reviewed': 0,
        'created_at': 'not-a-date',
        'updated_at': 'also-not-a-date',
      };
      final w = Word.fromMap(map);
      // Should not throw, should default to now
      expect(w.createdAt, isA<DateTime>());
      expect(w.updatedAt, isA<DateTime>());
    });

    test('copyWith replaces specified fields', () {
      final updated = word.copyWith(
        translation: 'cash, counter',
        isReviewed: true,
      );
      expect(updated.translation, 'cash, counter');
      expect(updated.isReviewed, true);
      // Unchanged fields
      expect(updated.word, 'Bar');
      expect(updated.id, 1);
    });

    test('copyWith keeps unchanged fields', () {
      final updated = word.copyWith();
      expect(updated.word, word.word);
      expect(updated.translation, word.translation);
      expect(updated.isReviewed, word.isReviewed);
    });

    test('roundtrip: toMap then fromMap', () {
      final map = word.toMap();
      final restored = Word.fromMap(map);
      expect(restored.word, word.word);
      expect(restored.translation, word.translation);
      expect(restored.exampleSource, word.exampleSource);
      expect(restored.exampleTarget, word.exampleTarget);
      expect(restored.isReviewed, word.isReviewed);
    });

    test('saved 2nd-language translation survives toMap/fromMap (DB v5)', () {
      final w = word.copyWith(secondLang: 'fr', secondTranslation: 'argent');
      final map = w.toMap();
      expect(map['second_lang'], 'fr');
      expect(map['second_translation'], 'argent');
      final restored = Word.fromMap(map);
      expect(restored.secondLang, 'fr');
      expect(restored.secondTranslation, 'argent');
    });

    test('2nd-language fields are null when absent (pre-v5 rows)', () {
      final w = Word.fromMap({
        'word': 'Haus',
        'translation': 'house',
        'source_lang': 'de',
        'target_lang': 'en',
        // no second_lang / second_translation columns
      });
      expect(w.secondLang, isNull);
      expect(w.secondTranslation, isNull);
    });

    test('canonical grammar fields survive toMap/fromMap and copyWith (DB v6)', () {
      final w = word.copyWith(
        partOfSpeech: 'Verb',
        usageNote: 'Used across all formal and informal situations.',
        grammarVersion: 1,
        grammarConfidence: 0.98,
        grammarData: {
          'infinitive': 'arbeiten',
          'simple_past': 'arbeitete',
          'past_participle': 'gearbeitet',
          'auxiliary': 'haben',
          'is_irregular': false,
          'is_separable': false,
          'pronunciation': {
            'ipa': '/aʁˈbaɪ̯tən/',
            'stress': '2nd syllable',
          },
          'extra': {'register': 'neutral'}
        },
      );
      final map = w.toMap();
      expect(map['part_of_speech'], 'Verb');
      expect(map['usage_note'], 'Used across all formal and informal situations.');
      expect(map['grammar_version'], 1);
      expect(map['grammar_confidence'], 0.98);
      expect(map['grammar_data'], isA<String>());

      final restored = Word.fromMap(map);
      expect(restored.partOfSpeech, 'Verb');
      expect(restored.usageNote, 'Used across all formal and informal situations.');
      expect(restored.grammarVersion, 1);
      expect(restored.grammarConfidence, 0.98);
      expect(restored.grammarData?['infinitive'], 'arbeiten');
      expect(restored.grammarData?['extra']?['register'], 'neutral');
      expect(restored.ipa, '/aʁˈbaɪ̯tən/');
      expect(restored.stress, '2nd syllable');
      expect(restored.isIrregular, false);
      expect(restored.isSeparable, false);
    });

    test('grammar booleans return correct true flags', () {
      final w = Word(
        word: 'aufstehen',
        translation: 'to get up',
        exampleSource: 'Ich stehe auf.',
        exampleTarget: 'I get up.',
        sourceLang: 'de',
        targetLang: 'en',
        grammarData: {
          'is_irregular': true,
          'is_separable': true,
          'is_reflexive': true,
          'is_uncountable': true,
        },
      );
      expect(w.isIrregular, true);
      expect(w.isSeparable, true);
      expect(w.isReflexive, true);
      expect(w.isUncountable, true);
    });

    test('v6 fields default cleanly when absent (pre-v6 rows)', () {
      final w = Word.fromMap({
        'word': 'Job',
        'translation': 'job',
        'source_lang': 'de',
        'target_lang': 'en',
      });
      expect(w.partOfSpeech, isNull);
      expect(w.grammarData, isNull);
      expect(w.usageNote, isNull);
      expect(w.grammarVersion, 0);
      expect(w.grammarConfidence, isNull);
      expect(w.isIrregular, false);
      expect(w.ipa, isNull);
    });
  });
}
