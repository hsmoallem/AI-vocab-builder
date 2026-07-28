import 'package:flutter/material.dart';
import '../models/word.dart';
import '../utils/clipboard_util.dart';
import 'grammar_tutor_sheet.dart';

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
                // 🎓 AI Language Tutor Console button
                IconButton(
                  icon: Icon(
                    Icons.school,
                    color: (word.grammarVersion >= 1 || word.grammarTip != null)
                        ? Colors.amber[700] ?? Colors.amber
                        : Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  tooltip: 'Open AI Language Tutor',
                  onPressed: () => showGrammarTutorSheet(context, word),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
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

            // Language pair badges & linguistic traits
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildBadge(word.sourceLang, Theme.of(context).colorScheme.primary),
                const Icon(Icons.arrow_forward, size: 14),
                _buildBadge(word.targetLang, Theme.of(context).colorScheme.tertiary),
                if (word.partOfSpeech != null && word.partOfSpeech!.isNotEmpty)
                  _buildGrammarChip(word.partOfSpeech!, Colors.indigo),
                if (word.ipa != null && word.ipa!.isNotEmpty)
                  _buildGrammarChip('[${word.ipa!}]', Colors.purple),
                if (word.grammarData?['article'] != null)
                  _buildGrammarChip('Art: ${word.grammarData?['article']}', Colors.blue),
                if (word.grammarData?['plural'] != null && word.grammarData?['plural'].toString().isNotEmpty == true)
                  _buildGrammarChip('Pl: ${word.grammarData?['plural']}', Colors.teal),
                if (word.grammarData?['feminine'] != null && word.grammarData?['feminine'].toString().isNotEmpty == true)
                  _buildGrammarChip('Fem: ${word.grammarData?['feminine']}', Colors.pink),
                if (word.grammarData?['infinitive'] != null && word.grammarData?['infinitive'].toString().isNotEmpty == true)
                  _buildGrammarChip('Inf: ${word.grammarData?['infinitive']}', Colors.cyan),
                if (word.grammarData?['verb_type'] != null && word.grammarData?['verb_type'].toString().isNotEmpty == true)
                  _buildGrammarChip('${word.grammarData?['verb_type']}', Colors.deepOrange),
                if (word.isIrregular) _buildGrammarChip('Irregular', Colors.orange),
                if (word.isReflexive) _buildGrammarChip('Reflexive', Colors.blue),
                if (word.isSeparable) _buildGrammarChip('Separable', Colors.teal),
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

  Widget _buildGrammarChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
