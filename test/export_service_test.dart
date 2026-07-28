import 'package:flutter_test/flutter_test.dart';
import 'package:ai_vocab_builder/models/word.dart';
import 'package:ai_vocab_builder/services/export_service.dart';

void main() {
  group('ExportService', () {
    test('toCsv includes canonical grammar data and usage note', () {
      final w = Word(
        word: 'Lehrer',
        translation: 'teacher',
        exampleSource: 'Der Lehrer unterrichtet.',
        exampleTarget: 'The teacher teaches.',
        sourceLang: 'de',
        targetLang: 'en',
      )..partOfSpeech = 'Noun'
       ..usageNote = 'Common title for teachers'
       ..grammarData = {
         'article': 'der',
         'plural': 'Lehrer',
         'feminine': 'Lehrerin',
         'ipa': 'ˈleːrɐ',
       };

      final csv = ExportService.toCsv([w]);
      expect(csv, contains('"Lehrer"'));
      expect(csv, contains('"Noun"'));
      expect(csv, contains('"ˈleːrɐ"'));
      expect(csv, contains('"der"'));
      expect(csv, contains('"Lehrerin"'));
      expect(csv, contains('"Common title for teachers"'));
    });

    test('toText formats grammar forms nicely', () {
      final w = Word(
        word: 'Lehrer',
        translation: 'teacher',
        exampleSource: 'Der Lehrer.',
        exampleTarget: 'The teacher.',
        sourceLang: 'de',
        targetLang: 'en',
      )..partOfSpeech = 'Noun'
       ..grammarData = {
         'article': 'der',
         'plural': 'Lehrer',
         'feminine': 'Lehrerin',
       };

      final text = ExportService.toText([w]);
      expect(text, contains('Lehrer  →  teacher'));
      expect(text, contains('Art: der'));
      expect(text, contains('Pl: Lehrer'));
      expect(text, contains('Fem: Lehrerin'));
    });
  });
}
