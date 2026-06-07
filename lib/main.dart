/// ─── Vocab Builder App — Entry Point ───────────────────────────────
///
/// Initializes Firebase, sets up Provider tree (Auth + Words),
/// and shows LoginScreen or HomeScreen based on auth state.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/word_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/firebase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (must happen before runApp).
  // If google-services.json is missing or invalid, this will throw —
  // the error screen shown below catches it gracefully.
  try {
    await FirebaseService.instance.init();
  } catch (e) {
    // Firebase init failed — likely missing google-services.json.
    // Run without Firebase (local-only mode).
    debugPrint('Firebase init failed: $e');
  }

  runApp(const VocabBuilderApp());
}

class VocabBuilderApp extends StatelessWidget {
  const VocabBuilderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => WordProvider()..loadWords()),
      ],
      child: MaterialApp(
        title: 'Vocab Builder',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const AuthGate(),
      ),
    );
  }
}

/// AuthGate watches auth state and shows the appropriate screen.
///
/// - Loading → splash/spinner
/// - Signed out → LoginScreen
/// - Signed in → HomeScreen
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        // Show loading spinner while Firebase checks auth state
        if (auth.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Signed in → main app
        if (auth.isSignedIn) {
          return const HomeScreen();
        }

        // Not signed in → login screen
        return const LoginScreen();
      },
    );
  }
}
