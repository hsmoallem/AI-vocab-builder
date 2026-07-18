import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/word.dart';
import '../providers/word_provider.dart';
import '../services/tts_service.dart';

class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({super.key});

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _isFlipped = false;
  final TtsService _tts = TtsService();

  int _currentIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
    _pageController = PageController();
  }

  @override
  void dispose() {
    _flipController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _flip() {
    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
      // Mark as reviewed when card is flipped
      final words = context.read<WordProvider>().words;
      if (_currentIndex < words.length) {
        final word = words[_currentIndex];
        if (!word.isReviewed) {
          context.read<WordProvider>().toggleReview(word);
        }
      }
    }
    setState(() => _isFlipped = !_isFlipped);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WordProvider>(
      builder: (context, provider, _) {
        final words = provider.words;
        if (words.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Flashcards')),
            body: const Center(child: Text('No words yet. Add some first!')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('Flashcard ${_currentIndex + 1} of ${words.length}'),
          ),
          body: Column(
            children: [
              // Progress bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_currentIndex + 1) / words.length,
                    minHeight: 6,
                  ),
                ),
              ),

              // Flashcard
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: words.length,
                  onPageChanged: (i) {
                    setState(() {
                      _currentIndex = i;
                      _isFlipped = false;
                      _flipController.reset();
                    });
                  },
                  itemBuilder: (context, index) {
                    final word = words[index];
                    return _buildCard(context, word);
                  },
                ),
              ),

              // Bottom controls
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Previous
                    IconButton.filled(
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Previous card',
                      onPressed: _currentIndex > 0
                          ? () => _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              )
                          : null,
                    ),
                    // Flip button
                    Tooltip(
                      message: _isFlipped
                          ? 'Flip back'
                          : 'Show translation',
                      child: FilledButton.icon(
                        onPressed: _flip,
                        icon: const Icon(Icons.flip),
                        label: Text(_isFlipped ? 'Hide' : 'Reveal'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 14),
                        ),
                      ),
                    ),
                    // Next
                    IconButton.filled(
                      icon: const Icon(Icons.arrow_forward),
                      tooltip: 'Next card',
                      onPressed: _currentIndex < words.length - 1
                          ? () => _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              )
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCard(BuildContext context, Word word) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: GestureDetector(
        onTap: _flip,
        child: AnimatedBuilder(
          animation: _flipAnimation,
          builder: (context, child) {
            final angle = _flipAnimation.value * 3.14159; // pi radians
            final isShowingFront = _flipAnimation.value <= 0.5;

            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(angle),
              child: isShowingFront
                  ? _buildFront(context, word)
                  : Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(3.14159),
                      child: _buildBack(context, word),
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFront(BuildContext context, Word word) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primaryContainer,
              Theme.of(context).colorScheme.primary.withAlpha(40),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    word.word,
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.volume_up, size: 28),
                    tooltip: 'Listen',
                    onPressed: () => _tts.speak(word.word, language: word.sourceLang),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  word.sourceLang.toUpperCase(),
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Tap to reveal',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBack(BuildContext context, Word word) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primaryContainer,
              Theme.of(context).colorScheme.primaryContainer,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Word (smaller)
              Text(
                word.word,
                style: TextStyle(
                    fontSize: 20,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),

              // Translation
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: Text(
                      word.translation,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.volume_up, size: 28),
                    tooltip: 'Listen',
                    onPressed: () => _tts.speak(word.translation, language: word.targetLang),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Language badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  word.targetLang.toUpperCase(),
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.w600),
                ),
              ),

              // Examples
              if (word.exampleSource.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (word.exampleSource.isNotEmpty)
                        Text(
                          word.exampleSource,
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      if (word.exampleTarget.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        const Divider(),
                        Text(
                          word.exampleTarget,
                          style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurface),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
              Text(
                'Tap to flip back',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
