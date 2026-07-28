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
      appBar: AppBar(title: const Text('User guide & features')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: const [
          _Guide(
            icon: Icons.school_outlined,
            title: 'AI Language Tutor & Grammar Enrichment',
            body:
                'Whenever you add a word or enhance an existing card, the AI acts as your personal experienced language teacher by automatically identifying language-specific grammatical attributes:\n\n'
                '• German & Language Rules: For German nouns, it accurately determines definite articles (der, die, das), plural forms, and feminine/masculine variations (e.g., Lehrer → Lehrerin). For verbs, it extracts infinitives, auxiliary verbs, verb types (weak/strong), simple past, and past participles!\n'
                '• Grammar Badges: Easily scan part of speech tags, IPA phonetic pronunciations, and smart trait badges such as "Irregular", "Reflexive", or "Separable".\n'
                '• Interactive Tutor Console: Tap the graduation cap Tutor icon on any flashcard or table row to open the comprehensive AI Language Tutor Console—complete with pedagogical Teacher Tips, common usage pitfalls, and conversational syntax guidance!',
          ),
          _Guide(
            icon: Icons.access_time_filled_outlined,
            title: 'Spaced Repetition Review (SRS)',
            body:
                'Tap Flashcards Review from the menu to choose between two main study modes:\n\n'
                '• Study Mode (SRS) — uses a smart spaced-repetition algorithm (SM-2). You only review cards that are currently DUE plus a configured batch of NEW words (e.g., "5 due, 20 new"). When you reveal a card, rate how effortlessly you recalled it. Easy cards are scheduled weeks or months ahead, while forgotten items return within minutes to reinforce learning!\n'
                '• Review All Flashcards — browse freely through your entire vocabulary library at your own pace without modifying your scheduled SRS progress.',
          ),
          _Guide(
            icon: Icons.touch_app_outlined,
            title: 'Rating Buttons & Automatic Advancing',
            body:
                'When reviewing in Study Mode, rating a card determines its future schedule:\n\n'
                '• Again — you forgot the word. It re-enters the immediate learning phase.\n'
                '• Hard — recalled with difficulty. Short interval increase (e.g. 1.2x).\n'
                '• Good — correct recall. Standard interval progression.\n'
                '• Easy — effortless recall. Maximum spacing leap (e.g. 1.3x bonus).\n\n'
                '⚡ Automatic Advancing: Tapping any rating button instantly saves your progress and advances directly to the next flashcard—no extra tap required!',
          ),
          _Guide(
            icon: Icons.style_outlined,
            title: 'Interactive Study Modes',
            body:
                '• Flip Mode — see the prompt word, then tap anywhere on the card (or click "Show answer") to reveal translations, grammatical breakdowns, AI teacher tips, and example sentences.\n'
                '• Typing Mode — type out the correct translation to test active recall; your answer is evaluated instantly. If a word has multiple valid meanings or translations, any matching meaning is accepted!\n'
                '• Reverse Mode — see the target translation first and challenge yourself to recall the original vocabulary vocabulary item and its grammar.',
          ),
          _Guide(
            icon: Icons.list_alt,
            title: 'My Words, Web Dashboard & Archiving',
            body:
                'Manage your vocabulary library across devices with robust search, filtering, and bulk operations:\n\n'
                '• Web Dashboard (Desktop): Features a responsive, space-optimized data table that eliminates wasteful white space between Word, Translation, and Example columns. Quick action buttons allow you to open the AI Tutor Console, regenerate examples, archive cards, export CSVs, or clear duplicates right from the top toolbars.\n'
                '• Android/Mobile Version: Tap any item in the list to view all sentence examples, hear native TTS pronunciations, and manage card states.\n'
                '• Data Exports: Export your deck anytime into CSV (Excel/Sheets), TSV (clipboard paste), or plain text. Exports natively include all grammatical enrichment metadata (Part of Speech, IPA, Articles, Plurals, Verb types, Teacher Rules, and Usage Notes).\n'
                '• Archiving: Archiving removes a word from daily SRS reviews while preserving your study streak and history. Manage or restore archived cards anytime in the Archived Words screen.',
          ),
          _Guide(
            icon: Icons.local_fire_department,
            title: 'Study Streak Tracker & Automatic Freeze',
            body:
                'Keep your learning momentum alive by completing at least one vocabulary study session daily! Active streaks and historical personal bests are tracked on your main dashboard and session summary reports.\n\n'
                '❄️ Automatic Streak Freeze: Life gets busy! If you miss a single study day, an automatic Streak Freeze is triggered—displayed as an Ice Blue circle with a snowflake icon on your interactive streak calendar. Your accumulated streak count is completely protected from resetting, allowing you to resume seamlessly the next day!',
          ),
          _Guide(
            icon: Icons.add_circle_outline,
            title: 'Adding Words & Bulk Import',
            body:
                'Click "+ Add Word" to open a centered, streamlined popup where AI automatically translates words, enriches grammatical attributes, assigns CEFR difficulty levels, and writes dual-language sentence examples.\n\n'
                'Have a long list of vocabulary? Use Bulk Import to paste word lists or paragraphs and generate dozens of enriched vocabulary flashcards simultaneously!',
          ),
          _Guide(
            icon: Icons.picture_as_pdf_outlined,
            title: 'Interactive PDF Reader',
            body:
                'Open any foreign language PDF document directly inside the app! Tap or click any unfamiliar word or highlight phrases while reading to see instant definitions, listen to audio speech, and save enriched cards straight into your deck.',
          ),
          _Guide(
            icon: Icons.auto_stories_outlined,
            title: 'Story Mode & Daily Phrases',
            body:
                '• Story Mode: Immerse yourself in context! AI writes engaging short stories incorporating words currently due in your learning schedule, or custom vocabulary you select manually. Click any word in a story for instant lookup or use TTS audio playback to hear the full narration.\n'
                '• Daily Phrases: Discover curated daily expressions generated specifically for your target language and CEFR level.',
          ),
          _Guide(
            icon: Icons.record_voice_over_outlined,
            title: 'Text-to-Audio Converter',
            body:
                'Paste or type any custom text to convert it into spoken audio using natural synthesizer voices. Adjust speed to train your listening comprehension and download or share speech recordings.',
          ),
          _Guide(
            icon: Icons.cloud_upload_outlined,
            title: 'Cloud Backup & Cross-Device Sync',
            body:
                'Sign in with your Google Account to automatically synchronize your vocabulary decks, study streaks, custom notes, AI grammar enrichments, and app settings across both Android and Web platforms! Enable daily or weekly automated syncs in Settings or manually trigger instant cloud backups anytime.',
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
