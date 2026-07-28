import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/word_provider.dart';
import '../services/translation_service.dart';
import '../services/database_service.dart';
import '../models/word.dart';
import '../widgets/web_top_bar.dart';

class AiQuizScreen extends StatefulWidget {
  const AiQuizScreen({super.key});

  @override
  State<AiQuizScreen> createState() => _AiQuizScreenState();
}

class _AiQuizScreenState extends State<AiQuizScreen> {
  final TranslationService _api = TranslationService();
  bool _isLoading = false;
  String? _generatedStory;
  List<Word> _selectedWords = [];
  
  int _selectionMode = 0; // 0 = Learning/Due, 1 = Manual

  void _generateStory() async {
    final provider = context.read<WordProvider>();
    List<Word> selected = [];

    if (_selectionMode == 0) {
      // Learning/Due (due words first, filled with wordlist new words up to 10)
      selected = await provider.buildSessionDeck(maxCards: 10);
      
      if (selected.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No vocabulary words available! Add some words first or try Manual selection.'))
          );
        }
        return;
      }
    } else {
      // Manual selection dialog
      if (provider.words.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your vocabulary list is empty! Add some words first.'))
        );
        return;
      }
      final manualSelection = await _showManualSelectionDialog(provider.words);
      if (manualSelection == null || manualSelection.isEmpty) {
        return; 
      }
      selected = manualSelection;
    }

    if (selected.length < 2) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Story mode requires at least 2 words! Please select more words.'))
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _generatedStory = null;
      _selectedWords = selected;
    });

    final wordsStr = selected.map((w) => w.word).join(', ');
    final themePrompt = "Write 5 simple sequential conversational sentences forming a short story using these vocabulary words: $wordsStr. Return each sentence strictly as a string in the JSON phrases list without numbering or markdown formatting.";

    try {
      final phrases = await _api.generateDailyPhrases(
        lang: selected.first.sourceLang.isNotEmpty ? selected.first.sourceLang : 'de',
        theme: themePrompt,
        level: 'B1',
      );
      
      setState(() {
        _generatedStory = phrases.map((p) => p.phrase).join(' '); // Join sentences into a story paragraph
      });
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '').replaceFirst('Error: ', '');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not generate practice story: $msg')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<List<Word>?> _showManualSelectionDialog(List<Word> allWords) async {
    final selectedWords = <Word>[];
    String searchQuery = '';
    bool sortAlphabetical = false;

    return showDialog<List<Word>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Filter and sort words
            var displayedWords = allWords.where((w) {
              return w.word.toLowerCase().contains(searchQuery.toLowerCase()) || 
                     w.translation.toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();

            if (sortAlphabetical) {
              displayedWords.sort((a, b) => a.word.toLowerCase().compareTo(b.word.toLowerCase()));
            } else {
              // Assuming Word has a createdAt or id we can sort by (fallback to reversing the list since newer is usually at the end)
              // We'll just reverse the default order as a proxy for "date added" if no date exists
              displayedWords = displayedWords.reversed.toList();
            }

            return AlertDialog(
              title: const Text('Select Vocabulary'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search words...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (val) {
                        setState(() {
                          searchQuery = val;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Sort by:'),
                        DropdownButton<bool>(
                          value: sortAlphabetical,
                          items: const [
                            DropdownMenuItem(value: false, child: Text('Date Added')),
                            DropdownMenuItem(value: true, child: Text('Alphabetical')),
                          ],
                          onChanged: (val) {
                            setState(() {
                              sortAlphabetical = val ?? false;
                            });
                          },
                        ),
                      ],
                    ),
                    const Divider(),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: displayedWords.length,
                        itemBuilder: (context, index) {
                          final word = displayedWords[index];
                          final isSelected = selectedWords.contains(word);
                          return CheckboxListTile(
                            title: Text(word.word),
                            subtitle: Text(word.translation),
                            value: isSelected,
                            onChanged: (bool? checked) {
                              setState(() {
                                if (checked == true) {
                                  selectedWords.add(word);
                                } else {
                                  selectedWords.remove(word);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: selectedWords.isEmpty
                      ? null
                      : () => Navigator.pop(context, selectedWords),
                  child: Text('Confirm (${selectedWords.length})'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _getDisplayText() {
    return _generatedStory ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _generatedStory == null,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Story Mode'),
            content: const Text('Are you sure you want to leave? Your generated story will be lost.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Leave'),
              ),
            ],
          ),
        );
        if (confirm == true && context.mounted) {
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
        title: const Text('Story Mode'),
        actions: (kIsWeb && MediaQuery.of(context).size.width > 800) ? WebTopBar.buildActions(context) : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Select vocabulary source:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Learning/Due')),
                ButtonSegment(value: 1, label: Text('Manual')),
              ],
              selected: {_selectionMode},
              onSelectionChanged: (Set<int> newSelection) {
                setState(() {
                  _selectionMode = newSelection.first;
                });
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.auto_awesome),
              label: Text(_selectionMode == 1 ? 'Select Words & Generate Story' : 'Generate AI Story'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _isLoading ? null : _generateStory,
            ),
            const SizedBox(height: 16),
            if (_selectedWords.isNotEmpty && !_isLoading) ...[
              const Text(
                'Vocabulary used in this story:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(8),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: _selectedWords.map((w) {
                      return Chip(
                        label: Text(w.word, style: const TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 8),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_generatedStory != null)
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _getDisplayText(),
                      style: const TextStyle(fontSize: 18, height: 1.8),
                    ),
                  ),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(
                  child: Text(
                    'Press Generate to create an AI story using your vocabulary.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
}
