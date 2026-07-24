import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../main.dart'; // For AuthGate
import '../screens/settings_screen.dart';
import '../screens/bulk_import_screen.dart';
import '../screens/archived_words_screen.dart';
import '../screens/pdf_reader_screen.dart';
import '../screens/text_to_audio_screen.dart';
import '../screens/flashcard_screen.dart';
import '../screens/ai_quiz_screen.dart';
import '../screens/daily_phrases_screen.dart';
import '../screens/review_session_screen.dart';
import '../screens/review_summary_screen.dart';
import '../screens/login_screen.dart';
import '../screens/user_guide_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const AuthGate(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/import',
      builder: (context, state) => const BulkImportScreen(),
    ),
    GoRoute(
      path: '/archived',
      builder: (context, state) => const ArchivedWordsScreen(),
    ),
    GoRoute(
      path: '/pdf',
      builder: (context, state) => const PdfReaderScreen(),
    ),
    GoRoute(
      path: '/audio',
      builder: (context, state) => const TextToAudioScreen(),
    ),
    GoRoute(
      path: '/flashcards',
      builder: (context, state) => const FlashcardScreen(),
    ),
    GoRoute(
      path: '/quiz',
      builder: (context, state) => const AiQuizScreen(),
    ),
    GoRoute(
      path: '/phrases',
      builder: (context, state) => const DailyPhrasesScreen(),
    ),
    GoRoute(
      path: '/guide',
      builder: (context, state) => const UserGuideScreen(),
    ),
    GoRoute(
      path: '/review',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return ReviewSessionScreen(
          mode: extra['mode'] ?? 'deck',
          deck: extra['deck'],
        );
      },
    ),
    GoRoute(
      path: '/summary',
      builder: (context, state) {
        final stats = state.extra as SessionStats;
        return ReviewSummaryScreen(stats: stats);
      },
    ),
  ],
);
