import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/word_provider.dart';
import '../services/translation_service.dart';
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
  
  int _selectionMode = 0; // 0 = Due Today, 1 = Random, 2 = Manual

  void _generateQuiz() async {
    final provider = context.read<WordProvider>();
    List<Word> selected = [];

    if (_selectionMode == 0) {
      // Due today
      selected = provider.dueWords.take(5).toList();
    } else if (_selectionMode == 1) {
      // Random
      final all = List<Word>.from(provider.words)..shuffle();
      selected = all.take(5).toList();
    } else {
      // Manual would require a complex picker. For now, random 10.
      final all = List<Word>.from(provider.words)..shuffle();
      selected = all.take(10).toList();
    }

    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough words available! Add more words first.'))
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _generatedStory = null;
    });

    final wordsStr = selected.map((w) => w.word).join(', ');
    final themePrompt = "Write a creative short story (3-4 sentences) that includes all of these words: $wordsStr.";

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Mini-Stories'),
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
                ButtonSegment(value: 0, label: Text('Due Today (5)')),
                ButtonSegment(value: 1, label: Text('Random (5)')),
                ButtonSegment(value: 2, label: Text('Random (10)')),
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
              label: const Text('Generate Mini-Story'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _isLoading ? null : _generateQuiz,
            ),
            const SizedBox(height: 32),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _generatedStory != null
                      ? SingleChildScrollView(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _generatedStory!,
                              style: const TextStyle(fontSize: 18, height: 1.5),
                            ),
                          ),
                        )
                      : const Center(
                          child: Text(
                            'Press Generate to create a story using your vocabulary.',
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
