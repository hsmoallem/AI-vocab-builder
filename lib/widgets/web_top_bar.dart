import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/word_provider.dart';
import '../screens/login_screen.dart';
import '../screens/settings_screen.dart';
import '../services/firebase_service.dart';
import '../config/app_strings.dart';
import '../widgets/add_word_dialog.dart';
import '../screens/bulk_import_screen.dart';
import '../screens/flashcard_screen.dart';
import '../screens/review_session_screen.dart';
import '../screens/study_mode_selector.dart';
import '../models/study_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/study_prefs.dart';
import '../screens/login_screen.dart';
import '../screens/web/web_archived_words_screen.dart';

class WebTopBar {
  static List<Widget> buildActions(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final s = AppStrings.of(context);
    final wordProvider = context.watch<WordProvider>();

    return [
      // Streak Flame
      Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              const Icon(Icons.local_fire_department, color: Colors.orange),
              const SizedBox(width: 4),
              Text(
                '${wordProvider.streak.current}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(width: 8),
      FilledButton.tonalIcon(
        icon: Badge.count(
          count: wordProvider.dueCount,
          isLabelVisible: wordProvider.dueCount > 0,
          child: const Icon(Icons.style_outlined),
        ),
        label: Text(s.flashcards),
        onPressed: () => _startReview(context),
      ),
      const SizedBox(width: 8),
      OutlinedButton.icon(
        icon: const Icon(Icons.playlist_add),
        label: const Text('Bulk Import'),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
        ),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BulkImportScreen()),
        ),
      ),
      const SizedBox(width: 8),
      OutlinedButton.icon(
        icon: const Icon(Icons.archive),
        label: const Text('Archived'),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WebArchivedWordsScreen()),
          );
        },
      ),
      const SizedBox(width: 8),
      FilledButton.icon(
        icon: const Icon(Icons.add),
        label: Text(s.addWord),
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        onPressed: () => _showAddWordDialog(context),
      ),
      const SizedBox(width: 16),
      if (auth.isSignedIn)
        PopupMenuButton<String>(
          tooltip: s.account,
          icon: auth.isAnonymous
              ? CircleAvatar(
                  radius: 16,
                  backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                  child: Icon(Icons.person_off, size: 18, color: Theme.of(context).colorScheme.onSecondaryContainer),
                )
              : CircleAvatar(
                  radius: 16,
                  backgroundImage: auth.photoUrl != null ? NetworkImage(auth.photoUrl!) : null,
                  child: auth.photoUrl == null
                      ? Text((auth.displayName ?? auth.email ?? '?')[0].toUpperCase(), style: const TextStyle(fontSize: 14))
                      : null,
                ),
          onSelected: (value) async {
            if (value == 'settings') {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            } else if (value == 'backup') {
              await _backupNow(context);
            } else if (value == 'restore') {
              await _restoreFromCloud(context);
            } else if (value == 'signout') {
              await context.read<AuthProvider>().signOut();
              if (context.mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              }
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              enabled: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (auth.isAnonymous) ...[
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 18, color: Theme.of(context).colorScheme.secondary),
                        const SizedBox(width: 6),
                        Text(s.anonymousUser, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(s.cloudBackupNotAvailable, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ] else ...[
                    Text(auth.displayName ?? 'Signed in', style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (auth.email != null) Text(auth.email!, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'settings',
              child: ListTile(
                leading: const Icon(Icons.settings),
                title: Text(s.settings),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              enabled: !auth.isAnonymous,
              value: 'backup',
              child: Opacity(
                opacity: auth.isAnonymous ? 0.4 : 1.0,
                child: ListTile(
                  leading: const Icon(Icons.cloud_upload_outlined),
                  title: Text(s.backupNow),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            PopupMenuItem(
              enabled: !auth.isAnonymous,
              value: 'restore',
              child: Opacity(
                opacity: auth.isAnonymous ? 0.4 : 1.0,
                child: ListTile(
                  leading: const Icon(Icons.cloud_download_outlined),
                  title: Text(s.restoreFromCloud),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'signout',
              child: ListTile(
                leading: const Icon(Icons.logout),
                title: Text(s.signOut),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      const SizedBox(width: 16),
    ];
  }

  static Future<void> _backupNow(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    if (auth.isAnonymous) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cloud backup not available for anonymous accounts. Sign in first.')));
      return;
    }
    try {
      final words = context.read<WordProvider>().words;
      await FirebaseService.instance.backupWords(words);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backed up ${words.length} words to cloud'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  static Future<void> _restoreFromCloud(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    if (auth.isAnonymous) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cloud restore not available for anonymous accounts. Sign in first.')));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore from cloud?'),
        content: const Text('This will merge cloud words with your local words. Duplicate words (same word text) will be skipped.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final cloudWords = await FirebaseService.instance.restoreWords();
      if (cloudWords.isEmpty) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No words found in cloud backup')));
        return;
      }
      final provider = context.read<WordProvider>();
      final existingWords = provider.words.map((w) => w.word.toLowerCase()).toSet();
      int added = 0;
      for (final word in cloudWords) {
        if (!existingWords.contains(word.word.toLowerCase())) {
          await provider.addWordObject(word);
          added++;
        }
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restored $added new words (${cloudWords.length - added} duplicates skipped)'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restore failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  static void _showAddWordDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const AddWordDialog());
  }

  static Future<void> _startReview(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: Theme.of(ctx).colorScheme.onSurfaceVariant.withAlpha(80), borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              Text('Flashcards', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.school),
                title: const Text('Study Mode'),
                subtitle: const Text('Spaced repetition with SRS — due + new cards'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: Theme.of(ctx).colorScheme.primaryContainer.withAlpha(80),
                onTap: () => Navigator.pop(ctx, 'study'),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.flip),
                title: const Text('View Flashcards'),
                subtitle: const Text('Browse all cards — flip, edit notes, grammar tips'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: Theme.of(ctx).colorScheme.surfaceContainerLow,
                onTap: () => Navigator.pop(ctx, 'view'),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !context.mounted) return;

    if (choice == 'view') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const FlashcardScreen()));
      return;
    }

    final provider = context.read<WordProvider>();
    await provider.refreshSrs();
    if (!context.mounted) return;
    if (provider.dueCount == 0 && provider.newCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🎉 All caught up — no cards due. Browsing all cards.')));
      Navigator.push(context, MaterialPageRoute(builder: (_) => const FlashcardScreen()));
      return;
    }
    final mode = await showStudyModeSelector(context: context, dueCount: provider.dueCount, newCount: provider.newCount);
    if (mode == null || !context.mounted) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kStudyModePrefKey, mode.index);
    final maxNew = await StudyPrefs.newCardsPerSession();
    final deck = await provider.buildSessionDeck(maxCards: maxNew);
    if (!context.mounted) return;
    if (deck.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nothing to review right now.')));
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => ReviewSessionScreen(mode: mode, deck: deck)));
  }
}
