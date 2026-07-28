import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/word_provider.dart';
import '../../config/app_strings.dart';
import '../../models/word.dart';
import '../../widgets/web_top_bar.dart';
import '../../widgets/add_word_dialog.dart';
import '../../services/tts_service.dart';
import '../../services/export_service.dart';
import '../../widgets/grammar_tutor_sheet.dart';
import '../../models/study_mode.dart';
import '../../screens/study_mode_selector.dart';

class WebWordListScreen extends StatefulWidget {
  const WebWordListScreen({super.key});

  @override
  State<WebWordListScreen> createState() => _WebWordListScreenState();
}

class _WebWordListScreenState extends State<WebWordListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TtsService _tts = TtsService();
  bool _isSelecting = false;
  final Set<int> _selectedIds = {};

  Future<void> _startStudySession(BuildContext context, List<Word> selectedWords) async {
    if (selectedWords.isEmpty) return;
    final mode = await showStudyModeSelector(
      context: context,
      dueCount: selectedWords.length,
      newCount: 0,
    );
    if (mode != null && context.mounted) {
      context.push('/review', extra: {'mode': mode, 'deck': selectedWords});
    }
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
          const SizedBox(width: 16),
          ...WebTopBar.buildActions(context),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9), // bg-slate-100
                          borderRadius: BorderRadius.circular(12), // rounded-xl
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildSegmentButton(
                              context,
                              label: s.sortAlphabetical,
                              icon: Icons.sort_by_alpha,
                              isActive: provider.sortMode == SortMode.alphabetical,
                              onTap: () => provider.setSortMode(SortMode.alphabetical),
                            ),
                            const SizedBox(width: 4),
                            _buildSegmentButton(
                              context,
                              label: provider.sortMode == SortMode.oldestFirst ? s.sortOldest : s.sortNewest,
                              icon: provider.sortMode == SortMode.oldestFirst ? Icons.history : Icons.access_time,
                              isActive: provider.sortMode == SortMode.newestFirst || provider.sortMode == SortMode.oldestFirst,
                              onTap: () {
                                if (provider.sortMode == SortMode.newestFirst) {
                                  provider.setSortMode(SortMode.oldestFirst);
                                } else {
                                  provider.setSortMode(SortMode.newestFirst);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        icon: Icon(_isSelecting ? Icons.check_box : Icons.check_box_outline_blank, size: 18),
                        label: Text(_isSelecting ? 'Exit Select Mode' : 'Select to Study'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isSelecting ? theme.colorScheme.primary : const Color(0xFFF1F5F9),
                          foregroundColor: _isSelecting ? theme.colorScheme.onPrimary : const Color(0xFF1E293B),
                          elevation: _isSelecting ? 2 : 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _isSelecting = !_isSelecting;
                            if (!_isSelecting) _selectedIds.clear();
                          });
                        },
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.archive_outlined, size: 18),
                        label: const Text('Archived words'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF475569),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => context.push('/archived'),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.file_download_outlined, size: 18),
                        label: const Text('Export CSV'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF475569),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          ExportService.shareFile(
                            content: ExportService.toCsv(provider.words),
                            filename: 'words.csv',
                            mime: 'text/csv',
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '${filtered.length} ${s.locale == "de" ? (filtered.length == 1 ? "Wort" : "Wörter") : (filtered.length == 1 ? "word" : "words")}',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isSelecting) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [theme.colorScheme.primary.withAlpha(30), theme.colorScheme.secondary.withAlpha(20)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.primary.withAlpha(80)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.library_books, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Text(
                      '${_selectedIds.length} word${_selectedIds.length == 1 ? "" : "s"} selected',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 24),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: theme.colorScheme.primary.withAlpha(100)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            minimumSize: Size.zero,
                          ),
                          onPressed: () {
                            setState(() {
                              _selectedIds.clear();
                              for (var i = 0; i < filtered.length && i < 20; i++) {
                                if (filtered[i].id != null) _selectedIds.add(filtered[i].id!);
                              }
                            });
                          },
                          child: const Text('Top 20', style: TextStyle(fontSize: 12)),
                        ),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: theme.colorScheme.primary.withAlpha(100)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            minimumSize: Size.zero,
                          ),
                          onPressed: () {
                            setState(() {
                              _selectedIds.clear();
                              for (var i = 0; i < filtered.length && i < 40; i++) {
                                if (filtered[i].id != null) _selectedIds.add(filtered[i].id!);
                              }
                            });
                          },
                          child: const Text('Top 40', style: TextStyle(fontSize: 12)),
                        ),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: theme.colorScheme.primary.withAlpha(100)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            minimumSize: Size.zero,
                          ),
                          onPressed: () {
                            setState(() {
                              _selectedIds.clear();
                              final now = DateTime.now();
                              for (var w in filtered) {
                                if (w.id != null && (w.srsNextDue == null || w.srsNextDue!.isBefore(now))) {
                                  _selectedIds.add(w.id!);
                                }
                              }
                            });
                          },
                          child: const Text('All Due Today', style: TextStyle(fontSize: 12)),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            minimumSize: Size.zero,
                          ),
                          onPressed: () => setState(() => _selectedIds.clear()),
                          child: const Text('Clear', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ),
                      ],
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.rocket_launch, size: 18),
                      label: Text('Study Selected (${_selectedIds.length})'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _selectedIds.isEmpty
                          ? null
                          : () {
                              final selectedWords = provider.words.where((w) => w.id != null && _selectedIds.contains(w.id!)).toList();
                              _startStudySession(context, selectedWords);
                            },
                    ),
                  ],
                ),
              ),
            ],
            Expanded(
              child: Container(
                width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xCCE2E8F0)), // border-slate-200/80
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double tableWidth = constraints.maxWidth < 850 ? 850.0 : constraints.maxWidth;
                  const headerStyle = TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  );
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: tableWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            color: const Color(0xCCF8FAFC),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            child: Row(
                              children: [
                                if (_isSelecting) ...[
                                  SizedBox(
                                    width: 40,
                                    child: Checkbox(
                                      value: filtered.isNotEmpty && filtered.every((w) => w.id != null && _selectedIds.contains(w.id!)),
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            for (var w in filtered) {
                                              if (w.id != null) _selectedIds.add(w.id!);
                                            }
                                          } else {
                                            _selectedIds.clear();
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(flex: 2, child: Text('WORD', style: headerStyle)),
                                const SizedBox(width: 16),
                                Expanded(flex: 3, child: Text('TRANSLATION', style: headerStyle)),
                                const SizedBox(width: 16),
                                Expanded(flex: 6, child: Text('EXAMPLE', style: headerStyle)),
                                const SizedBox(width: 16),
                                const SizedBox(width: 60, child: Text('LEVEL', style: headerStyle)),
                                const SizedBox(width: 16),
                                const SizedBox(width: 180, child: Text('ACTIONS', style: headerStyle)),
                              ],
                            ),
                          ),
                          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
                          Expanded(
                            child: ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final word = filtered[index];
                                return Column(
                                  children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (_isSelecting) ...[
                                        SizedBox(
                                          width: 40,
                                          child: Checkbox(
                                            value: word.id != null && _selectedIds.contains(word.id!),
                                            onChanged: (val) {
                                              setState(() {
                                                if (word.id == null) return;
                                                if (val == true) {
                                                  _selectedIds.add(word.id!);
                                                } else {
                                                  _selectedIds.remove(word.id!);
                                                }
                                              });
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      Expanded(
                                        flex: 2,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            IconButton(
                                              icon: Icon(Icons.volume_up, size: 18, color: theme.colorScheme.primary),
                                              onPressed: () => _tts.speak(word.word, language: word.sourceLang),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                              splashRadius: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  SelectableText(
                                                    word.word,
                                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                                                  ),
                                                  if (word.partOfSpeech != null || word.ipa != null || (word.grammarData != null && word.grammarData!.isNotEmpty) || word.isIrregular || word.isReflexive || word.isSeparable)
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 6),
                                                      child: Wrap(
                                                        spacing: 6,
                                                        runSpacing: 4,
                                                        children: [
                                                          if (word.partOfSpeech != null && word.partOfSpeech!.isNotEmpty)
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                              decoration: BoxDecoration(color: theme.colorScheme.primary.withAlpha(25), borderRadius: BorderRadius.circular(8)),
                                                              child: Text(word.partOfSpeech!, style: TextStyle(fontSize: 11.5, color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                                                            ),
                                                          if (word.ipa != null && word.ipa!.isNotEmpty)
                                                            Text('[${word.ipa!}]', style: const TextStyle(fontSize: 11.5, color: Colors.purple, fontFamily: 'Courier')),
                                                          if (word.grammarData?['article'] != null)
                                                            Text('Art: ${word.grammarData?['article']}', style: const TextStyle(fontSize: 11.5, color: Colors.blue, fontWeight: FontWeight.w600)),
                                                          if (word.grammarData?['plural'] != null && word.grammarData?['plural'].toString().isNotEmpty == true)
                                                            Text('Pl: ${word.grammarData?['plural']}', style: const TextStyle(fontSize: 11.5, color: Colors.teal, fontWeight: FontWeight.w600)),
                                                          if (word.grammarData?['feminine'] != null && word.grammarData?['feminine'].toString().isNotEmpty == true)
                                                            Text('Fem: ${word.grammarData?['feminine']}', style: const TextStyle(fontSize: 11.5, color: Colors.pink, fontWeight: FontWeight.w600)),
                                                          if (word.grammarData?['infinitive'] != null && word.grammarData?['infinitive'].toString().isNotEmpty == true)
                                                            Text('Inf: ${word.grammarData?['infinitive']}', style: const TextStyle(fontSize: 11.5, color: Colors.cyan, fontWeight: FontWeight.w600)),
                                                          if (word.grammarData?['verb_type'] != null && word.grammarData?['verb_type'].toString().isNotEmpty == true)
                                                            Text('${word.grammarData?['verb_type']}', style: const TextStyle(fontSize: 11.5, color: Colors.deepOrange, fontWeight: FontWeight.w600)),
                                                          if (word.isIrregular)
                                                            Text('Irregular', style: const TextStyle(fontSize: 11.5, color: Colors.orange, fontWeight: FontWeight.bold)),
                                                          if (word.isReflexive)
                                                            Text('Reflexive', style: const TextStyle(fontSize: 11.5, color: Colors.blue, fontWeight: FontWeight.bold)),
                                                          if (word.isSeparable)
                                                            Text('Separable', style: const TextStyle(fontSize: 11.5, color: Colors.teal, fontWeight: FontWeight.bold)),
                                                        ],
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 3,
                                        child: SelectableText(
                                          word.translation,
                                          style: const TextStyle(fontSize: 14.5),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 6,
                                        child: word.exampleSource.isNotEmpty
                                            ? Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: word.exampleSource
                                                    .split('\n')
                                                    .map((line) => line.trim())
                                                    .where((line) => line.isNotEmpty)
                                                    .map((line) {
                                                  return Padding(
                                                    padding: const EdgeInsets.only(bottom: 8.0),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        IconButton(
                                                          icon: Icon(Icons.volume_up, size: 16, color: theme.colorScheme.primary),
                                                          onPressed: () {
                                                            final cleanText = line.replaceAll('•', '').trim();
                                                            _tts.speak(cleanText, language: word.sourceLang);
                                                          },
                                                          padding: EdgeInsets.zero,
                                                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                                          splashRadius: 16,
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Expanded(
                                                          child: SelectableText(
                                                            line,
                                                            style: TextStyle(
                                                              color: theme.colorScheme.onSurface,
                                                              fontSize: 13.5,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }).toList(),
                                              )
                                            : const SelectableText('-'),
                                      ),
                                      const SizedBox(width: 16),
                                      SizedBox(
                                        width: 60,
                                        child: Text(
                                          word.srsEaseFactor.toStringAsFixed(1),
                                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      SizedBox(
                                        width: 180,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Tooltip(
                                              message: 'Open AI Language Tutor',
                                              child: IconButton(
                                                icon: Icon(Icons.school, size: 19, color: (word.grammarVersion >= 1 || word.grammarTip != null) ? Colors.amber[700] ?? Colors.amber : theme.colorScheme.primary),
                                                onPressed: () => showGrammarTutorSheet(context, word),
                                                visualDensity: VisualDensity.compact,
                                              ),
                                            ),
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
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                              ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentButton(BuildContext context, {required String label, required IconData icon, required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isActive ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            )
          ] : [],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? const Color(0xFF7C3AED) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? const Color(0xFF7C3AED) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

