/// ─── Study Heatmap Card (Habit Continuity) ────────────────────────
///
/// A GitHub-style activity calendar displaying user study habits over the past
/// 12 weeks. Synthesizes interaction timestamps from vocabulary cards and cloud
/// streak histories to visually reinforce sustainable daily learning routines.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/word_provider.dart';

class StudyHeatmapCard extends StatelessWidget {
  const StudyHeatmapCard({super.key});

  String _isoDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  Map<String, int> _buildActivityMap(WordProvider provider) {
    final activity = <String, int>{};

    void addDate(DateTime? dt) {
      if (dt == null) return;
      final key = _isoDate(dt.toLocal());
      activity[key] = (activity[key] ?? 0) + 1;
    }

    // Include last study date from streak tracker
    if (provider.streak.lastStudyDate != null) {
      activity[provider.streak.lastStudyDate!] = 3;
    }

    // Count interactions from all vocabulary words
    for (final w in provider.words) {
      addDate(w.createdAt);
      addDate(w.updatedAt);
      addDate(w.srsLastReview);
    }

    return activity;
  }

  Color _getCellColor(int count, ColorScheme cs, bool isDark) {
    if (count == 0) {
      return isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    } else if (count == 1) {
      return isDark ? const Color(0xFF5B21B6) : const Color(0xFFDDD6FE);
    } else if (count <= 3) {
      return isDark ? const Color(0xFF7C3AED) : const Color(0xFF8B5CF6);
    } else {
      return isDark ? const Color(0xFFA78BFA) : const Color(0xFF6D28D9);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WordProvider>();
    final activity = _buildActivityMap(provider);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final now = DateTime.now();
    // 12 weeks * 7 days = 84 days
    const totalDays = 84;
    const numWeeks = 12;
    final startDate = now.subtract(const Duration(days: totalDays - 1));

    int totalActiveDays = 0;
    for (int i = 0; i < totalDays; i++) {
      final dt = startDate.add(Duration(days: i));
      if (activity.containsKey(_isoDate(dt))) {
        totalActiveDays++;
      }
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.calendar_month_rounded, color: Colors.purple, size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Habit Continuity Heatmap',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$totalActiveDays Active Days',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: Colors.purple),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Heatmap grid (horizontal scrollable on very narrow screens)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(numWeeks, (weekIndex) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(7, (dayOfWeek) {
                      final dayIndex = (weekIndex * 7) + dayOfWeek;
                      if (dayIndex >= totalDays) return const SizedBox.shrink();

                      final dt = startDate.add(Duration(days: dayIndex));
                      final key = _isoDate(dt);
                      final count = activity[key] ?? 0;
                      final isToday = dayIndex == (totalDays - 1);

                      return Tooltip(
                        message: '${_isoDate(dt)}: ${count > 0 ? "$count interactions" : "No study practice"}',
                        child: Container(
                          width: 14,
                          height: 14,
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: _getCellColor(count, cs, isDark),
                            borderRadius: BorderRadius.circular(3),
                            border: isToday
                                ? Border.all(color: Colors.orange, width: 1.8)
                                : null,
                          ),
                        ),
                      );
                    }),
                  );
                }),
              ),
            ),
            const SizedBox(height: 12),

            // Footer / Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('Less', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                const SizedBox(width: 6),
                Container(width: 12, height: 12, decoration: BoxDecoration(color: _getCellColor(0, cs, isDark), borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 3),
                Container(width: 12, height: 12, decoration: BoxDecoration(color: _getCellColor(1, cs, isDark), borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 3),
                Container(width: 12, height: 12, decoration: BoxDecoration(color: _getCellColor(2, cs, isDark), borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 3),
                Container(width: 12, height: 12, decoration: BoxDecoration(color: _getCellColor(4, cs, isDark), borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 6),
                Text('More', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
