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
import 'services/db_bootstrap.dart';
import 'config/router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Select the SQLite backend for this platform (web → WASM/IndexedDB).
  // Must run before any database access.
  configureDatabaseFactory();

  final firebaseReady = await FirebaseService.instance.init();
  if (!firebaseReady) {
    debugPrint('⚠ Firebase not initialized — running in local-only mode');
  }

  runApp(const VocabBuilderApp());
}

class VocabBuilderApp extends StatelessWidget {
  const VocabBuilderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        // Always provided — AuthProvider self-guards when Firebase isn't
        // initialized (local-only mode), so consumers always find it.
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => WordProvider()),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, localeProvider, _) {
          return MaterialApp.router(
            title: 'AI Vocab Builder',
            debugShowCheckedModeBanner: false,
            // Force the locale on the app so built-in widgets can potentially translate
            // (if localizations delegates are added later), but more importantly,
            // this Consumer forces a full rebuild of the widget tree when locale changes.
            locale: Locale(localeProvider.locale),
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
            routerConfig: appRouter,
          );
        },
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
      // Local-only mode (e.g. web without a Firebase config): skip the login
      // gate entirely — the app works with the local DB and no cloud backup.
      return const HomeScreen();
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
