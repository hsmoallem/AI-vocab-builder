/// ─── Review Summary Screen ──────────────────────────────────────────
///
/// Shown after the user finishes a review session (all session cards rated).
/// Displays session stats: card counts per rating, accuracy, time spent,
/// streak update, and action buttons.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/srs_service.dart';
import '../services/database_service.dart';

/// Data collected during a single review session, passed to the summary.
class SessionStats {
  final int again;
  final int hard;
  final int good;
  final int easy;
  final DateTime sessionStart;
  final DateTime sessionEnd;
  final StreakSnapshot streak;

  const SessionStats({
    required this.again,
    required this.hard,
    required this.good,
    required this.easy,
    required this.sessionStart,
    required this.sessionEnd,
    required this.streak,
  });

  int get total => again + hard + good + easy;

  /// "Good or Easy" out of total, as a percentage.
  double get accuracy =>
      total == 0 ? 0.0 : ((good + easy) / total * 100);

  Duration get duration => sessionEnd.difference(sessionStart);
}

class ReviewSummaryScreen extends StatelessWidget {
  final SessionStats stats;

  const ReviewSummaryScreen({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final mins = stats.duration.inMinutes;
    final secs = stats.duration.inSeconds % 60;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session complete'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Trophy icon ───────────────────────────────────────
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.emoji_events_outlined,
                      size: 44,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Cards reviewed ────────────────────────────────────
                  Text(
                    '${stats.total} cards reviewed',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Rating breakdown bars ─────────────────────────────
                  _RatingBar(
                    label: 'Again',
                    count: stats.again,
                    total: stats.total,
                    color: cs.error,
                  ),
                  const SizedBox(height: 8),
                  _RatingBar(
                    label: 'Hard',
                    count: stats.hard,
                    total: stats.total,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 8),
                  _RatingBar(
                    label: 'Good',
                    count: stats.good,
                    total: stats.total,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 8),
                  _RatingBar(
                    label: 'Easy',
                    count: stats.easy,
                    total: stats.total,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 24),

                  // ── Stats row ────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatItem(
                        icon: Icons.timer_outlined,
                        label: 'Time',
                        value: '$mins:${secs.toString().padLeft(2, '0')}',
                      ),
                      _StatItem(
                        icon: Icons.check_circle_outline,
                        label: 'Accuracy',
                        value: '${stats.accuracy.toStringAsFixed(0)}%',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Streak (hidden for anonymous users) ────────────────────────────────────────────
                  if (!context.read<AuthProvider>().isAnonymous && stats.streak.current > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: cs.tertiaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 24)),
                          const SizedBox(width: 8),
                          Text(
                            '${stats.streak.current} day streak',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: cs.onTertiaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (stats.streak.current == stats.streak.longest &&
                        stats.streak.current > 1) ...[
                      const SizedBox(height: 8),
                      Text(
                        'New personal best!',
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.tertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 32),

                  // ── Action buttons ────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => context.go('/'),
                      icon: const Icon(Icons.home_outlined),
                      label: const Text('Back to Home'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.pop('review_again'),
                      icon: const Icon(Icons.replay_outlined),
                      label: const Text('Review again'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RatingBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _RatingBar({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : count / total;
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 14,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 28,
          child: Text(
            '$count',
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, size: 22, color: cs.onSurfaceVariant),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}
