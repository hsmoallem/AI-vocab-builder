import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/translation_service.dart';
import '../services/tts_service.dart';

class DailyPhrasesScreen extends StatefulWidget {
  const DailyPhrasesScreen({super.key});

  @override
  State<DailyPhrasesScreen> createState() => _DailyPhrasesScreenState();
}

class _DailyPhrasesScreenState extends State<DailyPhrasesScreen> {
  final TranslationService _translator = TranslationService();
  final TtsService _tts = TtsService();

  List<DailyPhrase>? _phrases;
  bool _isLoading = true;
  String? _error;
  String _lang = 'de'; // Default German, loaded from prefs

  static const _dateKey = 'daily_phrases_date';
  static const _phrasesKey = 'daily_phrases_data';
  static const _langKey = 'daily_phrases_lang';

  String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _loadPhrases();
  }

  Future<void> _loadPhrases() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDate = prefs.getString(_dateKey);
      final lang = prefs.getString(_langKey) ?? 'de';
      _lang = lang;

      if (savedDate == _today()) {
        final jsonStr = prefs.getString(_phrasesKey);
        if (jsonStr != null) {
          final list = jsonDecode(jsonStr) as List;
          _phrases = list.map((j) => DailyPhrase.fromJson(j)).toList();
          _isLoading = false;
          setState(() {});
          return;
        }
      }

      final phrases = await _translator.generateDailyPhrases(lang: lang);
      _phrases = phrases;
      _isLoading = false;
      setState(() {});

      await _saveToPrefs(prefs);
    } catch (e) {
      setState(() {
        _error = 'Failed to load phrases: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveToPrefs(SharedPreferences prefs) async {
    await prefs.setString(_dateKey, _today());
    await prefs.setString(
      _phrasesKey,
      jsonEncode(_phrases!.map((p) => p.toJson()).toList()),
    );
  }

  void _toggleMemorized(int index) async {
    setState(() {
      _phrases![index].memorized = !_phrases![index].memorized;
    });

    final prefs = await SharedPreferences.getInstance();
    await _saveToPrefs(prefs);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadPhrases,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final allMemorized = _phrases!.every((p) => p.memorized);

    return Column(
      children: [
        // Header card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          decoration: BoxDecoration(
            color: allMemorized
                ? Colors.green.shade50
                : theme.colorScheme.primaryContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                allMemorized ? Icons.emoji_events : Icons.auto_awesome,
                color: allMemorized ? Colors.green : theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  allMemorized
                      ? 'All done! 🎉\nCheck back tomorrow for 5 new phrases.'
                      : 'Memorize these 5 phrases today',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '${_phrases!.where((p) => p.memorized).length}/${_phrases!.length}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: allMemorized ? Colors.green : theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),

        // Phrase cards
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _phrases!.length,
            itemBuilder: (context, index) {
              final phrase = _phrases![index];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                color: phrase.memorized
                    ? Colors.green.shade50
                    : theme.cardTheme.color ?? theme.cardColor,
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: GestureDetector(
                    onTap: () => _toggleMemorized(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: phrase.memorized
                            ? Colors.green
                            : Colors.grey.shade300,
                      ),
                      child: Icon(
                        phrase.memorized ? Icons.check : Icons.circle_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      // 🔊 Speak phrase in the daily phrases language
                      IconButton(
                        icon: Icon(Icons.volume_up,
                            size: 18,
                            color: phrase.memorized
                                ? Colors.grey[400]
                                : theme.colorScheme.primary),
                        tooltip: 'Listen',
                        onPressed: phrase.memorized
                            ? null
                            : () => _tts.speak(phrase.phrase, language: _lang),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          phrase.phrase,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            decoration: phrase.memorized
                                ? TextDecoration.lineThrough
                                : null,
                            color: phrase.memorized ? Colors.grey : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  trailing: phrase.memorized
                      ? Icon(Icons.check_circle, color: Colors.green[400])
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
