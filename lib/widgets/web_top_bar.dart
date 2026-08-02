import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/word_provider.dart';
import '../providers/locale_provider.dart';
import '../services/firebase_service.dart';
import '../config/app_strings.dart';
import '../widgets/add_word_dialog.dart';

class WebTopBar {
  static List<Widget> buildActions(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final s = AppStrings.of(context);

    return [
      OutlinedButton.icon(
        icon: const Icon(Icons.playlist_add),
        label: const Text('Bulk Import'),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
        ),
        onPressed: () => context.push('/import'),
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
      final provider = context.read<WordProvider>();
      final words = await provider.getAllWordsForBackup();
      final syncCount = await FirebaseService.instance.backupWords(words);
      try {
        await FirebaseService.instance.backupSettings();
        await FirebaseService.instance.updateStreak(provider.streak);
      } catch (e) {
        debugPrint('Non-fatal error backing up secondary data: $e');
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backed up $syncCount words, streak, and settings to cloud'), backgroundColor: Colors.green));
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
      try {
        await provider.syncCloudStreak();
        await FirebaseService.instance.restoreSettings();
        if (context.mounted) {
          await context.read<LocaleProvider>().load();
        }
      } catch (e) {
        debugPrint('Non-fatal error restoring secondary data: $e');
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restored $addedOrUpdated words from cloud backup.'), backgroundColor: Colors.green));
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
}
