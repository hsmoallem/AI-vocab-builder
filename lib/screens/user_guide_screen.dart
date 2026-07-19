/// ─── User Guide ─────────────────────────────────────────────────────
///
/// A plain-language help screen explaining the app: flashcards, spaced
/// repetition, the rating buttons, study modes, and the main features.

import 'package:flutter/material.dart';

class UserGuideScreen extends StatelessWidget {
  const UserGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User guide')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: const [
          _Guide(
            icon: Icons.school_outlined,
            title: 'How review (spaced repetition) works',
            body:
                'Tap the flashcards icon to start a review. You only see cards '
                'that are DUE plus a batch of NEW cards — not your whole list at '
                'once. After you reveal a card, you rate how well you knew it, and '
                'the app schedules when to show it again. Easy cards come back in '
                'weeks; forgotten cards come back soon. That spacing is what makes '
                'words stick.',
          ),
          _Guide(
            icon: Icons.touch_app_outlined,
            title: 'The rating buttons',
            body:
                '• Again — you forgot it. It comes back in this same session.\n'
                '• Hard — you knew it but struggled. Short interval.\n'
                '• Good — you knew it. Standard spacing (1 day → 6 days → longer).\n'
                '• Easy — instant recall. A bigger jump than Good.\n\n'
                'The small hint on each button (e.g. 1d, 6d, 2mo) shows when that '
                'choice will bring the card back.',
          ),
          _Guide(
            icon: Icons.style_outlined,
            title: 'Study modes',
            body:
                '• Flip — see the word, flip to recall the translation.\n'
                '• Typing — type the translation; it is checked. A hint shows '
                'which language to answer in (the one the word is translated '
                'to). If a card has more than one translation, any is accepted.\n'
                '• Reverse — see the translation, recall the word.\n\n'
                'Pick a mode when you start a session.',
          ),
          _Guide(
            icon: Icons.credit_card,
            title: 'On each card',
            body:
                'Reveal the answer to see the translation, example sentences, an '
                'AI grammar tip, your note, and a "translate to another language" '
                'tool. Every field has a 🔊 listen button and a copy icon, and you '
                'can regenerate the example or copy the whole card.',
          ),
          _Guide(
            icon: Icons.add_circle_outline,
            title: 'Adding words',
            body:
                'Add a single word with the + button, or use Bulk Import to paste '
                'a whole list and translate them all at once. Words are also saved '
                'from the PDF reader (tap a word) and from Daily Phrases.',
          ),
          _Guide(
            icon: Icons.list_alt,
            title: 'Saved Words',
            body:
                'Your full list. Search and sort, copy or regenerate examples, '
                'remove duplicates, and Export (⋮ menu) to CSV / text — filtered '
                'by date range or last-N if you like. "Save to Drive" opens the '
                'CSV as a Google Sheet.',
          ),
          _Guide(
            icon: Icons.school_outlined,
            title: 'CEFR levels',
            body:
                'Each word can show its CEFR level (A1–C2) — how advanced a '
                'learner needs to be to know it. To fill them in, open Saved '
                'Words → ⋮ → "Classify CEFR levels"; the AI grades every word '
                'that doesn\'t have a level yet. The colored badge then appears '
                'on the word and on its review card. Run it again after adding '
                'new words.',
          ),
          _Guide(
            icon: Icons.archive_outlined,
            title: 'Archiving',
            body:
                'Archive a card (top-right on a review card) to hide it from your '
                'list and reviews. Find archived words under Saved Words → ⋮ → '
                'Archived words, where you can restore or delete them.',
          ),
          _Guide(
            icon: Icons.cloud_upload_outlined,
            title: 'Backup',
            body:
                'Sign in with Google to back up to the cloud. Turn on Automatic '
                'backup in Settings (Daily / Weekly) to have it happen for you, or '
                'back up manually from the account menu.',
            last: true,
          ),
        ],
      ),
    );
  }
}

class _Guide extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final bool last;
  const _Guide({
    required this.icon,
    required this.title,
    required this.body,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(body,
              style: TextStyle(
                  fontSize: 14, height: 1.4, color: cs.onSurfaceVariant)),
          if (!last) const Divider(height: 28),
        ],
      ),
    );
  }
}
