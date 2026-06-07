import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_strings.dart';
import '../models/word.dart';
import '../providers/word_provider.dart';
import '../services/tts_service.dart';
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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

            // Sort toggle + count
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
                    style: TextStyle(color: Colors.grey.shade600),
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
                              size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            _searchController.text.isNotEmpty
                                ? (s.locale == 'de' ? 'Keine passenden Wörter' : 'No matching words')
                                : s.noWords,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade500,
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
                            color: Colors.red,
                            child: const Icon(Icons.delete, color: Colors.white),
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
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : Colors.grey.shade700,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
