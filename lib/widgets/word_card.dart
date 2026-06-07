import 'package:flutter/material.dart';
import '../models/word.dart';

class WordCard extends StatelessWidget {
  final Word word;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleReview;
  final VoidCallback? onSpeakWord;       // Speak the word in source language
  final VoidCallback? onSpeakExample;    // Speak the example in source language

  const WordCard({
    super.key,
    required this.word,
    this.onDelete,
    this.onToggleReview,
    this.onSpeakWord,
    this.onSpeakExample,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Word + speak + review + delete
            Row(
              children: [
                // 🔊 Speak word button — plays the word in source language
                if (onSpeakWord != null)
                  IconButton(
                    icon: const Icon(Icons.volume_up, size: 20),
                    tooltip: 'Listen to word',
                    onPressed: onSpeakWord,
                    color: Theme.of(context).colorScheme.primary,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                Expanded(
                  child: Text(
                    word.word,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Review / flashcard toggle
                if (onToggleReview != null)
                  IconButton(
                    icon: Icon(
                      word.isReviewed
                          ? Icons.check_circle
                          : Icons.check_circle_outline,
                      color: word.isReviewed ? Colors.green : Colors.grey,
                    ),
                    tooltip: word.isReviewed ? 'Mark as unreviewed' : 'Mark as reviewed',
                    onPressed: onToggleReview,
                    iconSize: 22,
                    visualDensity: VisualDensity.compact,
                  ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Delete word',
                    onPressed: onDelete,
                    iconSize: 22,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 6),

            // Translation
            if (word.translation.isNotEmpty)
              Text(
                word.translation,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                ),
              ),
            const SizedBox(height: 8),

            // Language pair badges
            Row(
              children: [
                _buildBadge(word.sourceLang, Colors.blue),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                ),
                _buildBadge(word.targetLang, Colors.green),
              ],
            ),

            // Example (source) — with 🔊 speak button
            if (word.exampleSource.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (onSpeakExample != null)
                      GestureDetector(
                        onTap: onSpeakExample,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6, top: 1),
                          child: Icon(Icons.volume_up,
                              size: 16, color: Colors.grey[600]),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        word.exampleSource,
                        style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Example (target)
            if (word.exampleTarget.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  word.exampleTarget,
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
