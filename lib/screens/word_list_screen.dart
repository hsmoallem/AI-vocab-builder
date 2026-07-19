import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_strings.dart';
import '../models/word.dart';
import '../providers/word_provider.dart';
import '../services/tts_service.dart';
import '../services/export_service.dart';
import '../utils/clipboard_util.dart';
import '../widgets/word_card.dart';

class WordListScreen extends StatefulWidget {
  const WordListScreen({super.key});

  @override
  State<WordListScreen> createState() => _WordListScreenState();
}

class _WordListScreenState extends State<WordListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TtsService _tts = TtsService();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Word> _filter(List<Word> words, String query) {
    if (query.isEmpty) return words;
    final q = query.toLowerCase();
    return words.where((w) {
      return w.word.toLowerCase().contains(q) ||
          w.translation.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _deleteWord(BuildContext context, Word word) async {
    final s = AppStrings.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteConfirmTitle),
        content: Text(s.deleteConfirmBody(word.word)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: Text(s.delete),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        await context.read<WordProvider>().deleteWord(word.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"${word.word}" ${s.locale == "de" ? "gelöscht" : "deleted"}')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${s.locale == "de" ? "Löschen fehlgeschlagen" : "Delete failed"}: $e')),
          );
        }
      }
    }
  }

  Future<void> _regenerate(BuildContext context, Word word) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Regenerating example…'),
          duration: Duration(seconds: 2)),
    );
    try {
      await context.read<WordProvider>().regenerateExample(word);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Example regenerated'),
              duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _removeDuplicates(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove duplicates?'),
        content: const Text(
          'Removes words that repeat the same text and language pair, keeping '
          'the oldest of each. This cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    final removed = await context.read<WordProvider>().removeDuplicates();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(removed == 0
              ? 'No duplicates found'
              : 'Removed $removed duplicate${removed == 1 ? '' : 's'}'),
        ),
      );
    }
  }

  Future<void> _export(BuildContext context) async {
    final words = context.read<WordProvider>().words;
    if (words.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No words to export')));
      return;
    }
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Export word list',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Newest words first'),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('Share as CSV (opens in Excel)'),
              onTap: () => Navigator.pop(ctx, 'csv'),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Share as text'),
              onTap: () => Navigator.pop(ctx, 'txt'),
            ),
            ListTile(
              leading: const Icon(Icons.content_copy),
              title: const Text('Copy to clipboard (paste into Excel)'),
              onTap: () => Navigator.pop(ctx, 'clip'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    try {
      switch (choice) {
        case 'csv':
          await ExportService.shareFile(
              content: ExportService.toCsv(words),
              filename: 'vocab_$stamp.csv',
              mime: 'text/csv');
          break;
        case 'txt':
          await ExportService.shareFile(
              content: ExportService.toText(words),
              filename: 'vocab_$stamp.txt',
              mime: 'text/plain');
          break;
        case 'clip':
          if (context.mounted) {
            await copyToClipboard(context, ExportService.toTsv(words),
                label: 'Word list');
          }
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WordProvider>(
      builder: (context, provider, _) {
        final s = AppStrings.of(context);
        final filtered = _filter(provider.words, _searchController.text);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: s.searchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: s.locale == 'de' ? 'Suche löschen' : 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            // Sort toggle + count + Export
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _SortChip(
                    label: s.sortAlphabetical,
                    icon: Icons.sort_by_alpha,
                    selected: provider.sortMode == SortMode.alphabetical,
                    onTap: () => provider.setSortMode(SortMode.alphabetical),
                  ),
                  const SizedBox(width: 8),
                  _SortChip(
                    label: s.sortNewest,
                    icon: Icons.access_time,
                    selected: provider.sortMode == SortMode.newestFirst,
                    onTap: () => provider.setSortMode(SortMode.newestFirst),
                  ),
                  const Spacer(),
                  Text(
                    '${filtered.length} ${s.locale == "de" ? (filtered.length == 1 ? "Wort" : "Wörter") : (filtered.length == 1 ? "word" : "words")}',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    tooltip: s.locale == 'de' ? 'Mehr' : 'More',
                    onSelected: (v) {
                      if (v == 'dedupe') _removeDuplicates(context);
                      if (v == 'export') _export(context);
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'export',
                        child: ListTile(
                          leading: const Icon(Icons.ios_share),
                          title: Text(s.locale == 'de'
                              ? 'Wortliste exportieren'
                              : 'Export word list'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'dedupe',
                        child: ListTile(
                          leading: const Icon(Icons.cleaning_services_outlined),
                          title: Text(s.locale == 'de'
                              ? 'Duplikate entfernen'
                              : 'Remove duplicates'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Word list
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.menu_book_outlined,
                              size: 64, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2)),
                          const SizedBox(height: 12),
                          Text(
                            _searchController.text.isNotEmpty
                                ? (s.locale == 'de' ? 'Keine passenden Wörter' : 'No matching words')
                                : s.noWords,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 4, bottom: 80),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final word = filtered[index];
                        return Dismissible(
                          key: Key('word-${word.id}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            color: Theme.of(context).colorScheme.error,
                            child: Icon(Icons.delete,
                                color: Theme.of(context).colorScheme.onError),
                          ),
                          confirmDismiss: (_) async {
                            _deleteWord(context, word);
                            return false;
                          },
                          child: WordCard(
                            word: word,
                            onDelete: () => _deleteWord(context, word),
                            onToggleReview: () {
                              context.read<WordProvider>().toggleReview(word);
                            },
                            // Regenerate the example sentence(s) via AI
                            onRegenerate: () => _regenerate(context, word),
                            // 🔊 Speak word in its source language
                            onSpeakWord: () {
                              _tts.speak(word.word, language: word.sourceLang);
                            },
                            // 🔊 Speak example in its source language
                            onSpeakExample: word.exampleSource.isNotEmpty
                                ? () {
                                    _tts.speak(word.exampleSource,
                                        language: word.sourceLang);
                                  }
                                : null,
                            // 🔊 Speak target example in target language
                            onSpeakTargetExample: word.exampleTarget.isNotEmpty
                                ? () {
                                    _tts.speak(word.exampleTarget,
                                        language: word.targetLang);
                                  }
                                : null,
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
