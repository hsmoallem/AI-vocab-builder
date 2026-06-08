import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/word_provider.dart';
import '../services/translation_service.dart';

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
  bool _isTranslating = false;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
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
      );

      setState(() {
        _meanings = result.meanings.map((m) => _MeaningEntry(
          article: m.article,
          meaning: TextEditingController(text: m.text),
          exampleSource: TextEditingController(text: m.exampleSource),
          exampleTarget: TextEditingController(text: m.exampleTarget),
        )).toList();
      });

      // If an article was returned, prepend it to the word field
      final article = result.meanings.firstOrNull?.article;
      if (article != null && article.isNotEmpty) {
        final currentWord = _wordController.text.trim();
        if (!currentWord.startsWith(article)) {
          _wordController.text = '$article $currentWord';
        }
      }
    } catch (e) {
      setState(() => _error = 'Translation failed: $e');
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
        exampleSource: exampleSource,
        exampleTarget: exampleTarget,
        sourceLang: _sourceLang,
        targetLang: _targetLang,
      );

      if (success && mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _error = 'Save failed: $e');
    }

    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
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
                    child: DropdownButtonFormField<String>(
                      value: _sourceLang,
                      decoration: const InputDecoration(
                        labelText: 'From',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'de', child: Text('🇩🇪 German')),
                        DropdownMenuItem(value: 'en', child: Text('🇬🇧 English')),
                        DropdownMenuItem(value: 'fr', child: Text('🇫🇷 French')),
                        DropdownMenuItem(value: 'es', child: Text('🇪🇸 Spanish')),
                        DropdownMenuItem(value: 'ar', child: Text('🇸🇦 Arabic')),
                        DropdownMenuItem(value: 'tr', child: Text('🇹🇷 Turkish')),
                        DropdownMenuItem(value: 'ru', child: Text('🇷🇺 Russian')),
                        DropdownMenuItem(value: 'zh', child: Text('🇨🇳 Chinese')),
                      ],
                      onChanged: (val) => setState(() => _sourceLang = val!),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward, size: 18),
                  ),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _targetLang,
                      decoration: const InputDecoration(
                        labelText: 'To',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'en', child: Text('🇬🇧 English')),
                        DropdownMenuItem(value: 'de', child: Text('🇩🇪 German')),
                        DropdownMenuItem(value: 'fr', child: Text('🇫🇷 French')),
                        DropdownMenuItem(value: 'es', child: Text('🇪🇸 Spanish')),
                        DropdownMenuItem(value: 'ar', child: Text('🇸🇦 Arabic')),
                        DropdownMenuItem(value: 'tr', child: Text('🇹🇷 Turkish')),
                        DropdownMenuItem(value: 'ru', child: Text('🇷🇺 Russian')),
                        DropdownMenuItem(value: 'zh', child: Text('🇨🇳 Chinese')),
                      ],
                      onChanged: (val) => setState(() => _targetLang = val!),
                    ),
                  ),
                ],
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
                  );
                }),
              ],

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

  const _MeaningCard({
    required this.index,
    required this.total,
    this.article,
    required this.meaning,
    required this.exampleSource,
    required this.exampleTarget,
  });

  @override
  Widget build(BuildContext context) {
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
              ],
            ),
            const SizedBox(height: 8),

            // Examples
            TextField(
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
            const SizedBox(height: 6),
            TextField(
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
          ],
        ),
      ),
    );
  }
}
