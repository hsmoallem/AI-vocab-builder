import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/word_provider.dart';

class AddWordDialog extends StatefulWidget {
  const AddWordDialog({super.key});

  @override
  State<AddWordDialog> createState() => _AddWordDialogState();
}

class _AddWordDialogState extends State<AddWordDialog> {
  final _wordController = TextEditingController();
  final _translationController = TextEditingController();
  final _exampleSourceController = TextEditingController();
  final _exampleTargetController = TextEditingController();

  String _sourceLang = 'de';
  String _targetLang = 'en';
  bool _isTranslating = false;
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _wordController.dispose();
    _translationController.dispose();
    _exampleSourceController.dispose();
    _exampleTargetController.dispose();
    super.dispose();
  }

  Future<void> _translate() async {
    final word = _wordController.text.trim();
    if (word.isEmpty) {
      setState(() => _error = 'Please enter a word first');
      return;
    }

    setState(() {
      _isTranslating = true;
      _error = null;
    });

    try {
      final provider = context.read<WordProvider>();
      final result = await provider.translateWord(
        word,
        from: _sourceLang,
        to: _targetLang,
      );

      _translationController.text = result.translation;
      _exampleSourceController.text = result.exampleSource;
      _exampleTargetController.text = result.exampleTarget;
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

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final provider = context.read<WordProvider>();
      final success = await provider.addWord(
        word: word,
        translation: _translationController.text.trim(),
        exampleSource: _exampleSourceController.text.trim(),
        exampleTarget: _exampleTargetController.text.trim(),
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
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red.shade800),
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
              const SizedBox(height: 16),

              // Translation fields
              TextField(
                controller: _translationController,
                decoration: const InputDecoration(
                  labelText: 'Translation',
                  prefixIcon: Icon(Icons.language),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _exampleSourceController,
                decoration: const InputDecoration(
                  labelText: 'Example (original language)',
                  prefixIcon: Icon(Icons.format_quote),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _exampleTargetController,
                decoration: const InputDecoration(
                  labelText: 'Example (translated)',
                  prefixIcon: Icon(Icons.format_quote_outlined),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Save button
              FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Saving...' : 'Save Word'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
