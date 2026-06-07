import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'providers/word_provider.dart';
import 'services/database_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize sqflite database
  await DatabaseService.instance.init();

  runApp(const VocabBuilderApp());
}

class VocabBuilderApp extends StatelessWidget {
  const VocabBuilderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => WordProvider()..loadWords(),
      child: MaterialApp(
        title: 'Vocab Builder',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
      ),
    );
  }
}
