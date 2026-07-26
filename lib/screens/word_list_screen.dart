import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../config/app_strings.dart';
import '../models/word.dart';
import '../providers/word_provider.dart';
import '../services/tts_service.dart';
import '../services/export_service.dart';
import '../utils/clipboard_util.dart';
import '../widgets/word_card.dart';
import 'archived_words_screen.dart';

class WordListScreen extends StatefulWidget {
  const WordListScreen({super.key});

  @override
  State<WordListScreen> createState() => _WordListScreenState();
}

class _WordListScreenState extends State<WordListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TtsService _tts = TtsService();
  Timer? _debounce;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = query;
      });
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
          final msg = e.toString().replaceFirst("Exception: ", "").replaceFirst("Error: ", "");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${s.locale == "de" ? "Löschen fehlgeschlagen" : "Could not delete vocabulary item"}: $msg')),
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
        final msg = e.toString().replaceFirst("Exception: ", "").replaceFirst("Error: ", "");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not regenerate example: $msg')));
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
    final choice = await showModalBottomSheet<_ExportChoice>(
      context: context,
      isScrollControlled: true, // room for the number field / keyboard
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _ExportSheet(words: words),
      ),
    );
    if (choice == null || !context.mounted) return;
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    try {
      switch (choice.format) {
        case _ExportFormat.csv:
          await ExportService.shareFile(
              content: ExportService.toCsv(choice.words),
              filename: 'vocab_$stamp.csv',
              mime: 'text/csv');
          break;
        case _ExportFormat.txt:
          await ExportService.shareFile(
              content: ExportService.toText(choice.words),
              filename: 'vocab_$stamp.txt',
              mime: 'text/plain');
          break;
        case _ExportFormat.clip:
          if (context.mounted) {
            await copyToClipboard(context, ExportService.toTsv(choice.words),
                label: 'Word list');
          }
          break;
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst("Exception: ", "").replaceFirst("Error: ", "");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not export word list: $msg')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WordProvider>(
      builder: (context, provider, _) {
        final s = AppStrings.of(context);
        final filtered = _filter(provider.words, _searchQuery);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: s.searchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: s.locale == 'de' ? 'Suche löschen' : 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
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
                    label: provider.sortMode == SortMode.oldestFirst ? s.sortOldest : s.sortNewest,
                    icon: provider.sortMode == SortMode.oldestFirst ? Icons.history : Icons.access_time,
                    selected: provider.sortMode == SortMode.newestFirst || provider.sortMode == SortMode.oldestFirst,
                    onTap: () {
                      if (provider.sortMode == SortMode.newestFirst) {
                        provider.setSortMode(SortMode.oldestFirst);
                      } else {
                        provider.setSortMode(SortMode.newestFirst);
                      }
                    },
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
                      if (v == 'archived') {
                        context.push('/archived');
                      }
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
                        value: 'archived',
                        child: ListTile(
                          leading: const Icon(Icons.archive_outlined),
                          title: Text(s.locale == 'de'
                              ? 'Archivierte Wörter'
                              : 'Archived words'),
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
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      avatar: Icon(icon, size: 16),
      selected: selected,
      onSelected: (_) => onTap(),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      showCheckmark: false,
    );
  }
}

// ─── Export options ────────────────────────────────────────────────

enum _ExportFormat { csv, txt, clip }

class _ExportChoice {
  final _ExportFormat format;
  final List<Word> words; // already filtered + newest-first
  _ExportChoice(this.format, this.words);
}

enum _Scope { all, range, last }

/// Bottom sheet: choose a scope (all / date range / last N) then a format.
class _ExportSheet extends StatefulWidget {
  final List<Word> words;
  const _ExportSheet({required this.words});

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  _Scope _scope = _Scope.all;
  DateTime? _from;
  DateTime? _to;
  final _nController = TextEditingController(text: '20');

  @override
  void dispose() {
    _nController.dispose();
    super.dispose();
  }

  List<Word> _filtered() {
    final all = [...widget.words]
      ..sort((a, b) {
        final c = b.createdAt.compareTo(a.createdAt);
        return c != 0 ? c : (b.id ?? 0).compareTo(a.id ?? 0);
      });
    switch (_scope) {
      case _Scope.all:
        return all;
      case _Scope.range:
        if (_from == null || _to == null) return const [];
        // Compare by LOCAL calendar day (YYYYMMDD) so time-of-day never
        // excludes a same-day word; swap if the range is reversed.
        int dnum(DateTime d) {
          final l = d.toLocal();
          return l.year * 10000 + l.month * 100 + l.day;
        }

        final a = dnum(_from!);
        final b = dnum(_to!);
        final lo = a <= b ? a : b;
        final hi = a <= b ? b : a;
        return all.where((w) {
          final d = dnum(w.createdAt);
          return d >= lo && d <= hi;
        }).toList();
      case _Scope.last:
        final n = int.tryParse(_nController.text.trim()) ?? 0;
        return n <= 0 ? const [] : all.take(n).toList();
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _from : _to) ?? now,
      // The "To" date can't be earlier than the "From" date.
      firstDate: isFrom ? DateTime(2020) : (_from ?? DateTime(2020)),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _from = picked;
          if (_to != null && _to!.isBefore(picked)) _to = picked; // keep To ≥ From
        } else {
          _to = picked;
        }
      });
    }
  }

  String _fmt(DateTime? d) => d == null
      ? 'Pick'
      : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Widget _fmtTile(
      IconData icon, String title, String? subtitle, bool ready, _ExportFormat f) {
    return ListTile(
      enabled: ready,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, style: const TextStyle(fontSize: 12)),
      onTap: ready
          ? () => Navigator.pop(context, _ExportChoice(f, _filtered()))
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final count = _filtered().length;
    final ready = count > 0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Export word list',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 2),
            Text('Newest words first',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            SegmentedButton<_Scope>(
              segments: const [
                ButtonSegment(value: _Scope.all, label: Text('All')),
                ButtonSegment(value: _Scope.range, label: Text('Range')),
                ButtonSegment(value: _Scope.last, label: Text('Last N')),
              ],
              selected: {_scope},
              onSelectionChanged: (s) => setState(() {
                _scope = s.first;
                // Default the range to TODAY so it immediately shows today's words.
                if (_scope == _Scope.range) {
                  final now = DateTime.now();
                  _from ??= now;
                  _to ??= now;
                }
              }),
            ),
            const SizedBox(height: 12),
            if (_scope == _Scope.range)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event, size: 16),
                      label: Text('From: ${_fmt(_from)}'),
                      onPressed: () => _pickDate(true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event, size: 16),
                      label: Text('To: ${_fmt(_to)}'),
                      onPressed: () => _pickDate(false),
                    ),
                  ),
                ],
              ),
            if (_scope == _Scope.last)
              TextField(
                controller: _nController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Number of most recent words',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            const SizedBox(height: 10),
            Text('$count word${count == 1 ? '' : 's'} selected',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            const Divider(height: 20),
            _fmtTile(Icons.table_chart_outlined, 'Share as CSV',
                'Excel — or "Save to Drive" to open as a Google Sheet', ready,
                _ExportFormat.csv),
            _fmtTile(Icons.description_outlined, 'Share as text', null, ready,
                _ExportFormat.txt),
            _fmtTile(Icons.content_copy, 'Copy to clipboard', null, ready,
                _ExportFormat.clip),
          ],
        ),
      ),
    );
  }
}
