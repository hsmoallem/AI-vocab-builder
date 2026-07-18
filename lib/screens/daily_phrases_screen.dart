import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_strings.dart';
import '../providers/locale_provider.dart';
import '../providers/word_provider.dart';
import '../services/translation_service.dart';
import '../utils/clipboard_util.dart';
import '../services/tts_service.dart';
import '../widgets/cefr_level_dropdown.dart';

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
  String _phraseLang = 'de';          // language phrases are generated in
  List<String> _blockedPhrases = [];   // phrases the user never wants to see again
  String? _level;                     // CEFR level (null = auto)
  bool _showThemeWarning = false;
  SharedPreferences? _prefs;

  static const _dateKey = 'daily_phrases_date';
  static const _phrasesKey = 'daily_phrases_data';
  static const _phraseLangKey = 'daily_phrase_language';  // new key
  static const _legacyLangKey = 'daily_phrases_lang';     // old fallback key
  static const _savedKey = 'daily_phrases_saved';
  static const _blockedKey = 'daily_phrases_blocked';

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
      // Read phrase language — new key first, fall back to legacy key, default 'de'
      _phraseLang = _prefs!.getString(_phraseLangKey)
          ?? _prefs!.getString(_legacyLangKey)
          ?? 'de';

      // Load blocked phrases list
      final blockedJson = _prefs!.getString(_blockedKey);
      if (blockedJson != null && blockedJson.isNotEmpty) {
        _blockedPhrases = List<String>.from(jsonDecode(blockedJson));
      }

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
          // Filter out blocked phrases from cached data
          _phrases!.removeWhere(
            (p) => _blockedPhrases.any(
              (b) => b.trim().toLowerCase() == p.phrase.trim().toLowerCase(),
            ),
          );
          _isLoading = false;
          setState(() {});
          return;
        }
      }

      // Generate phrases, filter blocked ones, retry if < 5 (max 3 attempts)
      final uid = FirebaseAuth.instance.currentUser?.uid;
      List<DailyPhrase> phrases = [];
      // Tell the server which phrases NOT to repeat: blocked ones, the batch
      // currently on screen, and anything gathered so far this run.
      final seen = <String>{
        ..._blockedPhrases,
        ...?_phrases?.map((p) => p.phrase),
      };
      for (int attempt = 0; attempt < 3; attempt++) {
        final batch = await _translator.generateDailyPhrases(
          lang: _phraseLang,
          theme: theme,
          firebaseUid: uid,
          level: _level,
          exclude: [...seen, ...phrases.map((p) => p.phrase)],
        );
        // Filter out blocked phrases (case-insensitive, trimmed)
        phrases.addAll(batch.where(
          (p) => !_blockedPhrases.any(
            (b) => b.trim().toLowerCase() == p.phrase.trim().toLowerCase(),
          ),
        ));
        if (phrases.length >= 5) break;
        // Pause between retries so the AI gets a different seed
        await Future.delayed(const Duration(milliseconds: 600));
      }
      _phrases = phrases.take(5).toList();
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
    await prefs.setString(_phraseLangKey, _phraseLang);
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
      final result = await _translator.translate(
        word: phrase.phrase,
        sourceLang: _phraseLang,
        targetLang: targetLang,
        firebaseUid: FirebaseAuth.instance.currentUser?.uid,
      );
      final m = result.meanings.isNotEmpty ? result.meanings.first : Meaning(text: phrase.phrase, article: null, exampleSource: '', exampleTarget: '');

      await provider.addWord(
        word: phrase.phrase,
        translation: m.text,
        exampleSource: m.exampleSource,
        exampleTarget: m.exampleTarget,
        sourceLang: _phraseLang,
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

  void _onPhraseLanguageChanged(String lang) async {
    if (lang == _phraseLang) return;
    _phraseLang = lang;
    // Persist immediately even before regenerate
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setString(_phraseLangKey, lang);
    // Force regenerate with the new language
    if (mounted) {
      setState(() => _isRefreshing = true);
      _loadPhrases(forceRefresh: true);
    }
  }

  /// Block a phrase forever — add to blocked list, persist, remove from view.
  void _blockPhrase(DailyPhrase phrase) async {
    _blockedPhrases.add(phrase.phrase);
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setString(_blockedKey, jsonEncode(_blockedPhrases));
    if (mounted) {
      setState(() {
        _phrases!.removeWhere(
          (p) => p.phrase.trim().toLowerCase() == phrase.phrase.trim().toLowerCase(),
        );
      });
    }
    _saveToPrefs(); // update the cache so blocked phrase stays gone
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
        // ── Phrase language dropdown ──────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Icon(Icons.translate, size: 18,
                  color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                s.locale == 'de' ? 'Phrasen-Sprache:' : s.locale == 'ar' ? 'لغة العبارات:' : 'Phrase language:',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: AppStrings.targetLanguages.containsKey(_phraseLang)
                        ? _phraseLang
                        : 'de',
                    isDense: true,
                    isExpanded: true,
                    style: theme.textTheme.bodyMedium,
                    items: AppStrings.targetLanguages.entries
                        .map((e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value, style: const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) _onPhraseLanguageChanged(v);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        // ── CEFR Level ────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: CefrLevelDropdown(
            value: _level,
            onChanged: (v) => setState(() => _level = v),
            compact: true,
          ),
        ),
        // ── Same-language warning ─────────────────────────────
        // Watch the LocaleProvider so we redraw when the translate-to
        // language changes and we need to show/hide the warning.
        Builder(
          builder: (context) {
            final loc = context.watch<LocaleProvider>();
            if (loc.targetLang == _phraseLang) {
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16,
                        color: theme.colorScheme.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.locale == 'de'
                            ? 'Phrasen-Sprache und Übersetzungs-Sprache sind gleich — Übersetzung nicht sinnvoll.'
                            : s.locale == 'ar'
                                ? 'لغة العبارات ولغة الترجمة متطابقتان — الترجمة غير مفيدة.'
                                : 'Phrase and translation language are the same — translation won\'t be useful.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
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
                            : () => _tts.speak(phrase.phrase, language: _phraseLang),
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
                        message: s.locale == 'de'
                            ? 'Kopieren'
                            : s.locale == 'ar'
                                ? 'نسخ'
                                : 'Copy',
                        child: IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: () => copyToClipboard(context, phrase.phrase),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 28, minHeight: 28),
                        ),
                      ),
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
                      Tooltip(
                        message: s.locale == 'de'
                            ? 'Nie wieder anzeigen'
                            : s.locale == 'ar'
                                ? 'لا تعرض مرة أخرى'
                                : 'Never show again',
                        child: IconButton(
                          icon: Icon(
                            Icons.visibility_off_outlined,
                            size: 18,
                            color: Theme.of(context).colorScheme.error.withOpacity(0.7),
                          ),
                          onPressed: () => _blockPhrase(phrase),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 28, minHeight: 28),
                        ),
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
