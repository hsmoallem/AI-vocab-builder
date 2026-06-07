import 'package:flutter/material.dart';
import 'word_list_screen.dart';
import 'pdf_reader_screen.dart';
import 'flashcard_screen.dart';
import '../widgets/add_word_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final _screens = const [
    PdfReaderScreen(),
    WordListScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vocab Builder'),
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
        ],
      ),
      body: _screens[_currentIndex],
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
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'My Words',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddWordDialog(context),
        tooltip: 'Add Word',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddWordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const AddWordDialog(),
    );
  }
}
