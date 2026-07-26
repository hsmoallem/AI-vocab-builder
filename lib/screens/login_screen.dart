/// ─── Login Screen ────────────────────────────────────────────────────
///
/// Two options: Continue with Google (signs up or signs in automatically)
/// or Anonymous (no credentials).
/// Anonymous users see a warning dialog first.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../services/firebase_service.dart';
import '../config/app_strings.dart';
import 'home_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    size: 56,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'AI Vocab Builder',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Read PDFs. Learn words. Never forget.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    if (auth.isLoading) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      );
                    }

                    return Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: () => _handleGoogleSignIn(context),
                            icon: const Icon(Icons.login),
                            label: Text(
                              AppStrings.of(context).signInWithGoogle,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.brightness == Brightness.dark
                                  ? Colors.white
                                  : Colors.black,
                              foregroundColor: theme.brightness == Brightness.dark
                                  ? Colors.black
                                  : Colors.white,
                            ),
                            onPressed: () => _handleAppleSignIn(context),
                            icon: const Icon(Icons.apple, size: 24),
                            label: Text(
                              AppStrings.of(context).signInWithApple,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'or',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: TextButton.icon(
                            onPressed: () => _handleAnonymousSignIn(context),
                            icon: const Icon(Icons.person_outline, size: 20),
                            label: const Text('Continue without account'),
                          ),
                        ),
                        if (auth.error != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline,
                                    color: theme.colorScheme.onErrorContainer,
                                    size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    auth.error!,
                                    style: TextStyle(
                                      color: theme.colorScheme.onErrorContainer,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleGoogleSignIn(BuildContext context) async {
    if (!FirebaseService.instance.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).googleNotAvailable)),
      );
      return;
    }
    final auth = context.read<AuthProvider>();
    final success = await auth.signInWithGoogle();
    if (success && context.mounted) _goToHome(context);
  }

  Future<void> _handleAppleSignIn(BuildContext context) async {
    if (!FirebaseService.instance.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).appleNotAvailable)),
      );
      return;
    }
    final auth = context.read<AuthProvider>();
    final success = await auth.signInWithApple();
    if (success && context.mounted) _goToHome(context);
  }

  Future<void> _handleAnonymousSignIn(BuildContext context) async {
    // If Firebase not available, skip auth entirely and go to HomeScreen.
    if (!FirebaseService.instance.isInitialized) {
      if (context.mounted) _goToHome(context);
      return;
    }

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.of(ctx).anonymousWarningTitle),
        content: Text(AppStrings.of(ctx).anonymousWarningBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.of(ctx).goBack),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.of(ctx).continueAnyway),
          ),
        ],
      ),
    );

    if (proceed != true || !context.mounted) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.signInAnonymously();
    if (success && context.mounted) _goToHome(context);
  }

  void _goToHome(BuildContext context) {
    context.go('/');
  }
}
