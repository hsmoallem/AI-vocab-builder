/// ─── Archived Words Screen ──────────────────────────────────────────
///
/// Words archived from the flashcards live here — hidden from Saved Words
/// and the flashcard deck until restored. Unarchive brings a word back;
/// delete removes it permanently.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/word.dart';
import '../providers/word_provider.dart';

class ArchivedWordsScreen extends StatefulWidget {
  const ArchivedWordsScreen({super.key});

  @override
  State<ArchivedWordsScreen> createState() => _ArchivedWordsScreenState();
}

class _ArchivedWordsScreenState extends State<ArchivedWordsScreen> {
  List<Word>? _words; // null = still loading

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await context.read<WordProvider>().archivedWords();
    if (mounted) setState(() => _words = list);
  }

  Future<void> _unarchive(Word w) async {
    await context.read<WordProvider>().unarchiveWord(w);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${w.word}" restored')),
      );
    }
  }

  Future<void> _delete(Word w) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete permanently?'),
        content: Text('Delete "${w.word}" for good? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (w.id != null) await context.read<WordProvider>().deleteWord(w.id!);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final words = _words;
    return Scaffold(
      appBar: AppBar(title: const Text('Archived words')),
      body: words == null
          ? const Center(child: CircularProgressIndicator())
          : words.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.archive_outlined,
                          size: 64, color: cs.onSurface.withOpacity(0.2)),
                      const SizedBox(height: 12),
                      Text('No archived words',
                          style: TextStyle(
                              fontSize: 16,
                              color: cs.onSurface.withOpacity(0.5))),
                      const SizedBox(height: 4),
                      Text('Archive a card from the flashcards to hide it here.',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: words.length,
                  itemBuilder: (context, i) {
                    final w = words[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      child: ListTile(
                        title: Text(w.word,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${w.translation}\n${w.sourceLang.toUpperCase()} → ${w.targetLang.toUpperCase()}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.unarchive_outlined),
                              tooltip: 'Unarchive',
                              onPressed: () => _unarchive(w),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline, color: cs.error),
                              tooltip: 'Delete permanently',
                              onPressed: () => _delete(w),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
