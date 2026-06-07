/// ─── Vocab Builder App — Entry Point ───────────────────────────────
///
/// This is the main entry point for the Vocab Builder Android app.
/// It initializes the Provider state management tree and launches the
/// Material 3 themed app with light/dark mode support.
///
/// ## Architecture decisions
///
/// **Provider** (not Riverpod, not BLoC):
///   Chosen for simplicity — this is a single-user, local-first app
///   with one primary data source. Provider's ChangeNotifier pattern
///   is the Flutter team's recommended approach for apps of this
///   complexity. No code generation needed.
///
/// **Database init is implicit:**
///   The DatabaseService uses a lazy singleton pattern — the database
///   file is created on first access, not at startup. This avoids
///   blocking the UI thread during app launch.
///
/// ## Issue: Isar → sqflite migration
///   The app originally used Isar for local storage. Isar 3.1.0 is
///   unmaintained and its generated code (.g.dart files) is incompatible
///   with Android Gradle Plugin 9.x. We replaced it with sqflite, a
///   mature SQLite plugin that requires zero code generation and works
///   with any AGP version.
///
/// ## Loading state
///   If DB init must be explicit in the future, uncomment:
///   `await DatabaseService.instance.init();`

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'providers/word_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  // Ensure Flutter bindings are ready before any async work.
  // Required because we may access platform channels or plugins.
  WidgetsFlutterBinding.ensureInitialized();

  // Database auto-initializes on first access — no explicit init needed.
  // The lazy singleton in DatabaseService creates the DB file when
  // getWords() or insertWord() is first called.

  runApp(const VocabBuilderApp());
}

/// Root widget — sets up Provider and Material theme.
class VocabBuilderApp extends StatelessWidget {
  const VocabBuilderApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Provider is created here so it lives for the entire app lifecycle.
    // loadWords() is called immediately to populate the word list on launch.
    return ChangeNotifierProvider(
      create: (_) => WordProvider()..loadWords(),
      child: MaterialApp(
        title: 'Vocab Builder',
        // Disable the red debug banner in the top-right corner.
        debugShowCheckedModeBanner: false,
        // Material 3 with dynamic color from seed.
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        // Follow the device's theme setting (light/dark).
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
      ),
    );
  }
}
