/// ─── Bulk Import Screen ─────────────────────────────────────────────
///
/// Translate and save many words at once. Each word is run through the
/// EXACT same workflow as adding a single word — see
/// [WordProvider.importWord], which reuses the same translate() call and
/// the same corrected-spelling / German-article / example formatting as the
/// single-word Add Word dialog.
///
/// Input: paste a list (one word per line, or comma/semicolon separated).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/word_provider.dart';
import '../providers/locale_provider.dart';
import '../config/app_strings.dart';
import '../widgets/cefr_level_dropdown.dart';

class BulkImportScreen extends StatefulWidget {
  const BulkImportScreen({super.key});

  @override
  State<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends State<BulkImportScreen> {
  final _inputController = TextEditingController();

  String _sourceLang = 'de';
  String _targetLang = 'en';
  bool _skipDuplicates = true;
  String? _level;       // CEFR level (null = auto)

  bool _isImporting = false;
  int _done = 0;
  int _total = 0;
  String? _currentWord;
  String? _error;
  final List<ImportOutcome> _results = [];

  @override
  void initState() {
    super.initState();
    // Default "To" to the user's saved language, but never equal to source.
    final savedTarget = context.read<LocaleProvider>().targetLang;
    if (AppStrings.targetLanguages.containsKey(savedTarget) &&
        savedTarget != _sourceLang) {
      _targetLang = savedTarget;
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  /// Split pasted/loaded text into a clean, de-duplicated word list.
  /// Accepts one word per line and/or comma/semicolon separated values.
  List<String> _parseWords(String raw) {
    final seen = <String>{};
    final out = <String>[];
    for (final piece in raw.split(RegExp(r'[\n,;]'))) {
      final w = piece.trim();
      if (w.isEmpty) continue;
      if (seen.add(w.toLowerCase())) out.add(w);
    }
    return out;
  }

  Future<void> _import() async {
    final words = _parseWords(_inputController.text);
    if (words.isEmpty) {
      setState(() => _error = 'Paste or load at least one word first.');
      return;
    }

    final provider = context.read<WordProvider>();
    // Snapshot of existing words for duplicate-skipping (case-insensitive).
    final existing = provider.words.map((w) => w.word.toLowerCase()).toSet();

    setState(() {
      _isImporting = true;
      _error = null;
      _results.clear();
      _total = words.length;
      _done = 0;
    });

    for (final word in words) {
      if (!mounted) return;
      setState(() => _currentWord = word);

      ImportOutcome outcome;
      if (_skipDuplicates && existing.contains(word.toLowerCase())) {
        outcome = ImportOutcome(word, ImportStatus.duplicate);
      } else {
        outcome = await provider.importWord(
            input: word, from: _sourceLang, to: _targetLang, level: _level);
        // Backstop: if we still hit the per-minute limit (very large lists),
        // wait out the window and retry instead of failing the word.
        var attempt = 0;
        while (outcome.status == ImportStatus.failed &&
            (outcome.error ?? '')
                .toLowerCase()
                .contains('too many requests') &&
            attempt < 3) {
          attempt++;
          if (!mounted) return;
          setState(() => _currentWord = '$word — rate-limited, retrying…');
          await Future.delayed(const Duration(seconds: 8));
          if (!mounted) return;
          outcome = await provider.importWord(
              input: word, from: _sourceLang, to: _targetLang, level: _level);
        }
        if (outcome.status == ImportStatus.added) {
          existing.add(word.toLowerCase());
          final saved = outcome.savedWord;
          if (saved != null) existing.add(saved.toLowerCase());
        }
      }

      if (!mounted) return;
      setState(() {
        _results.add(outcome);
        _done++;
      });

      // Pace requests: a short gap between AI calls keeps the whole import
      // comfortably under the per-minute rate limit (duplicates are skipped
      // locally, so they don't need a delay).
      if (outcome.status != ImportStatus.duplicate) {
        await Future.delayed(const Duration(milliseconds: 700));
      }
    }

    // importWord() does not reload per word — reload once after the batch.
    await provider.loadWords();
    if (!mounted) return;

    final added = _results.where((r) => r.status == ImportStatus.added).length;
    final dup =
        _results.where((r) => r.status == ImportStatus.duplicate).length;
    final failed =
        _results.where((r) => r.status == ImportStatus.failed).length;

    setState(() {
      _isImporting = false;
      _currentWord = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Added $added  •  skipped $dup duplicate${dup == 1 ? '' : 's'}  •  $failed failed',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Bulk Import')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Paste words (one per line, or comma-separated). '
                'Each word is translated with the same AI '
                'workflow as adding a single word.',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 12),

              // Words input
              TextField(
                controller: _inputController,
                enabled: !_isImporting,
                minLines: 4,
                maxLines: 10,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Words',
                  alignLabelWithHint: true,
                  hintText: 'Haus\nKatze\nWasser',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              // Language selectors (same swap rule as Add Word)
              Row(
                children: [
                  Expanded(
                    child: _langDropdown(
                      label: 'From',
                      value: _sourceLang,
                      onChanged: (val) => setState(() {
                        if (val == _targetLang) _targetLang = _sourceLang;
                        _sourceLang = val;
                      }),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward, size: 18),
                  ),
                  Expanded(
                    child: _langDropdown(
                      label: 'To',
                      value: _targetLang,
                      onChanged: (val) => setState(() {
                        if (val == _sourceLang) _sourceLang = _targetLang;
                        _targetLang = val;
                      }),
                    ),
                  ),
                ],
              ),

              CheckboxListTile(
                value: _skipDuplicates,
                onChanged: _isImporting
                    ? null
                    : (v) => setState(() => _skipDuplicates = v ?? true),
                title: const Text('Skip words already in my list'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              ),

              CefrLevelDropdown(
                value: _level,
                onChanged: _isImporting
                    ? null
                    : (v) => setState(() => _level = v),
                compact: true,
              ),

              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(_error!, style: TextStyle(color: cs.error)),
              ],
              const SizedBox(height: 8),

              FilledButton.icon(
                onPressed: _isImporting ? null : _import,
                icon: _isImporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.playlist_add_check),
                label: Text(
                  _isImporting
                      ? 'Importing $_done / $_total...'
                      : 'Import & Translate',
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),

              if (_isImporting) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                    value: _total == 0 ? null : _done / _total),
                if (_currentWord != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Translating: $_currentWord',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ],

              if (_results.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Results',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                ..._results.map(_resultTile),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _langDropdown({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: const OutlineInputBorder(),
      ),
      items: AppStrings.targetLanguages.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: _isImporting
          ? null
          : (val) {
              if (val != null) onChanged(val);
            },
    );
  }

  Widget _resultTile(ImportOutcome r) {
    final cs = Theme.of(context).colorScheme;
    final IconData icon;
    final Color color;
    final String subtitle;
    switch (r.status) {
      case ImportStatus.added:
        icon = Icons.check_circle;
        color = Colors.green;
        subtitle = (r.savedWord != null && r.savedWord != r.input)
            ? 'Saved as "${r.savedWord}"'
            : 'Added';
        break;
      case ImportStatus.duplicate:
        icon = Icons.info_outline;
        color = cs.secondary;
        subtitle = 'Already in your list — skipped';
        break;
      case ImportStatus.failed:
        icon = Icons.error_outline;
        color = cs.error;
        subtitle = r.error ?? 'Failed';
        break;
    }
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(r.input),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
    );
  }
}
