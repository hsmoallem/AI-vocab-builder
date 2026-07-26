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
import 'package:go_router/go_router.dart';
import '../services/study_prefs.dart';
import '../screens/login_screen.dart';
import '../screens/web/web_archived_words_screen.dart';

class WebTopBar {
  static List<Widget> buildActions(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final s = AppStrings.of(context);
    final wordProvider = context.watch<WordProvider>();

    return [
      MenuAnchor(
        builder: (BuildContext context, MenuController controller, Widget? child) {
          return FilledButton.tonalIcon(
            icon: Badge.count(
              count: wordProvider.dueCount,
              isLabelVisible: wordProvider.dueCount > 0,
              child: const Icon(Icons.style_outlined),
            ),
            label: Text(s.flashcards),
            onPressed: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
          );
        },
        menuChildren: [
          MenuItemButton(
            leadingIcon: const Icon(Icons.school, size: 22),
            onPressed: () => _handleFlashcardsChoice(context, 'study'),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Study Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  SizedBox(height: 2),
                  Text('Spaced repetition with SRS — due + new cards', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          MenuItemButton(
            leadingIcon: const Icon(Icons.flip, size: 22),
            onPressed: () => _handleFlashcardsChoice(context, 'view'),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('View Flashcards', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  SizedBox(height: 2),
                  Text('Browse all cards — flip, edit notes, grammar tips', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      ),
      const SizedBox(width: 8),
      OutlinedButton.icon(
        icon: const Icon(Icons.playlist_add),
        label: const Text('Bulk Import'),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
        ),
        onPressed: () => context.push('/import'),
      ),
      const SizedBox(width: 8),
      OutlinedButton.icon(
        icon: const Icon(Icons.archive),
        label: const Text('Archived'),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
        ),
        onPressed: () {
          context.push('/archived');
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
              context.push('/settings');
            } else if (value == 'backup') {
              await _backupNow(context);
            } else if (value == 'restore') {
              await _restoreFromCloud(context);
            } else if (value == 'signout') {
              await context.read<AuthProvider>().signOut();
              if (context.mounted) {
                context.go('/login');
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
      final words = await context.read<WordProvider>().getAllWordsForBackup();
      await FirebaseService.instance.backupWords(words);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backed up ${words.length} words to cloud'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to complete cloud backup. Please check your network connection and try again.'), backgroundColor: Colors.red));
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
        content: const Text('This will restore words and sync your study streak from the cloud. Existing words will be updated with your latest study progress.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final cloudWords = await FirebaseService.instance.restoreWords();
      final provider = context.read<WordProvider>();
      
      int addedOrUpdated = 0;
      if (cloudWords.isNotEmpty) {
        addedOrUpdated = await provider.syncRestoredWords(cloudWords);
      }
      await provider.syncCloudStreak();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully synced $addedOrUpdated vocabulary items and streak from cloud backup.'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to restore from cloud. Please check your network connection and try again.'), backgroundColor: Colors.red));
      }
    }
  }

  static void _showAddWordDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const AddWordDialog());
  }

  static Future<void> _handleFlashcardsChoice(BuildContext context, String choice) async {
    if (choice == 'view') {
      context.push('/flashcards');
      return;
    }

    final provider = context.read<WordProvider>();
    await provider.refreshSrs();
    if (!context.mounted) return;
    if (provider.dueCount == 0 && provider.newCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🎉 All caught up — no cards due. Browsing all cards.')));
      context.push('/flashcards');
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
    context.push('/review', extra: {'mode': mode, 'deck': deck});
  }
}
