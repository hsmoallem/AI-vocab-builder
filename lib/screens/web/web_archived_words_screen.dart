import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/word_provider.dart';
import '../../config/app_strings.dart';
import '../../models/word.dart';
import '../../services/tts_service.dart';

class WebArchivedWordsScreen extends StatefulWidget {
  const WebArchivedWordsScreen({super.key});

  @override
  State<WebArchivedWordsScreen> createState() => _WebArchivedWordsScreenState();
}

class _WebArchivedWordsScreenState extends State<WebArchivedWordsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TtsService _tts = TtsService();
  Future<List<Word>>? _archivedWordsFuture;
  
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _archivedWordsFuture = context.read<WordProvider>().archivedWords();
    });
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete permanently?'),
        content: Text('Delete "${word.word}" for good? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await context.read<WordProvider>().deleteWord(word.id!);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted "${word.word}"')));
      _load();
    }
  }

  Future<void> _unarchiveWord(BuildContext context, Word word) async {
    await context.read<WordProvider>().unarchiveWord(word);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restored "${word.word}"')));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Archived Words'),
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
          const SizedBox(width: 16),
        ],
      ),
      body: FutureBuilder<List<Word>>(
        future: _archivedWordsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final words = snapshot.data ?? [];
          final filtered = _filter(words, _searchController.text);

          if (words.isEmpty) {
             return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.archive_outlined,
                      size: 64, color: theme.colorScheme.onSurface.withOpacity(0.2)),
                  const SizedBox(height: 12),
                  Text('No archived words',
                      style: TextStyle(
                          fontSize: 16,
                          color: theme.colorScheme.onSurface.withOpacity(0.5))),
                  const SizedBox(height: 4),
                  Text('Archive a card from the flashcards to hide it here.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Spacer(),
                    Text(
                      '${filtered.length} ${s.locale == "de" ? (filtered.length == 1 ? "Wort" : "Wörter") : (filtered.length == 1 ? "word" : "words")}',
                      style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
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
                                message: 'Unarchive',
                                child: IconButton(
                                  icon: const Icon(Icons.unarchive_outlined, size: 20),
                                  onPressed: () => _unarchiveWord(context, word),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                              Tooltip(
                                message: 'Delete permanently',
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
          );
        }
      ),
    );
  }
}
