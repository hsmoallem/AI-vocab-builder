/// ─── Study Mode Selector ─────────────────────────────────────────────
///
/// Bottom sheet shown before starting a review session. Lets the user
/// pick an active-recall mode (Flip / Type / Reverse / Cloze), see the
/// available card counts, and start the session.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/study_mode.dart';

/// Shows the study-mode picker as a modal bottom sheet.
///
/// Returns the selected [StudyMode], or `null` if the user dismissed.
Future<StudyMode?> showStudyModeSelector({
  required BuildContext context,
  required int dueCount,
  required int newCount,
}) {
  return showModalBottomSheet<StudyMode>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _StudyModeSheet(
      dueCount: dueCount,
      newCount: newCount,
    ),
  );
}

class _StudyModeSheet extends StatefulWidget {
  final int dueCount;
  final int newCount;

  const _StudyModeSheet({required this.dueCount, required this.newCount});

  @override
  State<_StudyModeSheet> createState() => _StudyModeSheetState();
}

class _StudyModeSheetState extends State<_StudyModeSheet> {
  late StudyMode _selected;

  @override
  void initState() {
    super.initState();
    _selected = StudyMode.flip;
    // Restore last-used mode from SharedPreferences.
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      final idx = prefs.getInt(kStudyModePrefKey);
      if (idx != null && idx >= 0 && idx < StudyMode.values.length) {
        setState(() => _selected = StudyMode.values[idx]);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = widget.dueCount + widget.newCount;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Study Mode',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            // Mode chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: StudyMode.values.map((mode) {
                final selected = _selected == mode;
                return ChoiceChip(
                  avatar: Icon(_modeIcon(mode), size: 18),
                  label: Text(_modeLabel(mode)),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _selected = mode);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Description
            Text(
              _modeDescription(_selected),
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Card counts
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.dueCount > 0) ...[
                    Icon(Icons.schedule, size: 16, color: cs.primary),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.dueCount} due',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (widget.newCount > 0) ...[
                    Icon(Icons.fiber_new, size: 16, color: cs.tertiary),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.newCount} new',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.tertiary,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Text(
                    '$total total',
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Start button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: () async {
                  // Persist the chosen mode.
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setInt(
                      kStudyModePrefKey, _selected.index);
                  if (context.mounted) {
                    Navigator.pop(context, _selected);
                  }
                },
                icon: const Icon(Icons.play_arrow),
                label: Text(total > 0
                    ? 'Start Review ($total cards)'
                    : 'No cards available'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _modeIcon(StudyMode mode) {
    switch (mode) {
      case StudyMode.flip:
        return Icons.flip;
      case StudyMode.typing:
        return Icons.keyboard;
      case StudyMode.reverse:
        return Icons.swap_vert;
      case StudyMode.cloze:
        return Icons.text_fields;
    }
  }

  String _modeLabel(StudyMode mode) {
    switch (mode) {
      case StudyMode.flip:
        return 'Flip';
      case StudyMode.typing:
        return 'Type';
      case StudyMode.reverse:
        return 'Reverse';
      case StudyMode.cloze:
        return 'Cloze';
    }
  }

  String _modeDescription(StudyMode mode) {
    switch (mode) {
      case StudyMode.flip:
        return 'Show the word, then flip to reveal the translation.';
      case StudyMode.typing:
        return 'Show the word, type the translation before revealing.';
      case StudyMode.reverse:
        return 'Show the translation, recall the original word.';
      case StudyMode.cloze:
        return 'Fill in the missing word in an example sentence.';
    }
  }
}
