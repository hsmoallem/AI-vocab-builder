/// ─── Vocab Builder App — Entry Point ───────────────────────────────
///
/// Initializes Firebase, sets up Provider tree (Locale + Auth + Words),
/// and shows LoginScreen or HomeScreen based on auth state.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/word_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/firebase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firebaseReady = await FirebaseService.instance.init();
  if (!firebaseReady) {
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
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        if (firebaseReady)
          ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => WordProvider()),
      ],
      child: MaterialApp(
        title: 'AI Vocab Builder',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        // Clamp text scaling so a large device font/display size can't blow
        // labels out of their buttons across the app.
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(
                textScaler: mq.textScaler.clamp(maxScaleFactor: 1.3)),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const AuthGate(),
      ),
    );
  }
}

/// AuthGate watches auth state and shows the appropriate screen.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
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
