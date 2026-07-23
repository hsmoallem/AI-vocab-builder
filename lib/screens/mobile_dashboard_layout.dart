import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'word_list_screen.dart';
import 'pdf_reader_screen.dart';
import 'flashcard_screen.dart';
import 'review_session_screen.dart';
import 'study_mode_selector.dart';
import 'daily_phrases_screen.dart';
import '../models/study_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import '../widgets/add_word_dialog.dart';
import 'bulk_import_screen.dart';
import 'text_to_audio_screen.dart';
import 'ai_quiz_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/word_provider.dart';
import '../services/firebase_service.dart';
import '../services/auto_backup.dart';
import '../services/study_prefs.dart';
import '../config/app_strings.dart';

class MobileDashboardLayout extends StatefulWidget {
  const MobileDashboardLayout({super.key});

  @override
  State<MobileDashboardLayout> createState() => _MobileDashboardLayoutState();
}

class _MobileDashboardLayoutState extends State<MobileDashboardLayout> {
  int _currentIndex = 0;
  bool _isBackingUp = false;

  // The PDF reader relies on Android-native plugins, so it's omitted on web.
  // kIsWeb is a compile-time constant, so this stays a const list.
  List<Widget> get _screens => const [
        if (!kIsWeb) PdfReaderScreen(),
        DailyPhrasesScreen(),
        WordListScreen(),
      ];

  @override
  void initState() {
    super.initState();
    // Run an automatic backup on launch if it's enabled + due (silent).
    // Delay so the word list has time to load first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        AutoBackup.maybeRun(context.read<WordProvider>().words);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final s = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.appName),
        actions: [
          // Streak Flame
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    '${context.watch<WordProvider>().streak.current}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          // Settings gear — always visible
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: s.settings,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          IconButton(
            icon: Badge.count(
              count: context.watch<WordProvider>().dueCount,
              isLabelVisible: context.watch<WordProvider>().dueCount > 0,
              child: const Icon(Icons.style_outlined),
            ),
            tooltip: s.flashcards,
            onPressed: () => _startReview(context),
          ),
          IconButton(
            icon: const Icon(Icons.record_voice_over),
            tooltip: 'Text-to-Audio',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TextToAudioScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.auto_stories),
            tooltip: 'AI Quizzes & Stories',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AiQuizScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.playlist_add),
            tooltip: 'Bulk import',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BulkImportScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: s.addWord,
            onPressed: () => _showAddWordDialog(context),
          ),
          // User menu — shows when signed in
          if (auth.isSignedIn)
            PopupMenuButton<String>(
              tooltip: s.account,
              icon: auth.isAnonymous
                  ? CircleAvatar(
                      radius: 16,
                      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                      child: Icon(Icons.person_off, size: 18,
                          color: Theme.of(context).colorScheme.onSecondaryContainer),
                    )
                  : CircleAvatar(
                      radius: 16,
                      backgroundImage: auth.photoUrl != null
                          ? NetworkImage(auth.photoUrl!)
                          : null,
                      child: auth.photoUrl == null
                          ? Text(
                              (auth.displayName ?? auth.email ?? '?')[0].toUpperCase(),
                              style: const TextStyle(fontSize: 14),
                            )
                          : null,
                    ),
              onSelected: (value) => _handleMenuAction(value, context),
              itemBuilder: (context) => [
                PopupMenuItem(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (auth.isAnonymous) ...[
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                size: 18,
                                color: Theme.of(context).colorScheme.secondary),
                            const SizedBox(width: 6),
                            Text(
                              s.anonymousUser,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s.cloudBackupNotAvailable,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ] else ...[
                        Text(
                          auth.displayName ?? 'Signed in',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (auth.email != null)
                          Text(
                            auth.email!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
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
        ],
      ),
      body: Column(
        children: [
          if (auth.isSignedIn && auth.isAnonymous) _buildAnonymousBanner(),
          Expanded(child: _screens[_currentIndex]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: [
          if (!kIsWeb)
            NavigationDestination(
              icon: const Icon(Icons.menu_book_outlined),
              selectedIcon: const Icon(Icons.menu_book),
              label: s.tabReader,
            ),
          NavigationDestination(
            icon: const Icon(Icons.auto_awesome_outlined),
            selectedIcon: const Icon(Icons.auto_awesome),
            label: s.tabDaily,
          ),
          NavigationDestination(
            icon: const Icon(Icons.list_alt_outlined),
            selectedIcon: const Icon(Icons.list_alt),
            label: s.tabMyWords,
          ),
        ],
      ),
      // Add-word FAB shows on the "My Words" tab (always the last tab).
      floatingActionButton: _currentIndex == _screens.length - 1
          ? FloatingActionButton(
              onPressed: () => _showAddWordDialog(context),
              tooltip: s.addWord,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildAnonymousBanner() {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: cs.secondaryContainer,
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 20, color: cs.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              s.anonymousBanner,
              style: TextStyle(fontSize: 13, color: cs.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddWordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const AddWordDialog(),
    );
  }

  /// Shows a bottom sheet: Study Mode or View Flashcards.
  Future<void> _startReview(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text('Flashcards',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.school),
                title: const Text('Study Mode'),
                subtitle: const Text('Spaced repetition with SRS — due + new cards'),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                tileColor:
                    Theme.of(ctx).colorScheme.primaryContainer.withAlpha(80),
                onTap: () => Navigator.pop(ctx, 'study'),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.flip),
                title: const Text('View Flashcards'),
                subtitle: const Text(
                    'Browse all cards — flip, edit notes, grammar tips'),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
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
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FlashcardScreen()),
      );
      return;
    }

    // Study Mode path
    final provider = context.read<WordProvider>();
    await provider.refreshSrs();
    if (!context.mounted) return;
    if (provider.dueCount == 0 && provider.newCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('🎉 All caught up — no cards due. Browsing all cards.')),
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FlashcardScreen()),
      );
      return;
    }
    final mode = await showStudyModeSelector(
      context: context,
      dueCount: provider.dueCount,
      newCount: provider.newCount,
    );
    if (mode == null || !context.mounted) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kStudyModePrefKey, mode.index);
    final maxNew = await StudyPrefs.newCardsPerSession();
    final deck = await provider.buildSessionDeck(maxCards: maxNew);
    if (!context.mounted) return;
    if (deck.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to review right now.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => ReviewSessionScreen(mode: mode, deck: deck)),
    );
  }

  Future<void> _handleMenuAction(String value, BuildContext context) async {
    switch (value) {
      case 'settings':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
        break;
      case 'backup':
        await _backupNow(context);
        break;
      case 'restore':
        await _restoreFromCloud(context);
        break;
      case 'signout':
        await context.read<AuthProvider>().signOut();
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
        break;
    }
  }

  Future<void> _backupNow(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    if (auth.isAnonymous) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cloud backup not available for anonymous accounts. Sign in first.')),
      );
      return;
    }

    setState(() => _isBackingUp = true);

    try {
      final words = context.read<WordProvider>().words;
      await FirebaseService.instance.backupWords(words);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backed up ${words.length} words to cloud'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isBackingUp = false);
    }
  }

  Future<void> _restoreFromCloud(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    if (auth.isAnonymous) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cloud restore not available for anonymous accounts. Sign in first.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore from cloud?'),
        content: const Text(
          'This will merge cloud words with your local words. '
          'Duplicate words (same word text) will be skipped.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore')),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final cloudWords = await FirebaseService.instance.restoreWords();
      if (cloudWords.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No words found in cloud backup')),
          );
        }
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restored $added new words (${cloudWords.length - added} duplicates skipped)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
