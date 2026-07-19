/// ─── Review Session Screen ──────────────────────────────────────────
///
/// Drives one spaced-repetition study session. Cards come from
/// [WordProvider.buildSessionDeck] (due first, then new). Each card is
/// shown per the chosen [StudyMode]; after revealing the answer the user
/// rates recall (Again/Hard/Good/Easy), which is scheduled via SM-2
/// ([WordProvider.processReview]). "Again" cards re-appear later in the
/// session. When the deck is exhausted, the [ReviewSummaryScreen] is shown.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/study_mode.dart';
import '../models/word.dart';
import '../providers/word_provider.dart';
import '../services/database_service.dart'; // StreakSnapshot
import '../services/srs_service.dart';
import '../services/tts_service.dart';
import 'review_summary_screen.dart';

class ReviewSessionScreen extends StatefulWidget {
  final StudyMode mode;
  final List<Word> deck;

  const ReviewSessionScreen({
    super.key,
    required this.mode,
    required this.deck,
  });

  @override
  State<ReviewSessionScreen> createState() => _ReviewSessionScreenState();
}

class _ReviewSessionScreenState extends State<ReviewSessionScreen> {
  late final List<Word> _deck;
  int _index = 0;
  bool _revealed = false;

  final _typeController = TextEditingController();
  bool? _typedCorrect; // null = not yet checked (typing mode)

  final _tts = TtsService();

  // Session stats.
  int _again = 0, _hard = 0, _good = 0, _easy = 0;
  late final DateTime _start;
  StreakSnapshot? _lastStreak;

  @override
  void initState() {
    super.initState();
    _deck = [...widget.deck];
    _start = DateTime.now();
  }

  @override
  void dispose() {
    _typeController.dispose();
    super.dispose();
  }

  Word get _current => _deck[_index];

  // ── Answer checking (typing mode) ──────────────────────────────────
  bool _checkTyped(Word w, String typed) {
    String norm(String s) => s
        .toLowerCase()
        .replaceAll(RegExp(r'^(der|die|das|the|a|an|to)\s+'), '')
        .replaceAll(RegExp(r'[^a-z0-9äöüß\s]'), '')
        .trim();
    final t = norm(typed);
    if (t.isEmpty) return false;
    final options = w.translation
        .split(RegExp(r'[,/;]'))
        .map(norm)
        .where((e) => e.isNotEmpty);
    return options.contains(t);
  }

  // Cloze: blank the target word inside its example sentence.
  String _clozeText(Word w) {
    final bare = w.word.replaceFirst(
        RegExp(r'^(der|die|das)\s+', caseSensitive: false), '');
    if (bare.trim().isEmpty) return w.exampleSource;
    final re = RegExp(RegExp.escape(bare), caseSensitive: false);
    return w.exampleSource.replaceAll(re, '____');
  }

  void _submitTyped() {
    setState(() {
      _typedCorrect = _checkTyped(_current, _typeController.text);
      _revealed = true;
    });
  }

  Future<void> _rate(Rating rating) async {
    final word = _current;
    switch (rating) {
      case Rating.again:
        _again++;
        break;
      case Rating.hard:
        _hard++;
        break;
      case Rating.good:
        _good++;
        break;
      case Rating.easy:
        _easy++;
        break;
    }
    final result = await context.read<WordProvider>().processReview(word, rating);
    _lastStreak = result.streak;
    if (!mounted) return;

    // "Again" cards return later in the session (learning step).
    if (rating == Rating.again) _deck.add(word);

    if (_index + 1 >= _deck.length) {
      _finish();
      return;
    }
    setState(() {
      _index++;
      _revealed = false;
      _typedCorrect = null;
      _typeController.clear();
    });
  }

