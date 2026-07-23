import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/word_provider.dart';
import '../../config/app_strings.dart';
import '../../models/word.dart';
import '../../widgets/web_top_bar.dart';
import '../../widgets/add_word_dialog.dart';
import '../../services/tts_service.dart';
import '../../services/export_service.dart';

class WebWordListScreen extends StatefulWidget {
  const WebWordListScreen({super.key});

  @override
  State<WebWordListScreen> createState() => _WebWordListScreenState();
}

class _WebWordListScreenState extends State<WebWordListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TtsService _tts = TtsService();

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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: Text(s.delete),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await context.read<WordProvider>().deleteWord(word.id!);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted "${word.word}"')));
    }
  }

  Future<void> _removeDuplicates(BuildContext context) async {
    final s = AppStrings.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.locale == 'de' ? 'Duplikate entfernen?' : 'Remove duplicates?'),
        content: Text(s.locale == 'de' 
            ? 'Dies entfernt alle Wörter mit demselben Text. Nur das zuerst hinzugefügte Wort bleibt erhalten.'
            : 'This will remove all words with the exact same text. Only the first added word will be kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: Text(s.delete),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    final removed = await context.read<WordProvider>().removeDuplicates();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.locale == 'de' ? '$removed Duplikate entfernt' : 'Removed $removed duplicates')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WordProvider>();
    final s = AppStrings.of(context);
    final filtered = _filter(provider.words, _searchController.text);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.tabMyWords),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SizedBox(
              width: 300,
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: s.searchHint,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == 'export') {
                ExportService.shareFile(
                  content: ExportService.toCsv(provider.words),
                  filename: 'words.csv',
                  mime: 'text/csv',
                );
              }
              if (v == 'dedupe') _removeDuplicates(context);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    const Icon(Icons.file_download, size: 20),
                    const SizedBox(width: 8),
                    const Text('Export CSV'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'dedupe',
                child: Row(
                  children: [
                    Icon(Icons.cleaning_services, size: 20, color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 8),
                    Text(s.locale == 'de' ? 'Duplikate entfernen' : 'Remove duplicates', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          ...WebTopBar.buildActions(context),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FilterChip(
                  label: Text(s.sortAlphabetical),
                  selected: provider.sortMode == SortMode.alphabetical,
                  onSelected: (_) => provider.setSortMode(SortMode.alphabetical),
                  showCheckmark: false,
                  avatar: const Icon(Icons.sort_by_alpha, size: 18),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(provider.sortMode == SortMode.oldestFirst ? s.sortOldest : s.sortNewest),
                  selected: provider.sortMode == SortMode.newestFirst || provider.sortMode == SortMode.oldestFirst,
                  onSelected: (_) {
                    if (provider.sortMode == SortMode.newestFirst) {
                      provider.setSortMode(SortMode.oldestFirst);
                    } else {
                      provider.setSortMode(SortMode.newestFirst);
                    }
                  },
                  showCheckmark: false,
                  avatar: Icon(
                    provider.sortMode == SortMode.oldestFirst ? Icons.history : Icons.access_time, 
                    size: 18
                  ),
                ),
                const Spacer(),
                Text(
                  '${filtered.length} ${s.locale == "de" ? (filtered.length == 1 ? "Wort" : "Wörter") : (filtered.length == 1 ? "word" : "words")}',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: DataTable(
            columns: const [
              DataColumn(label: Text('Word', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Translation', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Example', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Level', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: filtered.map((word) {
              return DataRow(
                cells: [
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.volume_up, size: 18, color: theme.colorScheme.primary),
                          onPressed: () => _tts.speak(word.word, language: word.sourceLang),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          splashRadius: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(word.word, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  DataCell(Text(word.translation)),
                  DataCell(Text(word.exampleSource.isNotEmpty ? word.exampleSource : '-', maxLines: 1, overflow: TextOverflow.ellipsis)),
                  DataCell(Text(word.srsEaseFactor.toStringAsFixed(1))),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: 'Regenerate Example',
                        child: IconButton(
                          icon: Icon(Icons.auto_awesome, size: 20, color: theme.colorScheme.primary),
                          onPressed: () async {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Generating new example...')),
                            );
                            await provider.regenerateExample(word);
                          },
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      Tooltip(
                        message: word.isReviewed ? 'Mark unreviewed' : 'Mark reviewed',
                        child: IconButton(
                          icon: Icon(
                            word.isReviewed ? Icons.check_circle : Icons.adjust,
                            size: 20,
                            color: word.isReviewed ? Colors.green : Colors.grey,
                          ),
                          onPressed: () => provider.toggleReview(word),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      Tooltip(
                        message: 'Archive',
                        child: IconButton(
                          icon: const Icon(Icons.archive_outlined, size: 20),
                          onPressed: () => provider.archiveWord(word),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      Tooltip(
                        message: 'Delete',
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                          onPressed: () => _deleteWord(context, word),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  )),
                ],
              );
            }).toList(),
          ),
        ),
          ],
        ),
      ),
    );
  }
}
