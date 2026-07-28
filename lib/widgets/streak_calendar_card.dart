import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/word_provider.dart';
import '../config/app_strings.dart';

class StreakCalendarCard extends StatefulWidget {
  const StreakCalendarCard({super.key});

  @override
  State<StreakCalendarCard> createState() => _StreakCalendarCardState();
}

class _StreakCalendarCardState extends State<StreakCalendarCard> {
  late DateTime _focusedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
  }

  String _isoDate(int year, int month, int day) =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  Set<String> _buildActiveDateSet(WordProvider provider) {
    final activeDates = <String>{};

    void addDate(DateTime? dt) {
      if (dt == null) return;
      final local = dt.toLocal();
      activeDates.add(_isoDate(local.year, local.month, local.day));
    }

    if (provider.streak.lastStudyDate != null) {
      activeDates.add(provider.streak.lastStudyDate!);
    }

    for (final w in provider.words) {
      addDate(w.createdAt);
      addDate(w.updatedAt);
      addDate(w.srsLastReview);
    }

    return activeDates;
  }

  void _prevMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    if (_focusedMonth.year == now.year && _focusedMonth.month == now.month) {
      return; // Do not navigate into future months
    }
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WordProvider>();
    final activeDates = _buildActiveDateSet(provider);
    String? earliestDateStr;
    if (activeDates.isNotEmpty) {
      final sorted = activeDates.toList()..sort();
      earliestDateStr = sorted.first;
    }
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = AppStrings.of(context);

    final now = DateTime.now();
    final isCurrentMonth = _focusedMonth.year == now.year && _focusedMonth.month == now.month;
    final todayStr = _isoDate(now.year, now.month, now.day);

    final monthsEn = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final monthsDe = [
      'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
      'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember'
    ];
    final monthNames = s.locale == 'de' ? monthsDe : monthsEn;
    final monthHeader = '${monthNames[_focusedMonth.month - 1]} ${_focusedMonth.year}';

    final weekdays = s.locale == 'de'
        ? ['So', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa']
        : ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

    // Determine calendar grid calculations
    final firstDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    
    // Convert Dart weekday (Mon=1 ... Sun=7) to Sunday=0 index
    final firstWeekday = firstDayOfMonth.weekday % 7;
    final totalSlots = firstWeekday + daysInMonth;
    final numRows = (totalSlots / 7).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.locale == 'de' ? 'Streak-Kalender' : 'Streak Calendar',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? cs.surfaceContainerHigh : cs.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cs.outlineVariant.withAlpha(150), width: 1.5),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Column(
            children: [
              // Header row with arrows
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    onPressed: _prevMonth,
                    tooltip: s.locale == 'de' ? 'Vorherige' : 'Previous',
                  ),
                  Text(
                    monthHeader,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.arrow_forward_ios,
                      size: 18,
                      color: isCurrentMonth ? cs.outline.withAlpha(80) : null,
                    ),
                    onPressed: isCurrentMonth ? null : _nextMonth,
                    tooltip: s.locale == 'de' ? 'Nächste' : 'Next',
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Weekdays Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: weekdays
                    .map(
                      (day) => Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),

              // Calendar Grid Rows
              for (int row = 0; row < numRows; row++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: List.generate(7, (col) {
                      final dayIndex = row * 7 + col - firstWeekday + 1;
                      if (dayIndex < 1 || dayIndex > daysInMonth) {
                        return const Expanded(child: SizedBox(height: 44));
                      }

                      final currentDayStr = _isoDate(_focusedMonth.year, _focusedMonth.month, dayIndex);
                      final isStudied = activeDates.contains(currentDayStr);
                      final isToday = currentDayStr == todayStr;
                      final isPast = currentDayStr.compareTo(todayStr) < 0;
                      final isAfterEarliest = earliestDateStr != null && currentDayStr.compareTo(earliestDateStr) >= 0;
                      final isFrozen = !isStudied && isPast && isAfterEarliest;

                      return Expanded(
                        child: Center(
                          child: Tooltip(
                            message: isFrozen
                                ? (s.locale == 'de' ? 'Tag $dayIndex: Streak eingefroren' : 'Day $dayIndex: Streak Freeze')
                                : (isStudied ? (s.locale == 'de' ? 'Tag $dayIndex: Gelernt' : 'Day $dayIndex: Studied') : 'Tag $dayIndex'),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isStudied
                                    ? const Color(0xFFFF9600) // Duolingo Bright Orange
                                    : (isFrozen
                                        ? const Color(0xFF00C7E5) // Duolingo Ice Blue (Streak Freeze)
                                        : (isToday ? cs.primary.withAlpha(20) : Colors.transparent)),
                                shape: BoxShape.circle,
                                border: isToday && !isStudied && !isFrozen
                                    ? Border.all(color: cs.primary, width: 2)
                                    : null,
                                boxShadow: isStudied
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFFFF9600).withAlpha(80),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : (isFrozen
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF00C7E5).withAlpha(80),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            )
                                          ]
                                        : null),
                              ),
                              child: isFrozen
                                  ? Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.ac_unit, color: Colors.white, size: 16),
                                        Text(
                                          '$dayIndex',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                            height: 1.1,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Text(
                                          '$dayIndex',
                                          style: TextStyle(
                                            color: isStudied ? Colors.white : cs.onSurface,
                                            fontWeight: isStudied || isToday ? FontWeight.w800 : FontWeight.w500,
                                            fontSize: 15,
                                          ),
                                        ),
                                        if (isStudied)
                                          Positioned(
                                            bottom: 3,
                                            child: Container(
                                              width: 4,
                                              height: 4,
                                              decoration: const BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),
              // Calendar Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildLegendItem(
                    color: const Color(0xFFFF9600),
                    icon: Icons.local_fire_department,
                    label: s.locale == 'de' ? 'Gelernt' : 'Studied',
                    cs: cs,
                  ),
                  _buildLegendItem(
                    color: const Color(0xFF00C7E5),
                    icon: Icons.ac_unit,
                    label: s.locale == 'de' ? 'Eingefroren' : 'Freeze',
                    cs: cs,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: cs.primary, width: 2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        s.locale == 'de' ? 'Heute' : 'Today',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem({required Color color, required IconData icon, required String label, required ColorScheme cs}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, size: 13, color: Colors.white),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
