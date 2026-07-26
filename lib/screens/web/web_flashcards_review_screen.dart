import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/word_provider.dart';
import '../../models/study_mode.dart';
import '../../services/study_prefs.dart';
import '../../widgets/web_top_bar.dart';

class WebFlashcardsReviewScreen extends StatefulWidget {
  const WebFlashcardsReviewScreen({super.key});

  @override
  State<WebFlashcardsReviewScreen> createState() => _WebFlashcardsReviewScreenState();
}

class _WebFlashcardsReviewScreenState extends State<WebFlashcardsReviewScreen> {
  StudyMode _selectedMode = StudyMode.flip;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      final idx = prefs.getInt(kStudyModePrefKey);
      if (idx != null && idx >= 0 && idx < StudyMode.values.length) {
        setState(() => _selectedMode = StudyMode.values[idx]);
      }
    });
  }

  Future<void> _proceedWithStudy() async {
    setState(() => _isLoading = true);
    final provider = context.read<WordProvider>();
    await provider.refreshSrs();
    if (!mounted) return;

    if (provider.dueCount == 0 && provider.newCount == 0) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎉 All caught up — no cards due right now. Browsing all cards instead.')),
      );
      context.push('/flashcards');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kStudyModePrefKey, _selectedMode.index);
    final maxNew = await StudyPrefs.newCardsPerSession();
    final deck = await provider.buildSessionDeck(maxCards: maxNew);
    if (!mounted) return;

    setState(() => _isLoading = false);
    if (deck.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to review right now.')),
      );
      return;
    }

    context.push('/review', extra: {'mode': _selectedMode, 'deck': deck});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<WordProvider>();
    final totalDue = provider.dueCount + provider.newCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flashcards Review'),
        actions: WebTopBar.buildActions(context),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Icon(Icons.style_outlined, size: 30, color: theme.colorScheme.primary),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Flashcards & Spaced Repetition',
                            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Choose how you want to practice and master your vocabulary collection today.',
                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 36),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final bool useColumn = constraints.maxWidth < 740;
                    if (useColumn) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildStudyModeCard(theme, totalDue, provider),
                          const SizedBox(height: 24),
                          _buildReviewAllCard(theme),
                        ],
                      );
                    }
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _buildStudyModeCard(theme, totalDue, provider)),
                          const SizedBox(width: 28),
                          Expanded(child: _buildReviewAllCard(theme)),
                        ],
                      ),
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

  Widget _buildStudyModeCard(ThemeData theme, int totalDue, WordProvider provider) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(150), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.school, color: theme.colorScheme.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Study Mode (SRS)',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Smart Spaced Repetition system. Review cards right before you forget them to maximize long-term retention.',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  '${provider.dueCount} due',
                  style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.primary, fontSize: 13),
                ),
                const SizedBox(width: 16),
                Icon(Icons.fiber_new, size: 16, color: theme.colorScheme.tertiary),
                const SizedBox(width: 6),
                Text(
                  '${provider.newCount} new',
                  style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.tertiary, fontSize: 13),
                ),
                const SizedBox(width: 16),
                Text(
                  '$totalDue total available',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Select Practice Mode:',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: StudyMode.values.map((mode) {
              final selected = _selectedMode == mode;
              return ChoiceChip(
                avatar: Icon(_modeIcon(mode), size: 18, color: selected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant),
                label: Text(_modeLabel(mode)),
                selected: selected,
                onSelected: (val) {
                  if (val) setState(() => _selectedMode = mode);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow.withAlpha(120),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _modeDescription(_selectedMode),
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
            ),
          ),
          const Spacer(),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _proceedWithStudy,
              icon: _isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.play_arrow),
              label: Text(
                totalDue > 0 ? 'Proceed with Study Mode ($totalDue cards)' : 'Proceed (All Caught Up)',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewAllCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(150), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.flip_to_front, color: theme.colorScheme.secondary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Review All Flashcards',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Browse freely through your full vocabulary library at your own pace without modifying or affecting your SRS schedules.',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 24),
          _buildFeatureBullet(theme, Icons.check_circle_outline, 'Flip cards to inspect examples & definitions'),
          const SizedBox(height: 10),
          _buildFeatureBullet(theme, Icons.check_circle_outline, 'View AI-generated grammar and usage tips'),
          const SizedBox(height: 10),
          _buildFeatureBullet(theme, Icons.check_circle_outline, 'Edit personal notes and customized meanings'),
          const Spacer(),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/flashcards'),
              icon: const Icon(Icons.view_carousel),
              label: const Text(
                'Review All Flashcards',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                foregroundColor: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBullet(ThemeData theme, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  IconData _modeIcon(StudyMode mode) {
    switch (mode) {
      case StudyMode.flip:
        return Icons.flip;
      case StudyMode.typing:
        return Icons.keyboard;
      case StudyMode.reverse:
        return Icons.swap_vert;
    }
  }

  String _modeLabel(StudyMode mode) {
    switch (mode) {
      case StudyMode.flip:
        return 'Flip';
      case StudyMode.typing:
        return 'Type';
      case StudyMode.reverse:
        return 'Reverse';
    }
  }

  String _modeDescription(StudyMode mode) {
    switch (mode) {
      case StudyMode.flip:
        return 'Show the word, then flip to reveal the translation.';
      case StudyMode.typing:
        return 'Show the word, type the translation before revealing.';
      case StudyMode.reverse:
        return 'Show the translation, recall the original word.';
    }
  }
}
