import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/word.dart';
import '../providers/word_provider.dart';
import '../services/tts_service.dart';
import '../config/app_strings.dart';
import '../utils/clipboard_util.dart';

class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({super.key});

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _isFlipped = false;
  final TtsService _tts = TtsService();

  int _currentIndex = 0;
  late PageController _pageController;

  // Per-card ephemeral state (only the visible card is interactive) — reset on
  // page change so one card's second-language / loading state never leaks to the
  // next card.
  String? _secondLang;
  bool _secondLoading = false;
  bool _grammarLoading = false;
  bool _regenLoading = false;

  void _resetCardState() {
    _secondLang = null;
    _secondLoading = false;
    _grammarLoading = false;
    _regenLoading = false;
  }

  /// Full-card text for the "copy" action: word, translation, grammar tip,
  /// examples, and note (whichever are present).
  String _cardCopyText(Word word) {
    final parts = <String>[word.word];
    if (word.translation.isNotEmpty) parts.add(word.translation);
    if ((word.grammarTip ?? '').isNotEmpty) {
      parts.add('Grammar: ${word.grammarTip}');
    }
    if (word.exampleSource.isNotEmpty) parts.add(word.exampleSource);
    if (word.exampleTarget.isNotEmpty) parts.add(word.exampleTarget);
    if ((word.note ?? '').isNotEmpty) parts.add('Note: ${word.note}');
    return parts.join('\n');
  }

  Future<void> _archive(List<Word> words) async {
    if (words.isEmpty) return;
    final word = words[_currentIndex.clamp(0, words.length - 1)];
    await context.read<WordProvider>().archiveWord(word);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${word.word}" archived')),
    );
    // The deck just shrank — clamp the page so it stays valid.
    final newLen = context.read<WordProvider>().words.length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || newLen == 0) return;
      final target = _currentIndex.clamp(0, newLen - 1);
      if (_pageController.hasClients) _pageController.jumpToPage(target);
      setState(() {
        _currentIndex = target;
        _isFlipped = false;
        _flipController.reset();
        _resetCardState();
      });
    });
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

  Future<void> _regenerate(Word word) async {
    setState(() => _regenLoading = true);
    try {
      await context.read<WordProvider>().regenerateExample(word);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
    if (mounted) setState(() => _regenLoading = false);
  }

  Future<void> _resetSrs(List<Word> words) async {
    if (words.isEmpty) return;
    final word = words[_currentIndex.clamp(0, words.length - 1)];
    await context.read<WordProvider>().resetSrs(word);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${word.word}" — study progress reset')),
    );
  }

  Future<void> _generateGrammar(Word word) async {
    setState(() => _grammarLoading = true);
    try {
      await context.read<WordProvider>().generateGrammarTipFor(word);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
    if (mounted) setState(() => _grammarLoading = false);
  }

  Future<void> _translateSecond(Word word) async {
    final lang = _secondLang ?? word.secondLang;
    if (lang == null) return;
    setState(() => _secondLoading = true);
    try {
      final result = await context
          .read<WordProvider>()
          .translateWord(word.word, from: word.sourceLang, to: lang);
      // Persist so it's still shown when the card is reopened.
      await context
          .read<WordProvider>()
          .updateSecondTranslation(word, lang, result.translation);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
    if (mounted) setState(() => _secondLoading = false);
  }

  Future<void> _editNote(Word word) async {
    final controller = TextEditingController(text: word.note ?? '');
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
            hintText: 'Add a personal note…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (saved == null || !mounted) return;
    await context.read<WordProvider>().updateNote(word, saved);
  }

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
    _pageController = PageController();
  }

  @override
  void dispose() {
    _flipController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _flip() {
    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
      // Mark as reviewed when card is flipped
      final words = context.read<WordProvider>().words;
      if (_currentIndex < words.length) {
        final word = words[_currentIndex];
        if (!word.isReviewed) {
          context.read<WordProvider>().toggleReview(word);
        }
      }
    }
    setState(() => _isFlipped = !_isFlipped);
  }

  void _resetToStart() {
    _pageController.jumpToPage(0);
    setState(() {
      _currentIndex = 0;
      _isFlipped = false;
      _flipController.reset();
      _resetCardState();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WordProvider>(
      builder: (context, provider, _) {
        final words = provider.words;
        if (words.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Flashcards')),
            body: const Center(child: Text('No words yet. Add some first!')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(
                'Flashcard ${_currentIndex.clamp(0, words.length - 1) + 1} of ${words.length}'),
            actions: [
              IconButton(
                icon: const Icon(Icons.archive_outlined),
                tooltip: 'Archive this card',
                onPressed: () => _archive(words),
              ),
              IconButton(
                icon: const Icon(Icons.replay),
                tooltip: 'Start over',
                onPressed: _currentIndex == 0 ? null : _resetToStart,
              ),
              IconButton(
                icon: const Icon(Icons.restart_alt),
                tooltip: 'Reset study progress',
                onPressed: () => _resetSrs(words),
              ),
              IconButton(
                icon: const Icon(Icons.copy),
                tooltip: 'Copy card',
                onPressed: () {
                  final i = _currentIndex.clamp(0, words.length - 1);
                  copyToClipboard(context, _cardCopyText(words[i]),
                      label: 'Card');
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // Progress bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_currentIndex + 1) / words.length,
                    minHeight: 6,
                  ),
                ),
              ),

              // Flashcard
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: words.length,
                  onPageChanged: (i) {
                    setState(() {
                      _currentIndex = i;
                      _isFlipped = false;
                      _flipController.reset();
                      _resetCardState();
                    });
                  },
                  itemBuilder: (context, index) {
                    final word = words[index];
                    return _buildCard(context, word);
                  },
                ),
              ),

              // Bottom controls
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Previous
                    IconButton.filled(
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Previous card',
                      onPressed: _currentIndex > 0
                          ? () => _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              )
                          : null,
                    ),
                    // Flip button
                    Tooltip(
                      message: _isFlipped
                          ? 'Flip back'
                          : 'Show translation',
                      child: FilledButton.icon(
                        onPressed: _flip,
                        icon: const Icon(Icons.flip),
                        label: Text(_isFlipped ? 'Hide' : 'Reveal'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 14),
                        ),
                      ),
                    ),
                    // Next
                    IconButton.filled(
                      icon: const Icon(Icons.arrow_forward),
                      tooltip: 'Next card',
                      onPressed: _currentIndex < words.length - 1
                          ? () => _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              )
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCard(BuildContext context, Word word) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: GestureDetector(
        onTap: _flip,
        child: AnimatedBuilder(
          animation: _flipAnimation,
          builder: (context, child) {
            final v = _flipAnimation.value;
            // At rest, render the face WITHOUT the perspective transform. A
            // residual perspective matrix interferes with gesture hit-testing,
            // which is what stopped the back's scroll view from scrolling. Only
            // the in-between animation frames use the 3D transform.
            // SizedBox.expand forces each face to FILL the page height, so the
            // back's SingleChildScrollView gets a bounded height and scrolls
            // (otherwise it sizes to its content and overflows off-screen).
            if (v >= 1.0) return SizedBox.expand(child: _buildBack(context, word));
            if (v <= 0.0) return SizedBox.expand(child: _buildFront(context, word));

            final angle = v * 3.14159; // pi radians
            final isShowingFront = v <= 0.5;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(angle),
              child: isShowingFront
                  ? SizedBox.expand(child: _buildFront(context, word))
                  : Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(3.14159),
                      child: SizedBox.expand(child: _buildBack(context, word)),
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFront(BuildContext context, Word word) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primaryContainer,
              Theme.of(context).colorScheme.primary.withAlpha(40),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Word + 🔊. Flexible lets long words wrap to multiple lines
              // instead of being clipped, and keeps the speaker always visible.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        word.word,
                        style: const TextStyle(
                            fontSize: 32, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.volume_up, size: 28),
                      tooltip: 'Listen',
                      onPressed: () =>
                          _tts.speak(word.word, language: word.sourceLang),
                    ),
                    _copyIconBtn(word.word, 'word', size: 22),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Studied indicator
              if (word.srsNextDue != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 14, color: Colors.green.shade700),
                      const SizedBox(width: 4),
                      Text('Studied',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  word.sourceLang.toUpperCase(),
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Tap to reveal',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBack(BuildContext context, Word word) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primaryContainer,
              Theme.of(context).colorScheme.primaryContainer,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Word (smaller)
              Text(
                word.word,
                style: TextStyle(
                    fontSize: 20,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),

              // Translation
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: Text(
                      word.translation,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.volume_up, size: 28),
                    tooltip: 'Listen',
                    onPressed: () => _tts.speak(word.translation, language: word.targetLang),
                  ),
                  _copyIconBtn(word.translation, 'translation', size: 22),
                ],
              ),
              const SizedBox(height: 8),

              // Language badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  word.targetLang.toUpperCase(),
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.w600),
                ),
              ),

              // Examples
              if (word.exampleSource.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (word.exampleSource.isNotEmpty)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.volume_up, size: 20),
                              tooltip: 'Listen',
                              onPressed: () => _tts.speak(word.exampleSource, language: word.sourceLang),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                word.exampleSource,
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  fontSize: 14,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            _copyIconBtn(word.exampleSource, 'example', size: 16),
                          ],
                        ),
                      if (word.exampleTarget.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        const Divider(),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.volume_up, size: 20),
                              tooltip: 'Listen',
                              onPressed: () => _tts.speak(word.exampleTarget, language: word.targetLang),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                word.exampleTarget,
                                style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context).colorScheme.onSurface),
                              ),
                            ),
                            _copyIconBtn(word.exampleTarget, 'example', size: 16),
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
                  onPressed: _regenLoading ? null : () => _regenerate(word),
                  icon: _regenLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.autorenew, size: 18),
                  label: Text(
                      _regenLoading ? 'Regenerating…' : 'Regenerate example'),
                ),
              ),

              _buildGrammarSection(context, word),
              _buildNoteSection(context, word),
              _buildSecondLangSection(context, word),

              const SizedBox(height: 20),
              Text(
                'Tap to flip back',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// AI grammar/usage tip. null = never generated (show button); '' = generated
  /// but nothing noteworthy; non-empty = show the tip.
  Widget _buildGrammarSection(BuildContext context, Word word) {
    final cs = Theme.of(context).colorScheme;
    final tip = word.grammarTip;

    final spinner = SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2, color: cs.tertiary),
    );

    if (tip == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: OutlinedButton.icon(
          onPressed: _grammarLoading ? null : () => _generateGrammar(word),
          icon: _grammarLoading
              ? spinner
              : const Icon(Icons.lightbulb_outline, size: 18),
          label: Text(_grammarLoading ? 'Generating…' : 'Grammar tip'),
        ),
      );
    }

    if (tip.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('No notable grammar point',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            IconButton(
              icon: _grammarLoading
                  ? spinner
                  : const Icon(Icons.refresh, size: 16),
              tooltip: 'Try again',
              onPressed: _grammarLoading ? null : () => _generateGrammar(word),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer.withAlpha(120),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
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
                tooltip: 'Copy grammar tip',
                onPressed: () =>
                    copyToClipboard(context, tip, label: 'Grammar tip'),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              IconButton(
                icon: _grammarLoading
                    ? spinner
                    : const Icon(Icons.refresh, size: 16),
                tooltip: 'Regenerate',
                onPressed:
                    _grammarLoading ? null : () => _generateGrammar(word),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(tip, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  /// Free-text note, editable via a dialog (so tapping never flips the card).
  Widget _buildNoteSection(BuildContext context, Word word) {
    final cs = Theme.of(context).colorScheme;
    final note = word.note ?? '';
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sticky_note_2_outlined,
                  size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text('Note',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurfaceVariant)),
              const Spacer(),
              if (note.isNotEmpty) _copyIconBtn(note, 'note', size: 16),
              IconButton(
                icon: Icon(note.isEmpty ? Icons.add : Icons.edit, size: 16),
                tooltip: note.isEmpty ? 'Add note' : 'Edit note',
                onPressed: () => _editNote(word),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(note, style: const TextStyle(fontSize: 13)),
          ],
        ],
      ),
    );
  }

  /// Second-language translation — saved on the card and shown again on reopen.
  Widget _buildSecondLangSection(BuildContext context, Word word) {
    final cs = Theme.of(context).colorScheme;
    final entries = AppStrings.targetLanguages.entries
        .where((e) => e.key != word.sourceLang)
        .toList();
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Also translate to',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _secondLang ?? word.secondLang,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(),
                    hintText: 'Language',
                  ),
                  items: entries
                      .map((e) => DropdownMenuItem(
                          value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: _secondLoading
                      ? null
                      : (v) => setState(() => _secondLang = v),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed:
                    ((_secondLang ?? word.secondLang) == null || _secondLoading)
                        ? null
                        : () => _translateSecond(word),
                child: _secondLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Go'),
              ),
            ],
          ),
          if ((word.secondTranslation ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(word.secondTranslation!,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up, size: 18),
                  tooltip: 'Listen',
                  onPressed: () => _tts.speak(word.secondTranslation!,
                      language: word.secondLang ?? word.targetLang),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  tooltip: 'Copy',
                  onPressed: () =>
                      copyToClipboard(context, word.secondTranslation!),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
