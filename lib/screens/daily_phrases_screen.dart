import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_strings.dart';
import '../providers/locale_provider.dart';
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
  bool _showThemeWarning = false;
  SharedPreferences? _prefs;

  static const _dateKey = 'daily_phrases_date';
  static const _phrasesKey = 'daily_phrases_data';
  static const _langKey = 'daily_phrases_lang';
  static const _savedKey = 'daily_phrases_saved';

  String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Persistent set of phrase indices saved to My Words today.
  /// Survives widget rebuilds and hot reloads.
  final Set<int> _savedIndices = {};

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

      // Restore saved indices from persistent storage
      final savedJson = _prefs!.getString(_savedKey);
      if (savedJson != null) {
        _savedIndices.clear();
        _savedIndices.addAll((jsonDecode(savedJson) as List).cast<int>());
      }

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
    // Persist saved indices so they survive app restarts
    await prefs.setString(_savedKey, jsonEncode(_savedIndices.toList()));
  }

  void _toggleMemorized(int index) {
    setState(() {
      _phrases![index].memorized = !_phrases![index].memorized;
    });
    _saveToPrefs();
  }

  // ── Save phrase to My Words ─────────────────────────────────────

  Future<void> _saveToMyWords(int index) async {
    final phrase = _phrases![index];
    // Use read (not watch) — we're in a button handler, not a build method
    final provider = context.read<WordProvider>();
    final localeProvider = context.read<LocaleProvider>();
    final locale = localeProvider.locale;
    final targetLang = localeProvider.targetLang;
    final s = AppStrings(locale);

    // Check database directly — is this phrase already saved with a translation?
    for (final w in provider.words) {
      if (w.word == phrase.phrase && w.translation.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.locale == 'de' ? 'Bereits gespeichert' : 'Already saved'),
                backgroundColor: Theme.of(context).colorScheme.primary),
          );
        }
        setState(() => _savedIndices.add(index));
        return;
      }
    }

    // Translate and save
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Translating & saving...'), duration: Duration(seconds: 3)),
      );
    }

    try {
      final result = await _translator.translate(word: phrase.phrase, sourceLang: _lang, targetLang: targetLang);
      final m = result.meanings.isNotEmpty ? result.meanings.first : Meaning(text: phrase.phrase, article: null, exampleSource: '', exampleTarget: '');

      await provider.addWord(
        word: phrase.phrase,
        translation: m.text,
        exampleSource: m.exampleSource,
        exampleTarget: m.exampleTarget,
        sourceLang: _lang,
        targetLang: targetLang,
      );

      setState(() => _savedIndices.add(index));
      await _saveToPrefs();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ ${phrase.phrase} saved'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 5)),
        );
      }
    }
  }

  // ── UI ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    // Watch the word list so save-state stays in sync with the database.
    final wordProvider = context.watch<WordProvider>();

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
              Icon(Icons.cloud_off, size: 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
                          ? BorderSide(
                              color: Theme.of(context).colorScheme.error,
                              width: 2)
                          : BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: _showThemeWarning
                          ? BorderSide(
                              color: Theme.of(context).colorScheme.error,
                              width: 2)
                          : BorderSide(
                              color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: _showThemeWarning
                          ? BorderSide(
                              color: Theme.of(context).colorScheme.error,
                              width: 2)
                          : BorderSide(
                              color: Theme.of(context).colorScheme.primary),
                    ),
                    helperText: _showThemeWarning
                        ? (s.locale == 'de'
                            ? '⚠️ Kein Thema — zufällige Phrasen werden generiert'
                            : s.locale == 'ar'
                                ? '⚠️ لا يوجد موضوع — سيتم توليد عبارات عشوائية'
                                : '⚠️ No theme — generating random phrases')
                        : null,
                    helperStyle: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12),
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
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onPrimary,
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
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                allMemorized ? Icons.emoji_events : Icons.auto_awesome,
                color: allMemorized
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.primary,
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
                  color: allMemorized
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.primary,
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
              // Derive saved-state from the actual database, keyed by phrase text —
              // NOT by list position. Prevents stale per-index state from disabling
              // the button for never-saved phrases.
              final isSaved = wordProvider.words.any(
                (w) => w.word == phrase.phrase && w.translation.isNotEmpty,
              );
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                color: phrase.memorized
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
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
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outlineVariant,
                        ),
                        child: Icon(
                          phrase.memorized ? Icons.check : Icons.circle_outlined,
                          color: phrase.memorized
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurface,
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
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : Theme.of(context).colorScheme.primary),
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
                            color: phrase.memorized
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: isSaved
                            ? (s.locale == 'de' ? 'Gespeichert ✅' : s.locale == 'ar' ? 'تم الحفظ ✅' : 'Saved ✅')
                            : s.saveToWords,
                        child: IconButton(
                          icon: Icon(
                            isSaved ? Icons.bookmark_added : Icons.bookmark_add_outlined,
                            size: 20,
                            color: isSaved
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                          onPressed: isSaved ? null : () => _saveToMyWords(index),
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
                              color: Theme.of(context).colorScheme.primary, size: 20),
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
