// Unit tests for AnswerCheck — the typing-mode answer matcher.
//
// Includes the regression that motivated the Unicode-aware rewrite: answers
// in non-Latin scripts (Arabic, CJK, Cyrillic) must be able to match. The
// previous [a-z0-9äöüß] filter erased them to empty, so they never could.

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_vocab_builder/utils/answer_check.dart';

void main() {
  group('AnswerCheck.matches — Latin', () {
    test('exact match', () {
      expect(AnswerCheck.matches('house', 'house'), isTrue);
    });

    test('case-insensitive', () {
      expect(AnswerCheck.matches('House', 'hOuSe'), isTrue);
    });

    test('ignores surrounding punctuation and spaces', () {
      expect(AnswerCheck.matches('house', '  house! '), isTrue);
    });

    test('strips a leading article on either side', () {
      expect(AnswerCheck.matches('the house', 'house'), isTrue);
      expect(AnswerCheck.matches('house', 'the house'), isTrue);
      expect(AnswerCheck.matches('das Haus', 'Haus'), isTrue);
    });

    test('German umlauts / ß are preserved', () {
      expect(AnswerCheck.matches('Fußgänger', 'fußgänger'), isTrue);
    });

    test('wrong answer does not match', () {
      expect(AnswerCheck.matches('house', 'mouse'), isFalse);
    });

    test('empty input never matches', () {
      expect(AnswerCheck.matches('house', ''), isFalse);
      expect(AnswerCheck.matches('house', '   '), isFalse);
    });
  });

  group('AnswerCheck.matches — multiple meanings', () {
    test('any comma-separated meaning is accepted', () {
      expect(AnswerCheck.matches('money, bar, pub', 'bar'), isTrue);
      expect(AnswerCheck.matches('money, bar, pub', 'pub'), isTrue);
    });

    test('slash and semicolon separators also work', () {
      expect(AnswerCheck.matches('big / large', 'large'), isTrue);
      expect(AnswerCheck.matches('quick; fast', 'fast'), isTrue);
    });

    test('a meaning not in the list is rejected', () {
      expect(AnswerCheck.matches('money, bar', 'cash'), isFalse);
    });
  });

  group('AnswerCheck.matches — non-Latin scripts (regression)', () {
    test('Arabic answer matches an Arabic translation', () {
      expect(AnswerCheck.matches('زيتون', 'زيتون'), isTrue);
    });

    test('Arabic among multiple meanings', () {
      expect(AnswerCheck.matches('olive, زيتون', 'زيتون'), isTrue);
    });

    test('Chinese answer matches', () {
      expect(AnswerCheck.matches('房子', '房子'), isTrue);
    });

    test('Cyrillic answer matches (case-insensitive)', () {
      expect(AnswerCheck.matches('Дом', 'дом'), isTrue);
    });

    test('wrong non-Latin answer still fails', () {
      expect(AnswerCheck.matches('زيتون', 'تفاح'), isFalse);
    });
  });

  group('AnswerCheck.normalize', () {
    test('collapses internal whitespace', () {
      expect(AnswerCheck.normalize('hello   world'), 'hello world');
    });

    test('non-Latin text is not emptied out', () {
      expect(AnswerCheck.normalize('زيتون'), isNotEmpty);
    });
  });
}