  void _finish() {
    final stats = SessionStats(
      again: _again,
      hard: _hard,
      good: _good,
      easy: _easy,
      sessionStart: _start,
      sessionEnd: DateTime.now(),
      streak: _lastStreak ?? context.read<WordProvider>().streak,
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ReviewSummaryScreen(stats: stats)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = _current;
    final remaining = _deck.length - _index;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
                child: Text('$remaining left',
                    style: const TextStyle(fontSize: 13))),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _prompt(w),
                      if (_revealed) ...[
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 12),
                        _answer(w),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (!_revealed)
                _revealControls(w)
              else
                _ratingBar(w),
            ],
          ),
        ),
      ),
    );
  }

  // ── Prompt (front) ─────────────────────────────────────────────────
  Widget _prompt(Word w) {
    final cs = Theme.of(context).colorScheme;
    switch (widget.mode) {
      case StudyMode.reverse:
        // Show the translation; recall the source word.
        return _bigPrompt(w.translation, w.targetLang, 'Recall the word');
      case StudyMode.cloze:
        if (w.exampleSource.isEmpty) {
          return _bigPrompt(w.word, w.sourceLang, 'Recall the meaning');
        }
        return Column(
          children: [
            Text('Fill in the blank',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            Text(_clozeText(w),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, height: 1.4)),
          ],
        );
      case StudyMode.typing:
        return Column(
          children: [
            _bigPrompt(w.word, w.sourceLang, 'Type the translation'),
            const SizedBox(height: 16),
            TextField(
              controller: _typeController,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submitTyped(),
              decoration: const InputDecoration(
                labelText: 'Your answer',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        );
      case StudyMode.flip:
        return _bigPrompt(w.word, w.sourceLang, 'Recall the translation');
    }
  }

  Widget _bigPrompt(String text, String lang, String hint) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(hint, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 30, fontWeight: FontWeight.bold)),
            ),
            IconButton(
              icon: const Icon(Icons.volume_up),
              tooltip: 'Listen',
              onPressed: () => _tts.speak(text, language: lang),
            ),
          ],
        ),
      ],
    );
  }

  // ── Answer (back) ──────────────────────────────────────────────────
  Widget _answer(Word w) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Typing feedback
        if (widget.mode == StudyMode.typing && _typedCorrect != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (_typedCorrect! ? Colors.green : cs.error).withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(_typedCorrect! ? Icons.check_circle : Icons.cancel,
                    color: _typedCorrect! ? Colors.green : cs.error, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _typedCorrect!
                        ? 'Correct!'
                        : 'Not quite — you typed "${_typeController.text.trim()}"',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        // The answer: word + translation
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                widget.mode == StudyMode.reverse ? w.word : w.translation,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.volume_up, size: 22),
              tooltip: 'Listen',
              onPressed: () => _tts.speak(
                  widget.mode == StudyMode.reverse ? w.word : w.translation,
                  language:
                      widget.mode == StudyMode.reverse ? w.sourceLang : w.targetLang),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text('${w.word}  •  ${w.translation}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        if (w.exampleSource.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w.exampleSource,
                    style: const TextStyle(
                        fontStyle: FontStyle.italic, fontSize: 14)),
                if (w.exampleTarget.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(w.exampleTarget, style: const TextStyle(fontSize: 14)),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── Bottom controls ────────────────────────────────────────────────
  Widget _revealControls(Word w) {
    if (widget.mode == StudyMode.typing) {
      return FilledButton.icon(
        onPressed: _submitTyped,
        icon: const Icon(Icons.check),
        label: const Text('Check answer'),
        style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14)),
      );
    }
    return FilledButton.icon(
      onPressed: () => setState(() => _revealed = true),
      icon: const Icon(Icons.visibility),
      label: const Text('Show answer'),
      style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14)),
    );
  }

  Widget _ratingBar(Word w) {
    Widget btn(Rating r, String label, Color color) {
      final days = SrsService.previewInterval(
        repetitions: w.srsRepetitions,
        easeFactor: w.srsEaseFactor,
        interval: w.srsInterval,
        rating: r,
      );
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: FilledButton(
            onPressed: () => _rate(r),
            style: FilledButton.styleFrom(
                backgroundColor: color,
                padding: const EdgeInsets.symmetric(vertical: 10)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                Text(SrsService.hintForInterval(days),
                    style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        btn(Rating.again, 'Again', Colors.red.shade600),
        btn(Rating.hard, 'Hard', Colors.orange.shade700),
        btn(Rating.good, 'Good', Colors.green.shade600),
        btn(Rating.easy, 'Easy', Colors.blue.shade600),
      ],
    );
  }
}
