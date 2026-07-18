import 'package:flutter/material.dart';
import '../models/word.dart';
import '../utils/clipboard_util.dart';

class WordCard extends StatelessWidget {
  final Word word;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleReview;
  final VoidCallback? onSpeakWord;       // Speak the word in source language
  final VoidCallback? onSpeakExample;    // Speak the example in source language
  final VoidCallback? onSpeakTargetExample; // Speak the translated example
  final VoidCallback? onRegenerate;      // Regenerate the example sentence(s)

  const WordCard({
    super.key,
    required this.word,
    this.onDelete,
    this.onToggleReview,
    this.onSpeakWord,
    this.onSpeakExample,
    this.onSpeakTargetExample,
    this.onRegenerate,
  });

  /// A compact copy icon for a single piece of text.
  Widget _copyIcon(BuildContext context, String text, String label) {
    return IconButton(
      icon: const Icon(Icons.copy, size: 16),
      tooltip: 'Copy $label',
      onPressed: () => copyToClipboard(context, text, label: label),
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
    );
  }

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
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                // Copy the word only
                _copyIcon(context, word.word, 'word'),
                // Regenerate example sentence(s)
                if (onRegenerate != null)
                  IconButton(
                    icon: const Icon(Icons.autorenew, size: 19),
                    tooltip: 'Regenerate example',
                    onPressed: onRegenerate,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                // Review / flashcard toggle
                if (onToggleReview != null)
                  IconButton(
                    icon: Icon(
                      word.isReviewed
                          ? Icons.check_circle
                          : Icons.check_circle_outline,
                      color: word.isReviewed
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    tooltip: word.isReviewed ? 'Mark as unreviewed' : 'Mark as reviewed',
                    onPressed: onToggleReview,
                    iconSize: 22,
                    visualDensity: VisualDensity.compact,
                  ),
                if (onDelete != null)
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error),
                    tooltip: 'Delete word',
                    onPressed: onDelete,
                    iconSize: 22,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 6),

            // Translation — with its own copy icon
            if (word.translation.isNotEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      word.translation,
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  _copyIcon(context, word.translation, 'translation'),
                ],
              ),
            const SizedBox(height: 8),

            // Language pair badges
            Row(
              children: [
                _buildBadge(word.sourceLang, Theme.of(context).colorScheme.primary),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.arrow_forward, size: 14),
                ),
                _buildBadge(word.targetLang, Theme.of(context).colorScheme.tertiary),
              ],
            ),

            // Example (source) — with 🔊 speak button
            if (word.exampleSource.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (onSpeakExample != null)
                      Tooltip(
                        message: 'Listen to example',
                        child: GestureDetector(
                          onTap: onSpeakExample,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6, top: 1),
                            child: Icon(Icons.volume_up,
                                size: 16,
                                color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        word.exampleSource,
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    _copyIcon(context, word.exampleSource, 'example'),
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
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Tooltip(
                      message: 'Listen to translation',
                      child: GestureDetector(
                        onTap: onSpeakTargetExample,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6, top: 1),
                          child: Icon(Icons.volume_up,
                              size: 16,
                              color: Theme.of(context).colorScheme.onTertiaryContainer),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        word.exampleTarget,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                    _copyIcon(context, word.exampleTarget, 'example'),
                  ],
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
