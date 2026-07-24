import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/firebase_service.dart';
import '../../config/app_strings.dart';
import '../../providers/locale_provider.dart';
import '../../providers/word_provider.dart';
import '../../services/translation_service.dart';
import '../../utils/clipboard_util.dart';
import '../../services/tts_service.dart';
import '../../widgets/cefr_level_dropdown.dart';
import '../../widgets/searchable_dropdown.dart';
import '../../widgets/web_top_bar.dart';

class WebDailyPhrasesScreen extends StatefulWidget {
  const WebDailyPhrasesScreen({super.key});

  @override
  State<WebDailyPhrasesScreen> createState() => _WebDailyPhrasesScreenState();
}

class _WebDailyPhrasesScreenState extends State<WebDailyPhrasesScreen> {
  final TranslationService _translator = TranslationService();
  final TtsService _tts = TtsService();
  final _themeCtrl = TextEditingController();

  List<DailyPhrase>? _phrases;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;
  String _phraseLang = 'de';
  List<String> _blockedPhrases = [];
  String? _level;
  bool _showThemeWarning = false;
  SharedPreferences? _prefs;

  static const _dateKey = 'daily_phrases_date';
  static const _phrasesKey = 'daily_phrases_data';
  static const _phraseLangKey = 'daily_phrase_language';
  static const _legacyLangKey = 'daily_phrases_lang';
  static const _savedKey = 'daily_phrases_saved';
  static const _blockedKey = 'daily_phrases_blocked';

  String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

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
      _phraseLang = _prefs!.getString(_phraseLangKey) ?? _prefs!.getString(_legacyLangKey) ?? 'de';

