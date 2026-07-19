import 'package:flutter/material.dart';
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
import '../providers/auth_provider.dart';
import '../providers/word_provider.dart';
import '../services/firebase_service.dart';
import '../services/auto_backup.dart';
import '../services/study_prefs.dart';
import '../config/app_strings.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isBackingUp = false;

  final _screens = const [
    PdfReaderScreen(),
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
      floatingActionButton: _currentIndex == 2
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

  /// Start a spaced-repetition review session: pick a study mode, build the
  /// due+new deck, and open the session. If nothing is due, fall back to
  /// browsing all cards.
  Future<void> _startReview(BuildContext context) async {
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
    final deck = await provider.buildSessionDeck(maxNewCards: maxNew);
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
