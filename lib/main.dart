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

  // Initialize Firebase.
  // If google-services.json is missing → run in local-only mode
  // (login screen still shows — Google sign-in just won't work).
  final firebaseReady = await FirebaseService.instance.init();
  if (!firebaseReady) {
    // Firebase not available — app runs without auth/cloud features.
    debugPrint('⚠ Firebase not initialized — running in local-only mode');
  }

  runApp(VocabBuilderApp(firebaseReady: firebaseReady));
}

class VocabBuilderApp extends StatelessWidget {
  final bool firebaseReady;

  const VocabBuilderApp({super.key, required this.firebaseReady});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Only create AuthProvider if Firebase is available.
        if (firebaseReady)
          ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => WordProvider()..loadWords()),
      ],
      child: MaterialApp(
        title: 'AI Vocab Builder',
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
    // If Firebase isn't available, skip auth and go straight to LoginScreen.
    // The user can still use "Continue without account" — just no Google sign-in.
    final firebaseReady = FirebaseService.instance.isInitialized;
    if (!firebaseReady) {
      return const LoginScreen();
    }

    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (auth.isSignedIn) {
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
