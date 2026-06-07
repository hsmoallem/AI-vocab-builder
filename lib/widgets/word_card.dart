import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/word.dart';
import '../providers/word_provider.dart';

class WordCard extends StatelessWidget {
  final Word word;

  const WordCard({super.key, required this.word});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showEditDialog(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: word + translation + review dot
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          word.word,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          word.translation,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Review indicator
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: word.isReviewed
                          ? Colors.green
                          : Colors.grey.shade300,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Reviewed toggle
                  IconButton(
                    icon: Icon(
                      word.isReviewed ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: word.isReviewed ? Colors.green : Colors.grey,
                    ),
                    tooltip: word.isReviewed ? 'Mark as learning' : 'Mark as reviewed',
                    onPressed: () {
                      context.read<WordProvider>().toggleReviewed(word);
                    },
                  ),
                ],
              ),

              // Example sentences
              if (word.exampleSource.isNotEmpty) ...[
                const Divider(height: 20),
                Text(
                  word.exampleSource,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade700,
                  ),
                ),
                if (word.exampleTarget.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    word.exampleTarget,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final wordController = TextEditingController(text: word.word);
    final translationController = TextEditingController(text: word.translation);
    final exampleSourceController = TextEditingController(text: word.exampleSource);
    final exampleTargetController = TextEditingController(text: word.exampleTarget);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Word'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: wordController,
                decoration: const InputDecoration(labelText: 'Word'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: translationController,
                decoration: const InputDecoration(labelText: 'Translation'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: exampleSourceController,
                decoration: const InputDecoration(labelText: 'Example (original)'),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: exampleTargetController,
                decoration: const InputDecoration(labelText: 'Example (translated)'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              word.word = wordController.text.trim();
              word.translation = translationController.text.trim();
              word.exampleSource = exampleSourceController.text.trim();
              word.exampleTarget = exampleTargetController.text.trim();
              context.read<WordProvider>().updateWord(word);
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
