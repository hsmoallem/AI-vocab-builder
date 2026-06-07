/// ─── Translation Service — DeepSeek AI ──────────────────────────────
///
/// Handles all AI-powered features:
///   1. Word translation with multiple meanings
///   2. Daily phrase generation
///
/// ## Why DeepSeek
///   - $0.14 per million input tokens — cheapest viable LLM for translation
///   - `deepseek-chat` model is instruction-tuned and reliably returns JSON
///   - API is OpenAI-compatible, so we can swap to OpenAI/Groq with minimal changes
///   - No rate limits hit during development with single-user usage
///
/// ## Prompt engineering
///   - System message sets the role: "professional translator" or "language teacher"
///   - User message provides the word + language pair + exact JSON format
///   - Temperature 0.3 for translation (precise), 0.7 for daily phrases (variety)
///   - `max_tokens: 800` gives room for multi-meaning responses with examples
///
/// ## API key management
///   - Falls back to AppConfig.deepseekApiKey if no key in shared_preferences
///   - setApiKey() saves to shared_preferences (future Settings screen)

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class TranslationService {
  static const String _apiKeyKey = 'deepseek_api_key';
  static const String _baseUrl = 'https://api.deepseek.com/v1/chat/completions';
  static const String _defaultSourceLang = 'de';
  static const String _defaultTargetLang = 'en';

  String? _apiKey;

  /// Save a user-provided API key to shared_preferences.
  Future<void> setApiKey(String key) async {
    _apiKey = key;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyKey, key);
  }

  /// Get the API key — checks memory, then shared_preferences,
  /// then falls back to the embedded key in AppConfig.
  Future<String?> getApiKey() async {
    if (_apiKey != null) return _apiKey;
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString(_apiKeyKey);
    // Fall back to the embedded key from config
    _apiKey ??= AppConfig.deepseekApiKey;
    return _apiKey;
  }

  /// Check if any API key is configured.
  Future<bool> isConfigured() async {
    final key = await getApiKey();
    return key != null && key.isNotEmpty;
  }

  /// Translate a word/phrase with multi-meaning support.
  ///
  /// The prompt instructs DeepSeek to return ALL distinct meanings
  /// with separate example sentences for each. German nouns get
  /// automatic article detection (der/die/das).
  Future<TranslationResult> translate({
    required String word,
    String sourceLang = _defaultSourceLang,
    String targetLang = _defaultTargetLang,
  }) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('DeepSeek API key not configured. Add it in Settings.');
    }

    final prompt = _buildPrompt(word, sourceLang, targetLang);

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'deepseek-chat',
        'messages': [
          {
            'role': 'system',
            'content': 'You are a professional translator. Always respond with valid JSON only, no other text.',
          },
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        'temperature': 0.3,  // Low temp for consistent, accurate translations
        'max_tokens': 800,    // Enough space for multiple meanings + examples
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('DeepSeek API error: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body);
    final content = data['choices'][0]['message']['content'] as String;

    return TranslationResult.fromJson(content.trim());
  }

  /// Build the translation prompt with language names.
  String _buildPrompt(String word, String sourceLang, String targetLang) {
    final sourceName = _langName(sourceLang);
    final targetName = _langName(targetLang);

    return '''Translate the word/phrase "$word" from $sourceName to $targetName.

IMPORTANT: If this word has MULTIPLE distinct meanings, include ALL of them as separate items in the array. Each meaning MUST have its own example sentence that demonstrates THAT specific meaning.

For GERMAN nouns: ALWAYS include the correct article (der/die/das) in the "article" field.

Return ONLY a JSON object (no other text) with this format:
{
  "meanings": [
    {
      "meaning": "first meaning in $targetName",
      "article": "der/die/das (only for German nouns, otherwise omit)",
      "example_source": "example sentence using '$word' with this specific meaning in $sourceName",
      "example_target": "natural $targetName translation of the example"
    },
    {
      "meaning": "second meaning in $targetName",
      "article": "der/die/das (only for German nouns, otherwise omit)",
      "example_source": "example sentence using '$word' with this specific meaning in $sourceName",
      "example_target": "natural $targetName translation of the example"
    }
  ]
}''';
  }

  /// Generate 5 daily-life phrases in the given language.
  ///
  /// Used by the Daily Phrases screen. Phrases are practical,
  /// everyday expressions from different situations.
  /// Temperature 0.7 adds variety — each day feels fresh.
  Future<List<DailyPhrase>> generateDailyPhrases({
    String lang = 'de',
    String? theme,
  }) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('DeepSeek API key not configured.');
    }

    final langName = _langName(lang);
    final themeLine = (theme != null && theme.trim().isNotEmpty)
        ? 'Focus ALL 5 phrases on the theme: "${theme.trim()}". '
        : '';

    final prompt = '''Generate 5 useful everyday phrases in $langName that a learner should memorize.
${themeLine}Pick phrases from different daily situations (greetings, shopping, dining, directions, small talk, emergencies, transport, etc.).
Choose phrases that are practical and commonly needed — not textbook clichés.
Return ONLY a JSON object (no other text):
{
  "phrases": ["phrase 1", "phrase 2", "phrase 3", "phrase 4", "phrase 5"]
}''';

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'deepseek-chat',
        'messages': [
          {
            'role': 'system',
            'content': 'You are a language teacher. Respond with valid JSON only.',
          },
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        'temperature': 0.7,  // Higher temp for daily variety
        'max_tokens': 300,    // 5 short phrases need less tokens
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('DeepSeek API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final content = data['choices'][0]['message']['content'] as String;

    // Parse JSON — clean markdown fences if DeepSeek wraps in ```json```
    String jsonStr = content.trim();
    if (jsonStr.startsWith('```')) {
      jsonStr = jsonStr.replaceFirst(RegExp(r'```\w*\n?'), '');
      jsonStr = jsonStr.replaceFirst('```', '');
    }

    final map = jsonDecode(jsonStr);
    final phrases = List<String>.from(map['phrases'] ?? []);

    return phrases.map((p) => DailyPhrase(phrase: p)).toList();
  }

  /// Map language codes to human-readable names for the AI prompt.
  String _langName(String code) {
    const names = {
      'de': 'German', 'en': 'English', 'fr': 'French', 'es': 'Spanish',
      'it': 'Italian', 'pt': 'Portuguese', 'ru': 'Russian', 'zh': 'Chinese',
      'ja': 'Japanese', 'ko': 'Korean', 'ar': 'Arabic', 'tr': 'Turkish',
      'nl': 'Dutch', 'pl': 'Polish', 'sv': 'Swedish', 'no': 'Norwegian',
      'da': 'Danish', 'fi': 'Finnish', 'cs': 'Czech', 'hu': 'Hungarian',
      'ro': 'Romanian', 'bg': 'Bulgarian', 'el': 'Greek', 'he': 'Hebrew',
      'hi': 'Hindi', 'th': 'Thai', 'vi': 'Vietnamese', 'id': 'Indonesian',
      'ms': 'Malay', 'uk': 'Ukrainian',
    };
    return names[code] ?? code.toUpperCase();
  }
}

