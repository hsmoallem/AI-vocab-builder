/// ─── Login Screen ────────────────────────────────────────────────────
///
/// Entry point for authentication. Three paths:
/// 1. Google Sign-In (one tap)
/// 2. Email + Password (navigates to EmailLoginScreen)
/// 3. Anonymous (no credentials, warning shown first)
///
/// Also links to RegisterScreen for new email accounts.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'home_screen.dart';
import 'email_login_screen.dart';
import 'register_screen.dart';

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
                // ── App icon ────────────────────────────────────
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

                // ── App name ────────────────────────────────────
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
                const SizedBox(height: 40),

                // ── Buttons ─────────────────────────────────────
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
                        // ── Google ──────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: () => _handleGoogleSignIn(context),
                            icon: const Icon(Icons.login),
                            label: const Text(
                              'Sign in with Google',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Email ───────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: () => _openEmailLogin(context),
                            icon: const Icon(Icons.email_outlined),
                            label: const Text(
                              'Sign in with Email',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Divider ─────────────────────────────
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
                        const SizedBox(height: 20),

                        // ── Anonymous ───────────────────────────
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: TextButton.icon(
                            onPressed: () => _handleAnonymousSignIn(context),
                            icon: const Icon(Icons.person_outline, size: 20),
                            label: const Text('Continue without account'),
                          ),
                        ),

                        // ── Register link ───────────────────────
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: () => _openRegister(context),
                          child: Text.rich(
                            TextSpan(
                              text: "Don't have an account? ",
                              children: [
                                TextSpan(
                                  text: 'Register',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // ── Error ───────────────────────────────
                        if (auth.error != null) ...[
                          const SizedBox(height: 16),
                          _ErrorBanner(message: auth.error!),
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

  // ── Handlers ────────────────────────────────────────────────────────

  Future<void> _handleGoogleSignIn(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final success = await auth.signInWithGoogle();
    if (success && context.mounted) {
      _goToHome(context);
    }
  }

  void _openEmailLogin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EmailLoginScreen()),
    );
  }

  void _openRegister(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  Future<void> _handleAnonymousSignIn(BuildContext context) async {
    // Show warning dialog first
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Continue without account?'),
        content: const Text(
          'You can use the app, but your words will only be saved on this '
          'device. If you delete the app or get a new phone, your data will '
          'be lost.\n\n'
          'Sign in with Google or Email to back up your words to the cloud.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Go back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue anyway'),
          ),
        ],
      ),
    );

    if (proceed != true || !context.mounted) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.signInAnonymously();
    if (success && context.mounted) {
      _goToHome(context);
    }
  }

  void _goToHome(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }
}

/// Inline error banner used on the login screen.
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: theme.colorScheme.onErrorContainer,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: theme.colorScheme.onErrorContainer,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