      final blockedJson = _prefs!.getString(_blockedKey);
      if (blockedJson != null && blockedJson.isNotEmpty) {
        _blockedPhrases = List<String>.from(jsonDecode(blockedJson));
      }

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
          _phrases!.removeWhere((p) => _blockedPhrases.any((b) => b.trim().toLowerCase() == p.phrase.trim().toLowerCase()));
          _isLoading = false;
          setState(() {});
          return;
        }
      }

      final uid = FirebaseService.instance.currentUser?.uid;
      List<DailyPhrase> phrases = [];
      final seen = <String>{..._blockedPhrases, ...?_phrases?.map((p) => p.phrase)};
      for (int attempt = 0; attempt < 3; attempt++) {
        final batch = await _translator.generateDailyPhrases(
          lang: _phraseLang,
          theme: theme,
          firebaseUid: uid,
          level: _level,
          exclude: [...seen, ...phrases.map((p) => p.phrase)],
        );
        phrases.addAll(batch.where((p) => !_blockedPhrases.any((b) => b.trim().toLowerCase() == p.phrase.trim().toLowerCase())));
        if (phrases.length >= 5) break;
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
    await prefs.setString(_phrasesKey, jsonEncode(_phrases!.map((p) => p.toJson()).toList()));
    await prefs.setString(_savedKey, jsonEncode(_savedIndices.toList()));
  }



  Future<void> _saveToMyWords(int index) async {
    final phrase = _phrases![index];
    final provider = context.read<WordProvider>();
    final localeProvider = context.read<LocaleProvider>();
    final targetLang = localeProvider.targetLang;
    final s = AppStrings(localeProvider.locale);

    for (final w in provider.words) {
      if (w.word == phrase.phrase && w.translation.isNotEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.locale == 'de' ? 'Bereits gespeichert' : 'Already saved'), backgroundColor: Theme.of(context).colorScheme.primary));
        setState(() => _savedIndices.add(index));
        return;
      }
    }

    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Translating & saving...'), duration: Duration(seconds: 3)));

    try {
      final result = await _translator.translate(
        word: phrase.phrase,
        sourceLang: _phraseLang,
        targetLang: targetLang,
        firebaseUid: FirebaseService.instance.currentUser?.uid,
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

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ ${phrase.phrase} saved'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 5)));
    }
  }

  void _onPhraseLanguageChanged(String lang) async {
    if (lang == _phraseLang) return;
    _phraseLang = lang;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setString(_phraseLangKey, lang);
    if (mounted) {
      setState(() => _isRefreshing = true);
      _loadPhrases(forceRefresh: true);
    }
  }

  void _blockPhrase(DailyPhrase phrase) async {
    _blockedPhrases.add(phrase.phrase);
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setString(_blockedKey, jsonEncode(_blockedPhrases));
    if (mounted) {
      setState(() {
        _phrases!.removeWhere((p) => p.phrase.trim().toLowerCase() == phrase.phrase.trim().toLowerCase());
      });
    }
    _saveToPrefs();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final wordProvider = context.watch<WordProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(s.tabDaily),
        actions: WebTopBar.buildActions(context),
      ),
      body: _buildBody(theme, s, wordProvider),
    );
  }

  Widget _buildBody(ThemeData theme, AppStrings s, WordProvider wordProvider) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 64, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: _loadPhrases, icon: const Icon(Icons.refresh), label: Text(s.retry)),
          ],
        ),
      );
    }


    final loc = context.watch<LocaleProvider>();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Language Selector
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.translate, size: 20, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SearchableDropdown<String>(
                        value: AppStrings.targetLanguages.containsKey(_phraseLang) ? _phraseLang : 'de',
                        labelText: '',
                        hideUnderline: true,
                        items: AppStrings.targetLanguages.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                        itemAsString: (key) => AppStrings.targetLanguages[key] ?? key,
                        onChanged: (v) { if (v != null) _onPhraseLanguageChanged(v); },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Level Selector
              Expanded(
                child: CefrLevelDropdown(
                  value: _level,
                  onChanged: (v) => setState(() => _level = v),
                ),
              ),
            ],
          ),
          if (loc.targetLang == _phraseLang) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: theme.colorScheme.errorContainer.withOpacity(0.6), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: theme.colorScheme.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Phrase and translation language are the same — translation won\'t be useful.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onErrorContainer))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _themeCtrl,
                  onSubmitted: (_) => _generateNew(),
                  decoration: InputDecoration(
                    hintText: s.themeHint,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.topic),
                    errorText: _showThemeWarning ? '⚠️ No theme — generating random phrases' : null,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFDB2777), Color(0xFFBE185D)], // accent-600 to accent-700
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFDB2777).withOpacity(0.2), // shadow-brand-500/20
                      blurRadius: 6,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: FilledButton.icon(
                  onPressed: _isRefreshing ? null : _generateNew,
                  icon: _isRefreshing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.auto_awesome, color: Colors.white),
                  label: const Text('Generate Phrases', style: TextStyle(color: Colors.white)),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          const SizedBox(height: 24),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 450,
                crossAxisSpacing: 24,
                mainAxisSpacing: 24,
                childAspectRatio: 1.3,
              ),
              itemCount: _phrases!.length,
              itemBuilder: (context, index) {
                final phrase = _phrases![index];
                final isSaved = wordProvider.words.any((w) => w.word == phrase.phrase && w.translation.isNotEmpty);
                
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xCCE2E8F0)), // border-slate-200/80
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('Phrase ${index + 1}', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSecondaryContainer)),
                            ),
                            Tooltip(
                              message: 'Never show again',
                              child: IconButton(
                                icon: Icon(Icons.visibility_off_outlined, size: 18, color: theme.colorScheme.error.withOpacity(0.7)),
                                onPressed: () => _blockPhrase(phrase),
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: Text(
                            phrase.phrase,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.start,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _tts.speak(phrase.phrase, language: _phraseLang),
                              icon: const Icon(Icons.volume_up, size: 18),
                              label: const Text('Listen'),
                            ),
                            Tooltip(
                              message: 'Copy',
                              child: IconButton.outlined(
                                onPressed: () => copyToClipboard(context, phrase.phrase),
                                icon: const Icon(Icons.copy, size: 18),
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: isSaved ? null : () => _saveToMyWords(index),
                              icon: Icon(isSaved ? Icons.bookmark_added : Icons.bookmark_add, size: 18),
                              label: Text(isSaved ? 'Saved' : 'Save'),
                              style: isSaved ? FilledButton.styleFrom(backgroundColor: theme.colorScheme.primaryContainer, foregroundColor: theme.colorScheme.onPrimaryContainer) : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
