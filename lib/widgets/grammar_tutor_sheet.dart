/// ─── AI Language Tutor Console (Grammar Tutor Sheet / Dialog) ────────
///
/// Displays a comprehensive, teacher-style linguistic breakdown of a saved vocabulary item.
/// Includes canonical grammatical attributes, pronunciation IPA, irregular trait badges,
/// teacher grammar rules/pitfalls, conversational usage notes, and on-demand re-enrichment.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/word.dart';
import '../providers/word_provider.dart';
import '../services/analytics_service.dart';

/// Opens the AI Language Tutor linguistic breakdown sheet or dialog.
void showGrammarTutorSheet(BuildContext context, Word word) {
  AnalyticsService.trackEvent('open_grammar_tutor_sheet', {'word': word.word});
  final isWide = MediaQuery.of(context).size.width > 600;
  if (isWide) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
          child: _GrammarTutorContent(initialWord: word),
        ),
      ),
    );
  } else {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        child: _GrammarTutorContent(initialWord: word),
      ),
    );
  }
}

class _GrammarTutorContent extends StatefulWidget {
  final Word initialWord;
  const _GrammarTutorContent({required this.initialWord});

  @override
  State<_GrammarTutorContent> createState() => _GrammarTutorContentState();
}

class _GrammarTutorContentState extends State<_GrammarTutorContent> {
  late Word _word;
  bool _isEnriching = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _word = widget.initialWord;
  }

  Future<void> _reEnrich() async {
    setState(() {
      _isEnriching = true;
      _errorMessage = null;
    });
    try {
      final provider = context.read<WordProvider>();
      final updated = await provider.reEnrichWord(_word);
      // If tip is still null/empty, force tip generation
      if (updated.grammarTip == null || updated.grammarTip!.isEmpty) {
        await provider.generateGrammarTipFor(updated, force: true);
        final refreshed = provider.words.firstWhere((w) => w.id == _word.id, orElse: () => updated);
        setState(() => _word = refreshed);
      } else {
        setState(() => _word = updated);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Could not complete AI enrichment: ${e.toString().replaceAll("Exception: ", "")}');
    } finally {
      setState(() => _isEnriching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top drag handle for mobile sheet
        if (MediaQuery.of(context).size.width <= 600)
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: theme.dividerColor.withOpacity(0.2))),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor.withOpacity(0.2), Colors.purpleAccent.withOpacity(0.2)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.school, color: primaryColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Language Tutor',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Linguistic analysis & pedagogical guidance',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Close',
              ),
            ],
          ),
        ),
        // Main scrollable body
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Word Title & IPA Badge
              _buildWordHeader(theme),
              const SizedBox(height: 16),

              // AI Confidence Safety Banner
              if (_word.grammarConfidence != null)
                _buildConfidenceBanner(theme, _word.grammarConfidence!),

              // Grammatical Trait Badges (Irregular, Reflexive, Separable, etc.)
              _buildTraitBadges(theme),
              const SizedBox(height: 16),

              // Canonical Grammar Facts Table
              _buildCanonicalGrammarSection(theme, isDark),
              const SizedBox(height: 20),

              // Teacher Grammar Tip Card (Lightbulb)
              _buildTeacherTipCard(theme, isDark),
              const SizedBox(height: 16),

              // Conversational Usage Note Card (Chat Bubble)
              _buildUsageNoteCard(theme, isDark),
              const SizedBox(height: 24),

              if (_errorMessage != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                ),
              ],
            ],
          ),
        ),
        // Footer actions
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.grey[100],
            border: Border(top: BorderSide(color: theme.dividerColor.withOpacity(0.2))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: _isEnriching ? null : _reEnrich,
                icon: _isEnriching
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome, size: 18),
                label: Text(_isEnriching ? 'Analyzing...' : 'Re-enrich with AI Tutor'),
                style: TextButton.styleFrom(
                  foregroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWordHeader(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: [
              Text(
                _word.word,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
              ),
              if (_word.partOfSpeech != null && _word.partOfSpeech!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _word.partOfSpeech!,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.onSecondaryContainer),
                  ),
                ),
              if (_word.ipa != null && _word.ipa!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.volume_up, size: 14, color: Colors.purple),
                      const SizedBox(width: 4),
                      Text(
                        _word.ipa!,
                        style: const TextStyle(fontFamily: 'Courier', fontSize: 13, fontWeight: FontWeight.w500, color: Colors.purple),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfidenceBanner(ThemeData theme, double confidence) {
    final pct = (confidence * 100).clamp(0, 100).toInt();
    final isHigh = confidence >= 0.85;
    final color = isHigh ? Colors.green : Colors.orange;
    final text = isHigh
        ? 'AI Tutor Confidence: $pct% (High grammatical reliability)'
        : 'AI Tutor Confidence: $pct% (Moderate reliability — please verify rare regional conjugations)';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(isHigh ? Icons.verified : Icons.warning_amber_rounded, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12, color: color.darken(10), fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildTraitBadges(ThemeData theme) {
    final traits = <Widget>[];
    if (_word.isIrregular) {
      traits.add(_buildBadge('⚡ Irregular', Colors.orange, 'Does not follow standard grammatical conjugation or plural rules'));
    }
    if (_word.isReflexive) {
      traits.add(_buildBadge('🔄 Reflexive', Colors.blue, 'Requires a reflexive pronoun (sich / myself / yourself)'));
    }
    if (_word.isSeparable) {
      traits.add(_buildBadge('✂️ Separable Prefix', Colors.teal, 'Prefix detaches and moves to the end of a clause in simple sentences'));
    }
    if (_word.isUncountable) {
      traits.add(_buildBadge('🚫 Uncountable', Colors.redAccent, 'No distinct plural form; treated as a singular mass noun'));
    }
    if (traits.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: traits,
    );
  }

  Widget _buildBadge(String label, Color color, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }

  Widget _buildCanonicalGrammarSection(ThemeData theme, bool isDark) {
    final data = _word.grammarData ?? {};
    final entries = <String, String>{};

    // Extract canonical fields in predictable order
    if (data['article'] != null) entries['Definite Article'] = '${data['article']}';
    if (data['plural'] != null) entries['Plural Form'] = '${data['plural']}';
    if (data['feminine'] != null) entries['Feminine Equivalent'] = '${data['feminine']}';
    if (data['masculine'] != null && data['masculine'].toString().isNotEmpty) entries['Masculine Form'] = '${data['masculine']}';
    if (data['infinitive'] != null) entries['Infinitive'] = '${data['infinitive']}';
    if (data['simple_past'] != null) entries['Simple Past (Präteritum)'] = '${data['simple_past']}';
    if (data['past_participle'] != null) entries['Past Participle'] = '${data['past_participle']}';
    if (data['auxiliary'] != null) entries['Auxiliary Verb'] = '${data['auxiliary']}';
    if (data['verb_type'] != null) entries['Verb Type'] = '${data['verb_type']}';
    if (data['requires_case'] != null) entries['Required Case'] = '${data['requires_case']}';
    if (data['comparative'] != null) entries['Comparative'] = '${data['comparative']}';
    if (data['superlative'] != null) entries['Superlative'] = '${data['superlative']}';

    if (data['prepositions'] != null) {
      final prep = data['prepositions'];
      if (prep is List && prep.isNotEmpty) {
        entries['Associated Prepositions'] = prep.join(', ');
      } else if (prep is String && prep.isNotEmpty) {
        entries['Associated Prepositions'] = prep;
      }
    }

    if (data['extra'] is Map) {
      (data['extra'] as Map).forEach((k, v) {
        if (v != null && v.toString().isNotEmpty) {
          entries[_capitalize(k.toString())] = v.toString();
        }
      });
    }

    if (entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: theme.hintColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No structured canonical grammar table available yet. Tap "Re-enrich with AI Tutor" below to generate formal linguistic facts.',
                style: TextStyle(color: theme.hintColor, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E24) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.table_chart_outlined, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Canonical Grammar Attributes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.primary)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Table(
              columnWidths: const {0: FlexColumnWidth(1.2), 1: FlexColumnWidth(1.8)},
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: entries.entries.map((e) {
                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(e.key, style: TextStyle(fontSize: 13, color: theme.hintColor, fontWeight: FontWeight.w500)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(e.value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherTipCard(ThemeData theme, bool isDark) {
    final hasTip = _word.grammarTip != null && _word.grammarTip!.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF2E2415), const Color(0xFF221A10)]
              : [const Color(0xFFFFF9ED), const Color(0xFFFFF2D6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), shape: BoxShape.circle),
                child: const Icon(Icons.lightbulb_outline, size: 20, color: Colors.amber),
              ),
              const SizedBox(width: 10),
              Text(
                'Teacher Grammar Guidance',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDark ? Colors.amber[300] : const Color(0xFF8C5800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            hasTip ? _word.grammarTip!.trim() : 'No AI grammar explanations generated yet. Tap "Re-enrich" to let the AI Language Tutor analyze syntax rules and exceptions.',
            style: TextStyle(fontSize: 13.5, height: 1.5, color: theme.textTheme.bodyMedium?.color),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageNoteCard(ThemeData theme, bool isDark) {
    final hasUsage = _word.usageNote != null && _word.usageNote!.trim().isNotEmpty;
    if (!hasUsage && (_word.grammarTip == null || _word.grammarTip!.isEmpty)) {
      return const SizedBox.shrink(); // Hide until enriched if both are empty
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF152826), const Color(0xFF101E1D)]
              : [const Color(0xFFEDFCFA), const Color(0xFFDAF7F3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.teal.withOpacity(0.2), shape: BoxShape.circle),
                child: const Icon(Icons.forum_outlined, size: 20, color: Colors.teal),
              ),
              const SizedBox(width: 10),
              Text(
                'Conversational Usage & Register',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDark ? Colors.teal[200] : const Color(0xFF006C60),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            hasUsage ? _word.usageNote!.trim() : 'In everyday conversation, observe surrounding prepositions and formal vs. informal pronouns. Re-enrich for specific register notes.',
            style: TextStyle(fontSize: 13.5, height: 1.5, color: theme.textTheme.bodyMedium?.color),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');
  }
}

extension on Color {
  Color darken([int percent = 10]) {
    assert(1 <= percent && percent <= 100);
    var f = 1 - percent / 100;
    return Color.fromARGB(alpha, (red * f).round(), (green * f).round(), (blue * f).round());
  }
}
