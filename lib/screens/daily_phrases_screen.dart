import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_strings.dart';
import '../models/word.dart';
import '../providers/word_provider.dart';
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
  final _themeCtrl = TextEditingController();

  List<DailyPhrase>? _phrases;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;
  String _lang = 'de';
  String? _lastTheme;
  bool _showThemeWarning = false;
  SharedPreferences? _prefs;  // cached to avoid getInstance() on every tap

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

  @override
  void dispose() {
    _themeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPhrases({String? theme, bool forceRefresh = false}) async {
    // Only show full-screen spinner on initial load, not on refresh
    if (!forceRefresh) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      _prefs = await SharedPreferences.getInstance();
      final savedDate = _prefs!.getString(_dateKey);
      final lang = _prefs!.getString(_langKey) ?? 'de';
      _lang = lang;

      if (!forceRefresh && theme == null && savedDate == _today()) {
        final jsonStr = _prefs!.getString(_phrasesKey);
        if (jsonStr != null) {
          final list = jsonDecode(jsonStr) as List;
          _phrases = list.map((j) => DailyPhrase.fromJson(j)).toList();
          _isLoading = false;
          setState(() {});
          return;
        }
      }

      final phrases = await _translator.generateDailyPhrases(
        lang: lang,
        theme: theme,
      );
      _phrases = phrases;
      _isLoading = false;
      _isRefreshing = false;
      _lastTheme = theme;
      setState(() {});

      await _saveToPrefs();
    } catch (e) {
      setState(() {
        _error = 'Failed to load phrases: $e';
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  void _generateNew() {
    final theme = _themeCtrl.text.trim();
    if (theme.isEmpty) {
      setState(() => _showThemeWarning = true);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showThemeWarning = false);
      });
    }
    // Keep existing phrases visible while refreshing
    setState(() => _isRefreshing = true);
    _loadPhrases(theme: theme.isNotEmpty ? theme : null, forceRefresh: true);
  }

  Future<void> _saveToPrefs() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setString(_dateKey, _today());
    await prefs.setString(
      _phrasesKey,
      jsonEncode(_phrases!.map((p) => p.toJson()).toList()),
    );
  }

  void _toggleMemorized(int index) {
    setState(() {
      _phrases![index].memorized = !_phrases![index].memorized;
    });
    _saveToPrefs();  // uses cached _prefs, no need for getInstance()
  }

  void _saveToMyWords(int index) async {
    final phrase = _phrases![index];
    final provider = context.read<WordProvider>();
    final s = AppStrings.of(context);

    final exists = provider.words.any((w) => w.word == phrase.phrase);
    if (exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.locale == 'de' ? 'Bereits in Meine Wörter' : 'Already in My Words')),
        );
      }
      return;
    }

    // Save the word with its AI translation (from daily phrases, no translation yet)
    // Show a loading indicator while we translate
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.locale == 'de' ? 'Übersetze...' : s.locale == 'ar' ? '...جار الترجمة' : 'Translating...'),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    // Auto-translate the phrase so flashcards have content
    String translation = '';
    String exampleSource = '';
    String exampleTarget = '';
    try {
      final result = await _translator.translate(
        word: phrase.phrase,
        sourceLang: _lang,
        targetLang: 'en',
      );
      if (result.meanings.isNotEmpty) {
        final m = result.meanings.first;
        translation = m.text;
        exampleSource = m.exampleSource;
        exampleTarget = m.exampleTarget;
      }
    } catch (_) {
      // If translation fails, save with empty translation — user can edit later
    }

    final success = await provider.addWord(
      word: phrase.phrase,
      translation: translation,
      exampleSource: '',
      exampleTarget: '',
      sourceLang: _lang,
      targetLang: 'en',
    );

    if (mounted) {
      final msg = s.savedWordToMyWords.replaceAll('{word}', phrase.phrase);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? msg : (s.locale == 'de' ? 'Fehler beim Speichern' : 'Failed to save')),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);

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
                label: Text(s.retry),
              ),
            ],
          ),
        ),
      );
    }

    final allMemorized = _phrases!.every((p) => p.memorized);
    final doneCount = _phrases!.where((p) => p.memorized).length;

    return Column(
      children: [
        // Theme input + Refresh row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _themeCtrl,
                  decoration: InputDecoration(
                    hintText: s.themeHint,
                    prefixIcon: const Icon(Icons.topic, size: 20),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: _showThemeWarning
                          ? const BorderSide(color: Colors.red, width: 2)
                          : BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: _showThemeWarning
                          ? const BorderSide(color: Colors.red, width: 2)
                          : BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: _showThemeWarning
                          ? const BorderSide(color: Colors.red, width: 2)
                          : BorderSide(color: Theme.of(context).colorScheme.primary),
                    ),
                    helperText: _showThemeWarning
                        ? (s.locale == 'de'
                            ? '⚠️ Kein Thema — zufällige Phrasen werden generiert'
                            : s.locale == 'ar'
                                ? '⚠️ لا يوجد موضوع — سيتم توليد عبارات عشوائية'
                                : '⚠️ No theme — generating random phrases')
                        : null,
                    helperStyle: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                  style: const TextStyle(fontSize: 14),
                  onSubmitted: (_) => _generateNew(),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: s.generateNew,
                child: IconButton.filled(
                  onPressed: _isRefreshing ? null : _generateNew,
                  icon: _isRefreshing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.refresh, size: 20),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(42, 42),
                  ),
                ),
              ),
            ],
          ),
        ),

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
                      ? s.allDone
                      : s.locale == 'de'
                          ? 'Lerne diese 5 Phrasen heute'
                          : 'Memorize these 5 phrases today',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                s.memorizedCounter(doneCount, _phrases!.length),
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
                  leading: Tooltip(
                    message: phrase.memorized
                        ? (s.locale == 'de' ? 'Rückgängig' : 'Undo')
                        : (s.locale == 'de' ? 'Merken' : 'Memorize'),
                    child: GestureDetector(
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
                  ),
                  title: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.volume_up,
                            size: 18,
                            color: phrase.memorized
                                ? Colors.grey[400]
                                : theme.colorScheme.primary),
                        tooltip: s.listenWord,
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
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: s.saveToWords,
                        child: IconButton(
                          icon: const Icon(Icons.bookmark_add_outlined, size: 20),
                          onPressed: () => _saveToMyWords(index),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                      ),
                      if (phrase.memorized)
                        Tooltip(
                          message: s.locale == 'de' ? 'Gemerkt' : 'Memorized',
                          child: Icon(Icons.check_circle,
                              color: Colors.green[400], size: 20),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
