import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../providers/word_provider.dart';
import '../widgets/study_heatmap_card.dart';
import '../config/app_strings.dart';

class StreakScreen extends StatelessWidget {
  const StreakScreen({super.key});

  static void show(BuildContext context) {
    if (kIsWeb || MediaQuery.of(context).size.width > 600) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: const Padding(
              padding: EdgeInsets.all(24.0),
              child: StreakScreen(),
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: const StreakScreen(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WordProvider>();
    final streak = provider.streak;
    final cs = Theme.of(context).colorScheme;
    final s = AppStrings.of(context);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle for bottom sheet on mobile
          if (!kIsWeb && MediaQuery.of(context).size.width <= 600)
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

          // Header title & close icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                s.locale == 'de' ? 'Dein Lernstreak' : 'Your Learning Streak',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Streak badges row
          Row(
            children: [
              Expanded(
                child: _StreakStatBox(
                  icon: Icons.local_fire_department,
                  iconColor: Colors.orange,
                  value: '${streak.current}',
                  label: s.locale == 'de' ? 'Aktueller Streak' : 'Current Streak',
                  subtext: streak.studiedToday
                      ? (s.locale == 'de' ? 'Heute gelernt! 🔥' : 'Studied today! 🔥')
                      : (s.locale == 'de' ? 'Heute noch lernend...' : 'Study today to keep!'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StreakStatBox(
                  icon: Icons.emoji_events,
                  iconColor: Colors.amber,
                  value: '${streak.longest}',
                  label: s.locale == 'de' ? 'Längster Streak' : 'Best Streak',
                  subtext: s.locale == 'de' ? 'Persönlicher Rekord' : 'Personal best',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Heatmap card
          const StudyHeatmapCard(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _StreakStatBox extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final String subtext;

  const _StreakStatBox({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.subtext,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : cs.primaryContainer.withAlpha(50),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 28),
              const SizedBox(width: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtext,
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
