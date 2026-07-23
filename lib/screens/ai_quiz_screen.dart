import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/word_provider.dart';
import '../services/translation_service.dart';
import '../services/database_service.dart';
import '../models/word.dart';

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
  
  int _selectionMode = 0; // 0 = Due Today, 1 = Random, 2 = Manual

  void _generateQuiz() async {
    final provider = context.read<WordProvider>();
    List<Word> selected = [];

    if (_selectionMode == 0) {
      // Due today
      // Fetch fresh from the database in case the provider hasn't loaded them yet
      final dueWords = await DatabaseService.getDueWords();
      selected = dueWords.take(5).toList();
      if (selected.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No words are due for review today! Try Random or Manual selection.'))
        );
        return;
      }
    } else if (_selectionMode == 1) {
      // Random
      final all = List<Word>.from(provider.words)..shuffle();
      selected = all.take(5).toList();
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
        return; // User cancelled or selected nothing
      }
      selected = manualSelection;
    }

    setState(() {
      _isLoading = true;
      _generatedStory = null;
      _selectedWords = selected;
      _showAnswers = false; // Hide words in text initially for quiz mode
    });

    final wordsStr = selected.map((w) => w.word).join(', ');
    final themePrompt = "Write separate educational sentences using these specific words: $wordsStr.";

    try {
      final phrases = await _api.generateDailyPhrases(
        lang: selected.first.sourceLang.isNotEmpty ? selected.first.sourceLang : 'de',
        theme: themePrompt,
      );
      
      setState(() {
        _generatedStory = phrases.map((p) => p.phrase).join('\n\n');
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
    return showDialog<List<Word>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select Vocabulary'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: allWords.length,
                  itemBuilder: (context, index) {
                    final word = allWords[index];
                    final isSelected = selectedWords.contains(word);
                    return CheckboxListTile(
                      title: Text(word.word),
                      value: isSelected,
                      onChanged: (bool? checked) {
                        setState(() {
                          if (checked == true) {
                            if (selectedWords.length < 10) {
                              selectedWords.add(word);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('You can select a maximum of 10 words.'))
                              );
                            }
                          } else {
                            selectedWords.remove(word);
                          }
                        });
                      },
                    );
                  },
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
    if (_showAnswers) return _generatedStory!;

    String hiddenText = _generatedStory!;
    // Hide the selected words in the text to make it a quiz
    for (final w in _selectedWords) {
      // Basic case-insensitive replacement with blanks
      final regex = RegExp(w.word, caseSensitive: false);
      hiddenText = hiddenText.replaceAll(regex, '____');
    }
    return hiddenText;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Contextual Quiz'),
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
                ButtonSegment(value: 0, label: Text('Due Today')),
                ButtonSegment(value: 1, label: Text('Random')),
                ButtonSegment(value: 2, label: Text('Manual')),
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
              label: Text(_selectionMode == 2 ? 'Select Words & Generate' : 'Generate AI Quiz'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _isLoading ? null : _generateQuiz,
            ),
            const SizedBox(height: 16),
            if (_selectedWords.isNotEmpty && !_isLoading) ...[
              const Text(
                'Vocabulary used in this quiz:',
                style: TextStyle(fontWeight: FontWeight.bold),
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
                            child: Text(
                              _getDisplayText(),
                              style: const TextStyle(fontSize: 18, height: 1.8),
                            ),
                          ),
                        )
                      : const Center(
                          child: Text(
                            'Press Generate to create a contextual quiz using your vocabulary.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
