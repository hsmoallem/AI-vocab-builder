import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/word_provider.dart';
import '../providers/locale_provider.dart';
import '../config/app_strings.dart';
import '../services/translation_service.dart' show GrammarData, TranslationService;
import '../services/tts_service.dart';
import '../widgets/cefr_level_dropdown.dart';
import '../widgets/searchable_dropdown.dart';

class AddWordDialog extends StatefulWidget {
  final String? initialWord;

  const AddWordDialog({super.key, this.initialWord});

  @override
  State<AddWordDialog> createState() => _AddWordDialogState();
}

class _AddWordDialogState extends State<AddWordDialog> {
  final _wordController = TextEditingController();
  List<_MeaningEntry> _meanings = [];

  String _sourceLang = 'de';
  String _targetLang = 'en';
  String? _level;       // CEFR level (null = auto)
  bool _isTranslating = false;
  bool _isSaving = false;
  String? _error;
  GrammarData? _grammarData;  // auto-enriched grammar from proxy

  @override
  void initState() {
    super.initState();
    // Default "To" language to the user's saved setting
    final savedTarget = context.read<LocaleProvider>().targetLang;
    // Use the saved target only if it's valid AND not the same as the source,
    // so the dialog never opens with From == To.
    if (AppStrings.targetLanguages.containsKey(savedTarget) &&
        savedTarget != _sourceLang) {
      _targetLang = savedTarget;
    }
    if (widget.initialWord != null && widget.initialWord!.isNotEmpty) {
      _wordController.text = widget.initialWord!;
      // Auto-translate after the first frame
      WidgetsBinding.instance.addPostFrameCallback((_) => _translate());
    }
  }

  @override
  void dispose() {
    _wordController.dispose();
    for (final m in _meanings) {
      m.dispose();
    }
    super.dispose();
  }

  Future<void> _translate() async {
    final word = _wordController.text.trim();
    if (word.isEmpty) {
      setState(() => _error = 'Please enter a word first');
      return;
    }

    // Dispose old meaning controllers
    for (final m in _meanings) {
      m.dispose();
    }

    setState(() {
      _isTranslating = true;
      _error = null;
      _meanings = [];
    });

    try {
      final provider = context.read<WordProvider>();
      final result = await provider.translateWord(
        word,
        from: _sourceLang,
        to: _targetLang,
        level: _level,
      );

      _grammarData = result.grammar;
      setState(() {
        _meanings = result.meanings.map((m) => _MeaningEntry(
          article: m.article,
          meaning: TextEditingController(text: m.text),
          exampleSource: TextEditingController(text: m.exampleSource),
          exampleTarget: TextEditingController(text: m.exampleTarget),
        )).toList();
      });

      // If the server returned a corrected spelling, replace the typed word
      // so the properly-spelled form is what gets saved.
      final corrected = result.corrected?.trim();
      if (corrected != null &&
          corrected.isNotEmpty &&
          corrected.toLowerCase() != word.toLowerCase()) {
        _wordController.text = corrected;
      }

      // Prepend the article (der/die/das) ONLY when the source language is
      // German — articles are German-only, so never add them for English etc.
      final article = result.meanings.firstOrNull?.article;
      if (_sourceLang == 'de' && article != null && article.isNotEmpty) {
        final currentWord = _wordController.text.trim();
        if (!currentWord.startsWith(article)) {
          _wordController.text = '$article $currentWord';
        }
      }
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '').replaceFirst('Error: ', '');
      setState(() => _error = msg);
    }

