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
import '../config/app_strings.dart';
import '../utils/clipboard_util.dart';
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

  // Rich-content state (restores the normal flip behaviour: grammar tip, note,
  // and 2nd-language translation on the answer side). Reset on each new card.
  bool _grammarLoading = false;
  bool _regenLoading = false;
  String? _secondLang;
  bool _secondLoading = false;

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
    // Unicode-aware: keep letters of ANY script (Arabic, CJK, Cyrillic, …)
    // and digits, drop punctuation/diacritic marks. The old [a-z…] filter
    // erased non-Latin answers to empty, so e.g. Arabic could never match.
    String norm(String s) => s
        .toLowerCase()
        .replaceAll(RegExp(r'^(der|die|das|the|a|an|to)\s+'), '')
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final t = norm(typed);
    if (t.isEmpty) return false;
    final options = w.translation
        .split(RegExp(r'[,/;]'))
        .map(norm)
        .where((e) => e.isNotEmpty);
    return options.contains(t);
  }

  /// Hint under the typing box: which language to answer in (the language the
  /// word was translated to). If the card stores more than one meaning, any of
  /// them is accepted.
  String _answerLangHint(Word w) {
    final langName = AppStrings.targetLanguages[w.targetLang] ?? w.targetLang;
    final multi = w.translation.split(RegExp(r'[,/;]'))
        .where((e) => e.trim().isNotEmpty)
        .length > 1;
    return multi
        ? 'Answer in $langName — any of your translations counts'
        : 'Answer in $langName';
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
      _grammarLoading = false;
      _regenLoading = false;
      _secondLang = null;
      _secondLoading = false;
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

  /// Compact copy icon for a single piece of text on the card.
  Widget _copyIconBtn(String text, String label, {double size = 18}) {
    return IconButton(
      icon: Icon(Icons.copy, size: size),
      tooltip: 'Copy $label',
      onPressed: () => copyToClipboard(context, text, label: label),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
    );
  }

  /// Whole-card copy text (word + translation + grammar + examples + note).
  String _cardCopyText(Word w) {
    final parts = <String>[w.word];
    if (w.translation.isNotEmpty) parts.add(w.translation);
    if ((w.grammarTip ?? '').isNotEmpty) parts.add('Grammar: ${w.grammarTip}');
    if (w.exampleSource.isNotEmpty) parts.add(w.exampleSource);
    if (w.exampleTarget.isNotEmpty) parts.add(w.exampleTarget);
    if ((w.note ?? '').isNotEmpty) parts.add('Note: ${w.note}');
    return parts.join('\n');
  }

  Future<void> _regenerate(Word w) async {
    setState(() => _regenLoading = true);
    try {
      await context.read<WordProvider>().regenerateExample(w);
      final updated = context
          .read<WordProvider>()
          .words
          .firstWhere((x) => x.id == w.id, orElse: () => w);
      if (mounted) {
        setState(() => _deck[_index] = _deck[_index].copyWith(
              exampleSource: updated.exampleSource,
              exampleTarget: updated.exampleTarget,
            ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
    if (mounted) setState(() => _regenLoading = false);
  }

  Future<void> _archiveCurrent() async {
    final w = _current;
    await context.read<WordProvider>().archiveWord(w);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${w.word}" archived')),
    );
    _deck.removeWhere((x) => x.id == w.id);
    if (_index >= _deck.length) {
      _finish();
      return;
    }
    setState(() {
      _revealed = false;
      _typedCorrect = null;
      _typeController.clear();
      _grammarLoading = false;
      _regenLoading = false;
      _secondLang = null;
      _secondLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final w = _current;
    final remaining = _deck.length - _index;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review'),
        actions: [
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            tooltip: 'Archive this card',
            onPressed: _archiveCurrent,
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy card',
            onPressed: () =>
                copyToClipboard(context, _cardCopyText(w), label: 'Card'),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
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
                // Tap anywhere on the card to reveal the answer (flip/reverse
                // modes). Typing mode keeps its Check-answer flow, so tapping
                // there does nothing and the text field stays usable.
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: (!_revealed && widget.mode != StudyMode.typing)
                      ? () => setState(() => _revealed = true)
                      : null,
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
            const SizedBox(height: 8),
            // Which language the answer is expected in — the language the word
            // was translated to. Multiple stored meanings are all accepted.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _answerLangHint(w),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ),
              ],
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
            _copyIconBtn(text, 'text', size: 22),
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
        // The answer: word / translation + TTS + copy
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
                  language: widget.mode == StudyMode.reverse
                      ? w.sourceLang
                      : w.targetLang),
            ),
            _copyIconBtn(
                widget.mode == StudyMode.reverse ? w.word : w.translation,
                'translation',
                size: 20),
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.volume_up, size: 20),
                      tooltip: 'Listen',
                      onPressed: () =>
                          _tts.speak(w.exampleSource, language: w.sourceLang),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(w.exampleSource,
                          style: const TextStyle(
                              fontStyle: FontStyle.italic, fontSize: 14)),
                    ),
                    _copyIconBtn(w.exampleSource, 'example', size: 16),
                  ],
                ),
                if (w.exampleTarget.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  const Divider(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.volume_up, size: 20),
                        tooltip: 'Listen',
                        onPressed: () =>
                            _tts.speak(w.exampleTarget, language: w.targetLang),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(w.exampleTarget,
                            style: const TextStyle(fontSize: 14)),
                      ),
                      _copyIconBtn(w.exampleTarget, 'example', size: 16),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
        // Regenerate the example sentence(s)
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.center,
          child: TextButton.icon(
            onPressed: _regenLoading ? null : () => _regenerate(w),
            icon: _regenLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.autorenew, size: 18),
            label: Text(_regenLoading ? 'Regenerating…' : 'Regenerate example'),
          ),
        ),
        // Restored rich content: grammar tip, note, translate-to-another-language.
        _grammarSection(w),
        _noteSection(w),
        _secondLangSection(w),
      ],
    );
  }

  // ── Bottom controls ────────────────────────────────────────────────
  Widget _revealControls(Word w) {
    // Full-width buttons (Size.fromHeight → infinite min width) with real
    // horizontal padding, so the label sits inside with room to spare.
    final style = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(50),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    );
    if (widget.mode == StudyMode.typing) {
      return FilledButton.icon(
        onPressed: _submitTyped,
        icon: const Icon(Icons.check),
        label: const Text('Check answer'),
        style: style,
      );
    }
    return FilledButton.icon(
      onPressed: () => setState(() => _revealed = true),
      icon: const Icon(Icons.visibility),
      label: const Text('Show answer'),
      style: style,
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
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                minimumSize: const Size(0, 52),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            // FittedBox scales the label down to fit so text never spills
            // outside the button on narrow screens / large font scales.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      maxLines: 1,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(SrsService.hintForInterval(days),
                      maxLines: 1, style: const TextStyle(fontSize: 11)),
                ],
              ),
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

  // ── Rich content (grammar tip / note / 2nd-language) ───────────────
  Future<void> _generateGrammar(Word w) async {
    setState(() => _grammarLoading = true);
    try {
      final tip = await context.read<WordProvider>().generateGrammarTipFor(w);
      if (mounted) {
        setState(() => _deck[_index] = _deck[_index].copyWith(grammarTip: tip));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
    if (mounted) setState(() => _grammarLoading = false);
  }

  Future<void> _editNote(Word w) async {
    final controller = TextEditingController(text: w.note ?? '');
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Note'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
              hintText: 'Add a personal note…', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (saved == null || !mounted) return;
    await context.read<WordProvider>().updateNote(w, saved);
    if (mounted) {
      setState(() => _deck[_index] = _deck[_index].copyWith(note: saved));
    }
  }

  Future<void> _translateSecond(Word w) async {
    final lang = _secondLang ?? w.secondLang;
    if (lang == null) return;
    setState(() => _secondLoading = true);
    try {
      final result = await context
          .read<WordProvider>()
          .translateWord(w.word, from: w.sourceLang, to: lang);
      // Persist so the translation is still here when the card is reopened.
      await context
          .read<WordProvider>()
          .updateSecondTranslation(w, lang, result.translation);
      if (mounted) {
        setState(() => _deck[_index] = _deck[_index].copyWith(
            secondLang: lang, secondTranslation: result.translation));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
    if (mounted) setState(() => _secondLoading = false);
  }

  Widget _grammarSection(Word w) {
    final cs = Theme.of(context).colorScheme;
    final tip = w.grammarTip;
    final spinner = SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: cs.tertiary));
    if (tip == null || tip.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: OutlinedButton.icon(
          onPressed: _grammarLoading ? null : () => _generateGrammar(w),
          icon: _grammarLoading
              ? spinner
              : const Icon(Icons.lightbulb_outline, size: 18),
          label: Text(_grammarLoading
              ? 'Generating…'
              : (tip == null ? 'Grammar tip' : 'No tip — try again')),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: cs.tertiaryContainer.withAlpha(120),
          borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.lightbulb, size: 16, color: cs.tertiary),
          const SizedBox(width: 6),
          Text('Grammar tip',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: cs.tertiary)),
          const Spacer(),
          IconButton(
              icon: const Icon(Icons.copy, size: 16),
              tooltip: 'Copy',
              onPressed: () => copyToClipboard(context, tip, label: 'Grammar tip'),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
          IconButton(
              icon: _grammarLoading ? spinner : const Icon(Icons.refresh, size: 16),
              tooltip: 'Regenerate',
              onPressed: _grammarLoading ? null : () => _generateGrammar(w),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
        ]),
        const SizedBox(height: 4),
        Text(tip, style: const TextStyle(fontSize: 13)),
      ]),
    );
  }

  Widget _noteSection(Word w) {
    final cs = Theme.of(context).colorScheme;
    final note = w.note ?? '';
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.sticky_note_2_outlined, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text('Note',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurfaceVariant)),
          const Spacer(),
          IconButton(
              icon: Icon(note.isEmpty ? Icons.add : Icons.edit, size: 16),
              tooltip: note.isEmpty ? 'Add note' : 'Edit note',
              onPressed: () => _editNote(w),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
        ]),
        if (note.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(note, style: const TextStyle(fontSize: 13)),
        ],
      ]),
    );
  }

  Widget _secondLangSection(Word w) {
    final cs = Theme.of(context).colorScheme;
    final entries = AppStrings.targetLanguages.entries
        .where((e) => e.key != w.sourceLang)
        .toList();
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Also translate to',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: cs.onSurfaceVariant)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _secondLang ?? w.secondLang,
              isExpanded: true,
              decoration: const InputDecoration(
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(),
                  hintText: 'Language'),
              items: entries
                  .map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: _secondLoading
                  ? null
                  : (v) => setState(() => _secondLang = v),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: ((_secondLang ?? w.secondLang) == null || _secondLoading)
                ? null
                : () => _translateSecond(w),
            child: _secondLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Go'),
          ),
        ]),
        if ((w.secondTranslation ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: Text(w.secondTranslation!,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600))),
            IconButton(
                icon: const Icon(Icons.volume_up, size: 18),
                tooltip: 'Listen',
                onPressed: () => _tts.speak(w.secondTranslation!,
                    language: w.secondLang ?? w.targetLang),
                visualDensity: VisualDensity.compact),
            IconButton(
                icon: const Icon(Icons.copy, size: 16),
                tooltip: 'Copy',
                onPressed: () =>
                    copyToClipboard(context, w.secondTranslation!),
                visualDensity: VisualDensity.compact),
          ]),
        ],
      ]),
    );
  }
}
