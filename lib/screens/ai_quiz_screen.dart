import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  bool _showAnswers = true;
  
  int _selectionMode = 0; // 0 = Review, 1 = Random, 2 = Manual
  bool _isStoryMode = false;

  void _generateQuiz() async {
    final provider = context.read<WordProvider>();
    List<Word> selected = [];

    if (_selectionMode == 0) {
      // Due today or New words
      final dueWords = await DatabaseService.getDueWords();
      final newWords = await DatabaseService.getNewWords();
      final reviewList = [...dueWords, ...newWords];
      
      selected = reviewList.take(5).toList();
      if (selected.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No words are due for review or learning! Try Random or Manual selection.'))
          );
        }
        return;
      }
    } else if (_selectionMode == 1) {
      // Random
      final all = List<Word>.from(provider.words)..shuffle();
      // If story mode, we need at least 10 words for random
      selected = all.take(_isStoryMode ? 10 : 5).toList();
      if (selected.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your vocabulary list is empty! Add some words first.'))
        );
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

    if (_isStoryMode && selected.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Story mode requires at least 10 words! Please select more words.'))
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _generatedStory = null;
      _selectedWords = selected;
      _showAnswers = _isStoryMode; // In story mode, don't hide words
    });

    final wordsStr = selected.map((w) => w.word).join(', ');
    final themePrompt = _isStoryMode 
        ? "Write a creative short story that includes all of these words: $wordsStr"
        : "Write separate educational sentences using these specific words: $wordsStr.";

    try {
      final phrases = await _api.generateDailyPhrases(
        lang: selected.first.sourceLang.isNotEmpty ? selected.first.sourceLang : 'de',
        theme: themePrompt,
      );
      
      setState(() {
        _generatedStory = _isStoryMode 
            ? phrases.map((p) => p.phrase).join(' ') // Join as paragraph for story
            : phrases.map((p) => p.phrase).join('\n\n'); // Separate sentences for quiz
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate: $e'))
      );
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
              content: SizedBox(
                width: double.maxFinite,
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
                    Expanded(
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
    if (_generatedStory == null) return '';
    if (_showAnswers || _isStoryMode) return _generatedStory!;

    String hiddenText = _generatedStory!;
    // Hide the selected words in the text to make it a quiz
    for (final w in _selectedWords) {
      final regex = RegExp(w.word, caseSensitive: false);
      hiddenText = hiddenText.replaceAll(regex, '____');
    }
    return hiddenText;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Quizzes & Stories'),
        actions: kIsWeb ? WebTopBar.buildActions(context) : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Quiz Mode')),
                      ButtonSegment(value: true, label: Text('Story Mode')),
                    ],
                    selected: {_isStoryMode},
                    onSelectionChanged: (Set<bool> newSelection) {
                      setState(() {
                        _isStoryMode = newSelection.first;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Select vocabulary source:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SegmentedButton<int>(
              segments: [
                const ButtonSegment(value: 0, label: Text('Learning/Due')),
                ButtonSegment(value: 1, label: Text(_isStoryMode ? 'Random (10)' : 'Random (5)')),
                const ButtonSegment(value: 2, label: Text('Manual')),
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
              label: Text(_selectionMode == 2 ? 'Select Words & Generate' : 'Generate AI ${_isStoryMode ? 'Story' : 'Quiz'}'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _isLoading ? null : _generateQuiz,
            ),
            const SizedBox(height: 16),
            if (_selectedWords.isNotEmpty && !_isLoading) ...[
              Text(
                _isStoryMode ? 'Vocabulary used in this story:' : 'Vocabulary used in this quiz:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedWords.map((w) {
                  return Chip(
                    label: Text(w.word),
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              if (!_isStoryMode)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Fill in the blanks:'),
                    TextButton.icon(
                      icon: Icon(_showAnswers ? Icons.visibility_off : Icons.visibility),
                      label: Text(_showAnswers ? 'Hide Answers' : 'Show Answers'),
                      onPressed: () {
                        setState(() {
                          _showAnswers = !_showAnswers;
                        });
                      },
                    ),
                  ],
                ),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _generatedStory != null
                      ? SingleChildScrollView(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: SelectableText(
                              _getDisplayText(),
                              style: const TextStyle(fontSize: 18, height: 1.8),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            'Press Generate to create a ${_isStoryMode ? 'story' : 'contextual quiz'} using your vocabulary.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
