import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'word_list_screen.dart';
import 'pdf_reader_screen.dart';
import 'flashcard_screen.dart';
import 'daily_phrases_screen.dart';
import 'login_screen.dart';
import '../widgets/add_word_dialog.dart';
import '../providers/auth_provider.dart';
import '../providers/word_provider.dart';
import '../services/firebase_service.dart';

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
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Vocab Builder'),
        actions: [
          IconButton(
            icon: const Icon(Icons.style_outlined),
            tooltip: 'Flashcards',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FlashcardScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Word',
            onPressed: () => _showAddWordDialog(context),
          ),
          // User menu — shows when signed in
          if (auth.isSignedIn)
            PopupMenuButton<String>(
              tooltip: 'Account',
              icon: auth.isAnonymous
                  ? CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.orange.shade100,
                      child: const Icon(Icons.person_off, size: 18, color: Colors.orange),
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
                                size: 18, color: Colors.orange.shade700),
                            const SizedBox(width: 6),
                            Text(
                              'Anonymous user',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cloud backup not available',
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
                  enabled: !auth.isAnonymous,
                  value: 'backup',
                  child: Opacity(
                    opacity: auth.isAnonymous ? 0.4 : 1.0,
                    child: const ListTile(
                      leading: Icon(Icons.cloud_upload_outlined),
                      title: Text('Backup now'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                PopupMenuItem(
                  enabled: !auth.isAnonymous,
                  value: 'restore',
                  child: Opacity(
                    opacity: auth.isAnonymous ? 0.4 : 1.0,
                    child: const ListTile(
                      leading: Icon(Icons.cloud_download_outlined),
                      title: Text('Restore from cloud'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'signout',
                  child: ListTile(
                    leading: Icon(Icons.logout),
                    title: Text('Sign out'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // Anonymous warning banner
          if (auth.isSignedIn && auth.isAnonymous) _buildAnonymousBanner(),
          // Main content
          Expanded(child: _screens[_currentIndex]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Reader',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'Daily',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'My Words',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 2
          ? FloatingActionButton(
              onPressed: () => _showAddWordDialog(context),
              tooltip: 'Add Word',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildAnonymousBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.orange.shade50,
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 20, color: Colors.orange.shade800),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Using anonymously — your words are only on this device. '
              'Sign in to back up to the cloud.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.orange.shade900,
              ),
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

  Future<void> _handleMenuAction(String value, BuildContext context) async {
    switch (value) {
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
        const SnackBar(
          content: Text('Cloud backup not available for anonymous accounts. Sign in first.'),
        ),
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
          SnackBar(
            content: Text('Backup failed: $e'),
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
        const SnackBar(
          content: Text('Cloud restore not available for anonymous accounts. Sign in first.'),
        ),
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
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
            content: Text(
              'Restored $added new words (${cloudWords.length - added} duplicates skipped)',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
