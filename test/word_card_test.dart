import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_vocab_builder/models/word.dart';
import 'package:ai_vocab_builder/widgets/word_card.dart';

void main() {
  final testWord = Word(
    id: 1,
    word: 'Bar',
    translation: 'money, bar',
    exampleSource: 'Ich habe kein Bar.',
    exampleTarget: 'I have no cash.',
    sourceLang: 'de',
    targetLang: 'en',
  );

  Widget buildCard({VoidCallback? onDelete, VoidCallback? onToggleReview}) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: WordCard(
            word: testWord,
            onDelete: onDelete,
            onToggleReview: onToggleReview,
          ),
        ),
      ),
    );
  }

  group('WordCard', () {
    testWidgets('displays word text', (tester) async {
      await tester.pumpWidget(buildCard());
      expect(find.text('Bar'), findsOneWidget);
    });

    testWidgets('displays translation', (tester) async {
      await tester.pumpWidget(buildCard());
      expect(find.text('money, bar'), findsOneWidget);
    });

    testWidgets('displays language badges', (tester) async {
      await tester.pumpWidget(buildCard());
      expect(find.text('DE'), findsOneWidget);
      expect(find.text('EN'), findsOneWidget);
    });

    testWidgets('displays example source', (tester) async {
      await tester.pumpWidget(buildCard());
      expect(find.text('Ich habe kein Bar.'), findsOneWidget);
    });

    testWidgets('displays example target', (tester) async {
      await tester.pumpWidget(buildCard());
      expect(find.text('I have no cash.'), findsOneWidget);
    });

    testWidgets('shows delete button when onDelete provided', (tester) async {
      await tester.pumpWidget(buildCard(onDelete: () {}));
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('hides delete button when onDelete is null', (tester) async {
      await tester.pumpWidget(buildCard(onDelete: null));
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets('shows review toggle when onToggleReview provided', (tester) async {
      await tester.pumpWidget(buildCard(onToggleReview: () {}));
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('hides review toggle when onToggleReview is null', (tester) async {
      await tester.pumpWidget(buildCard(onToggleReview: null));
      expect(find.byIcon(Icons.check_circle_outline), findsNothing);
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('shows filled check when reviewed', (tester) async {
      final reviewed = testWord.copyWith(isReviewed: true);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: WordCard(word: reviewed, onToggleReview: () {}),
        ),
      ));
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('calls onDelete callback when tapped', (tester) async {
      bool called = false;
      await tester.pumpWidget(buildCard(onDelete: () => called = true));
      await tester.tap(find.byIcon(Icons.delete_outline));
      expect(called, true);
    });

    testWidgets('calls onToggleReview callback when tapped', (tester) async {
      bool called = false;
      await tester.pumpWidget(buildCard(onToggleReview: () => called = true));
      await tester.tap(find.byIcon(Icons.check_circle_outline));
      expect(called, true);
    });

    testWidgets('handles empty examples without error', (tester) async {
      final noExamples = Word(
        word: 'test',
        translation: 'test',
        exampleSource: '',
        exampleTarget: '',
        sourceLang: 'de',
        targetLang: 'en',
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: WordCard(word: noExamples),
        ),
      ));
      // Should render without throwing
      expect(find.text('test'), findsOneWidget);
    });
  });
}
