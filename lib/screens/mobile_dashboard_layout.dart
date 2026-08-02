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
import 'package:go_router/go_router.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import '../widgets/add_word_dialog.dart';
import 'bulk_import_screen.dart';
import 'text_to_audio_screen.dart';
import 'ai_quiz_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/word_provider.dart';
import '../providers/locale_provider.dart';
import '../services/firebase_service.dart';
import '../services/study_prefs.dart';
import '../config/app_strings.dart';
import 'streak_screen.dart';
import '../services/analytics_service.dart';


class MobileDashboardLayout extends StatefulWidget {
  const MobileDashboardLayout({super.key});

  @override
  State<MobileDashboardLayout> createState() => _MobileDashboardLayoutState();
}

class _MobileDashboardLayoutState extends State<MobileDashboardLayout> {
  int _currentIndex = 0;
  bool _isBackingUp = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AnalyticsService.trackView('/mobile/home', 'Mobile App Start');
      AnalyticsService.trackEvent('mobile_app_open');
    });
  }

  void _onTabSelect(int index) {
    setState(() => _currentIndex = index);
    final tabName = index == 0 ? 'Reader' : (index == 1 ? 'Daily AI' : 'My Words');
    AnalyticsService.trackView('/mobile/${tabName.toLowerCase().replaceAll(' ', '_')}', 'Mobile $tabName');
    AnalyticsService.trackEvent('mobile_navigation', {'tab': tabName});
  }

  // The PDF reader relies on Android-native plugins, so it's omitted on web.
  // kIsWeb is a compile-time constant, so this stays a const list.
  List<Widget> get _screens => const [
        if (!kIsWeb) PdfReaderScreen(),
        DailyPhrasesScreen(),
        WordListScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final s = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.appName),
        actions: [
          // Streak Flame (hidden for anonymous users)
          if (!auth.isAnonymous)
            Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => StreakScreen.show(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
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
            ),
          // Settings gear — always visible
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: s.settings,
            onPressed: () => context.push('/settings'),
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
            onPressed: () => context.push('/audio'),
          ),
          IconButton(
            icon: const Icon(Icons.auto_stories),
            tooltip: 'Story Mode',
            onPressed: () => context.push('/quiz'),
          ),
          IconButton(
            icon: const Icon(Icons.playlist_add),
            tooltip: 'Bulk import',
            onPressed: () => context.push('/import'),
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
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabSelect,
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

  /// Opens a bottom sheet asking if the user wants Spaced Repetition Study or just viewing cards.
  void _startReview(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.school, size: 28),
                  title: const Text('Study Mode', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Spaced repetition with SRS — due + new cards'),
                  onTap: () async {
                    Navigator.pop(bottomSheetContext);
                    final provider = context.read<WordProvider>();
                    await provider.refreshSrs();
                    if (!context.mounted) return;
                    if (provider.dueCount == 0 && provider.newCount == 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('🎉 All caught up — no cards due. Browsing all cards.')),
                      );
                      context.push('/flashcards');
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
                    context.push(
                      '/review',
                      extra: {'mode': mode, 'deck': deck},
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.flip, size: 28),
                  title: const Text('View Flashcards', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Browse all cards — flip, edit notes, grammar tips'),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    context.push('/flashcards');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleMenuAction(String value, BuildContext context) async {
    switch (value) {
      case 'settings':
        context.push('/settings');
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
          context.go('/login');
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
      final provider = context.read<WordProvider>();
      final words = await provider.getAllWordsForBackup();
      final syncCount = await FirebaseService.instance.backupWords(words);
      try {
        await FirebaseService.instance.backupSettings();
        await FirebaseService.instance.updateStreak(provider.streak);
      } catch (e) {
        debugPrint('Non-fatal error backing up secondary data: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backed up $syncCount words, streak, and settings to cloud'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to complete cloud backup. Please check your network connection and try again.'),
            backgroundColor: Colors.red,
          ),
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
          'This will restore words and sync your study streak from the cloud. '
          'Existing words will be updated with your latest study progress.',
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
      final provider = context.read<WordProvider>();
      
      int addedOrUpdated = 0;
      if (cloudWords.isNotEmpty) {
        addedOrUpdated = await provider.syncRestoredWords(cloudWords);
      }
      try {
        await provider.syncCloudStreak();
        await FirebaseService.instance.restoreSettings();
        if (mounted) {
          await context.read<LocaleProvider>().load();
        }
      } catch (e) {
        debugPrint('Non-fatal error restoring secondary data: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restored $addedOrUpdated words from cloud backup.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to restore from cloud. Please check your network connection and try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