    setState(() => _isTranslating = false);
  }

  Future<void> _save() async {
    final word = _wordController.text.trim();
    if (word.isEmpty) {
      setState(() => _error = 'Word is required');
      return;
    }

    final translation = _meanings
        .where((m) => m.meaning.text.trim().isNotEmpty)
        .map((m) => m.meaning.text.trim())
        .join(', ');

    final exampleSource = _meanings
        .where((m) => m.exampleSource.text.trim().isNotEmpty)
        .map((m) => '• ${m.exampleSource.text.trim()}')
        .join('\n');

    final exampleTarget = _meanings
        .where((m) => m.exampleTarget.text.trim().isNotEmpty)
        .map((m) => '• ${m.exampleTarget.text.trim()}')
        .join('\n');

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final provider = context.read<WordProvider>();
      final success = await provider.addWord(
        word: word,
        translation: translation,
        grammar: _grammarData,
        exampleSource: exampleSource,
        exampleTarget: exampleTarget,
        sourceLang: _sourceLang,
        targetLang: _targetLang,
      );

      if (success && mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '').replaceFirst('Error: ', '');
      setState(() => _error = 'Unable to save vocabulary item: $msg');
    }

    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                const Text(
                  'Add Word or Phrase',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

              // Error message
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer),
                  ),
                ),
              if (_error != null) const SizedBox(height: 12),

              // Word input
              TextField(
                controller: _wordController,
                decoration: const InputDecoration(
                  labelText: 'Word or Phrase',
                  hintText: 'Enter a word or phrase to translate...',
                  prefixIcon: Icon(Icons.text_fields),
                ),
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _translate(),
              ),
              const SizedBox(height: 12),

              // Language selectors
              Row(
                children: [
                  Expanded(
                    child: SearchableDropdown<String>(
                      value: _sourceLang,
                      labelText: 'From',
                      items: AppStrings.targetLanguages.entries
                          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                          .toList(),
                      itemAsString: (key) => AppStrings.targetLanguages[key] ?? key,
                      onChanged: (val) => setState(() {
                        if (val == _targetLang) {
                          _targetLang = _sourceLang;
                        }
                        _sourceLang = val!;
                      }),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward, size: 18),
                  ),
                  Expanded(
                    child: SearchableDropdown<String>(
                      value: _targetLang,
                      labelText: 'To',
                      items: AppStrings.targetLanguages.entries
                          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                          .toList(),
                      itemAsString: (key) => AppStrings.targetLanguages[key] ?? key,
                      onChanged: (val) => setState(() {
                        if (val == _sourceLang) {
                          _sourceLang = _targetLang;
                        }
                        _targetLang = val!;
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // CEFR Level
              CefrLevelDropdown(
                value: _level,
                onChanged: (v) => setState(() => _level = v),
                compact: true,
              ),
              const SizedBox(height: 12),

              // Translate button
              ElevatedButton.icon(
                onPressed: _isTranslating ? null : _translate,
                icon: _isTranslating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.translate),
                label: Text(_isTranslating ? 'Translating...' : 'Translate with AI'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),

              // Meanings (shown after translation)
              if (_meanings.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  '${_meanings.length} meaning${_meanings.length > 1 ? 's' : ''} found:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                ..._meanings.asMap().entries.map((entry) {
                  final i = entry.key;
                  final m = entry.value;
                  return _MeaningCard(
                    index: i,
                    total: _meanings.length,
                    article: m.article,
                    meaning: m.meaning,
                    exampleSource: m.exampleSource,
                    exampleTarget: m.exampleTarget,
                    sourceLang: _sourceLang,
                    targetLang: _targetLang,
                  );
                }),
              ],

                  ],
                ),
              ),
            ),
            // Save button (only show after translation)
            if (_meanings.isNotEmpty) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onPrimary),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Saving...' : 'Save Word'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Holds controllers for one meaning entry
class _MeaningEntry {
  final String? article;
  final TextEditingController meaning;
  final TextEditingController exampleSource;
  final TextEditingController exampleTarget;

  _MeaningEntry({
    this.article,
    required this.meaning,
    required this.exampleSource,
    required this.exampleTarget,
  });

  void dispose() {
    meaning.dispose();
    exampleSource.dispose();
    exampleTarget.dispose();
  }
}

/// Card showing one meaning with its example
class _MeaningCard extends StatelessWidget {
  final int index;
  final int total;
  final String? article;
  final TextEditingController meaning;
  final TextEditingController exampleSource;
  final TextEditingController exampleTarget;
  final String sourceLang;
  final String targetLang;

  const _MeaningCard({
    required this.index,
    required this.total,
    this.article,
    required this.meaning,
    required this.exampleSource,
    required this.exampleTarget,
    required this.sourceLang,
    required this.targetLang,
  });

  @override
  Widget build(BuildContext context) {
    final tts = TtsService();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Meaning header
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Article badge
                if (article != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      article!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                Expanded(
                  child: TextField(
                    controller: meaning,
                    decoration: const InputDecoration(
                      labelText: 'Meaning',
                      isDense: true,
                      border: UnderlineInputBorder(),
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up, size: 18),
                  tooltip: 'Listen',
                  onPressed: () => tts.speak(meaning.text, language: targetLang),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Examples
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: exampleSource,
                    decoration: const InputDecoration(
                      labelText: 'Example (original)',
                      prefixIcon: Icon(Icons.format_quote, size: 18),
                      isDense: true,
                      border: UnderlineInputBorder(),
                    ),
                    style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13),
                    maxLines: 2,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up, size: 16),
                  tooltip: 'Listen',
                  onPressed: () => tts.speak(exampleSource.text, language: sourceLang),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: exampleTarget,
                    decoration: const InputDecoration(
                      labelText: 'Example (translated)',
                      prefixIcon: Icon(Icons.format_quote_outlined, size: 18),
                      isDense: true,
                      border: UnderlineInputBorder(),
                    ),
                    style: const TextStyle(fontSize: 13),
                    maxLines: 2,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up, size: 16),
                  tooltip: 'Listen',
                  onPressed: () => tts.speak(exampleTarget.text, language: targetLang),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