/// A single meaning with its own example.
///
/// Used by the multi-meaning translation feature.
/// `article` is optional — only populated for German nouns.
class Meaning {
  final String text;
  final String? article;          // der/die/das for German nouns, null otherwise
  final String exampleSource;     // Example in the source language
  final String exampleTarget;     // Example translated to target language

  Meaning({
    required this.text,
    this.article,
    required this.exampleSource,
    required this.exampleTarget,
  });
}

/// Result from DeepSeek translation — contains one or more meanings.
///
/// ## Why a list of meanings instead of a single translation
/// German words like "Bank" (bench / bank) or "Schloss" (castle / lock)
/// have completely different meanings. Showing all of them with separate
/// examples helps the learner understand context.
class TranslationResult {
  final List<Meaning> meanings;

  TranslationResult({required this.meanings});

  /// Combined translation string — all meanings joined with commas.
  String get translation => meanings.map((m) => m.text).join(', ');

  /// Combined examples in source language.
  /// Single meaning: just the example. Multiple: numbered list.
  String get exampleSource {
    if (meanings.length == 1) return meanings.first.exampleSource;
    return meanings.asMap().entries.map((e) =>
        '${e.key + 1}. ${e.value.exampleSource}'
    ).join('\n');
  }

  /// Combined examples in target language (translated).
  String get exampleTarget {
    if (meanings.length == 1) return meanings.first.exampleTarget;
    return meanings.asMap().entries.map((e) =>
        '${e.key + 1}. ${e.value.exampleTarget}'
    ).join('\n');
  }

  /// Parse the JSON response from DeepSeek.
  ///
  /// Handles three response formats:
  ///   1. Modern format: {"meanings": [{...}, {...}]}  ← preferred
  ///   2. Legacy format: {"translation": "...", "example_sentence_source": "..."}
  ///   3. Raw text: all JSON parsing failed → returned as single meaning
  factory TranslationResult.fromJson(String rawJson) {
    try {
      // Strip markdown code fences if DeepSeek wraps the JSON
      String jsonStr = rawJson.trim();
      if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.replaceFirst(RegExp(r'```\w*\n?'), '');
        jsonStr = jsonStr.replaceFirst('```', '');
      }

      final map = jsonDecode(jsonStr);

      // Modern multi-meaning format
      if (map['meanings'] is List) {
        final meanings = (map['meanings'] as List).map((m) {
          final article = m['article']?.toString();
          return Meaning(
            text: m['meaning']?.toString() ?? '',
            article: (article != null && article.isNotEmpty) ? article : null,
            exampleSource: m['example_source']?.toString() ?? '',
            exampleTarget: m['example_target']?.toString() ?? '',
          );
        }).toList();

        if (meanings.isNotEmpty) {
          return TranslationResult(meanings: meanings);
        }
      }

      // Fallback: legacy single-meaning format
      final single = Meaning(
        text: map['translation']?.toString() ?? rawJson,
        exampleSource: map['example_sentence_source']?.toString() ?? '',
        exampleTarget: map['example_sentence_target']?.toString() ?? '',
      );
      return TranslationResult(meanings: [single]);
    } catch (e) {
      // Ultimate fallback: raw text as single meaning
      return TranslationResult(meanings: [
        Meaning(text: rawJson, exampleSource: '', exampleTarget: ''),
      ]);
    }
  }
}

/// Daily phrase — generated fresh each day by the AI.
///
/// Stored in shared_preferences (not the database) because phrases
/// reset daily — no value in persisting old ones permanently.
class DailyPhrase {
  final String phrase;
  bool memorized;   // Toggled by the user in the Daily Phrases screen

  DailyPhrase({required this.phrase, this.memorized = false});

  /// Serialize to JSON for shared_preferences storage.
  Map<String, dynamic> toJson() => {'phrase': phrase, 'memorized': memorized};

  /// Deserialize from shared_preferences JSON.
  factory DailyPhrase.fromJson(Map<String, dynamic> json) =>
      DailyPhrase(phrase: json['phrase'] as String, memorized: json['memorized'] == true);
}
