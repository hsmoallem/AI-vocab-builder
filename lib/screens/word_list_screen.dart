import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/word.dart';
import '../providers/word_provider.dart';
import '../widgets/word_card.dart';
import '../widgets/add_word_dialog.dart';

class WordListScreen extends StatefulWidget {
  const WordListScreen({super.key});

  @override
  State<WordListScreen> createState() => _WordListScreenState();
}

class _WordListScreenState extends State<WordListScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Word> _filteredWords = [];

  @override
  void initState() {
    super.initState();
    final provider = context.read<WordProvider>();
    _filteredWords = provider.words;
  }

  void _filterWords(String query, WordProvider provider) {
    if (query.isEmpty) {
      setState(() {
        _filteredWords = provider.words;
      });
    } else {
      final q = query.toLowerCase();
      setState(() {
        _filteredWords = provider.words.where((w) {
          return w.word.toLowerCase().contains(q) ||
              w.translation.toLowerCase().contains(q);
        }).toList();
      });
    }
  }

  Future<void> _deleteWord(BuildContext context, Word word) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Word'),
        content: Text('Delete "${word.word}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await context.read<WordProvider>().deleteWord(word.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${word.word}" deleted')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WordProvider>(
      builder: (context, provider, _) {
        if (_searchController.text.isEmpty) {
          _filteredWords = provider.words;
        } else {
          _filterWords(_searchController.text, provider);
        }

        return Scaffold(
          body: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  controller: _searchController,
                  onChanged: (q) => _filterWords(q, provider),
                  decoration: InputDecoration(
                    hintText: 'Search words...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _filterWords('', provider);
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
                      label: 'A-Z',
                      icon: Icons.sort_by_alpha,
                      selected: provider.sortMode == SortMode.alphabetical,
                      onTap: () => provider.setSortMode(SortMode.alphabetical),
                    ),
                    const SizedBox(width: 8),
                    _SortChip(
                      label: 'Newest',
                      icon: Icons.access_time,
                      selected: provider.sortMode == SortMode.newestFirst,
                      onTap: () => provider.setSortMode(SortMode.newestFirst),
                    ),
                    const Spacer(),
                    Text(
                      '${_filteredWords.length} word${_filteredWords.length == 1 ? '' : 's'}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),

              // Word list
              Expanded(
                child: _filteredWords.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.menu_book_outlined,
                                size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'No matching words'
                                  : 'No words yet.\nTap + to add one!',
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
                        itemCount: _filteredWords.length,
                        itemBuilder: (context, index) {
                          final word = _filteredWords[index];
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
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),

          // FAB
          floatingActionButton: FloatingActionButton(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const AddWordDialog(),
            ),
            child: const Icon(Icons.add),
          ),
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
