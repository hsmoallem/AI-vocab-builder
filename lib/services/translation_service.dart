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

  Future<void> setApiKey(String key) async {
    _apiKey = key;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyKey, key);
  }

  Future<String?> getApiKey() async {
    if (_apiKey != null) return _apiKey;
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString(_apiKeyKey);
    _apiKey ??= AppConfig.deepseekApiKey;
    return _apiKey;
  }

  Future<bool> isConfigured() async {
    final key = await getApiKey();
    return key != null && key.isNotEmpty;
  }

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
        'temperature': 0.3,
        'max_tokens': 800,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('DeepSeek API error: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body);
    final content = data['choices'][0]['message']['content'] as String;

    return TranslationResult.fromJson(content.trim());
  }

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
  /// Returns a list of {phrase, memorized: false}.
  Future<List<DailyPhrase>> generateDailyPhrases({String lang = 'de'}) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('DeepSeek API key not configured.');
    }

    final langName = _langName(lang);

    final prompt = '''Generate 5 useful everyday phrases in $langName that a learner should memorize.
Pick phrases from different daily situations (greetings, shopping, dining, directions, small talk, emergencies, transport, etc.).
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
        'temperature': 0.7,
        'max_tokens': 300,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('DeepSeek API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final content = data['choices'][0]['message']['content'] as String;

    // Parse JSON — clean markdown fences if present
    String jsonStr = content.trim();
    if (jsonStr.startsWith('```')) {
      jsonStr = jsonStr.replaceFirst(RegExp(r'```\w*\n?'), '');
      jsonStr = jsonStr.replaceFirst('```', '');
    }

    final map = jsonDecode(jsonStr);
    final phrases = List<String>.from(map['phrases'] ?? []);

    return phrases.map((p) => DailyPhrase(phrase: p)).toList();
  }

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

/// A single meaning with its own example
class Meaning {
  final String text;
  final String? article;
  final String exampleSource;
  final String exampleTarget;

  Meaning({
    required this.text,
    this.article,
    required this.exampleSource,
    required this.exampleTarget,
  });
}

/// Result from DeepSeek translation
class TranslationResult {
  final List<Meaning> meanings;

  TranslationResult({required this.meanings});

  /// Combined translation string (all meanings joined)
  String get translation => meanings.map((m) => m.text).join(', ');

  /// Combined examples (source)
  String get exampleSource {
    if (meanings.length == 1) return meanings.first.exampleSource;
    return meanings.asMap().entries.map((e) =>
        '${e.key + 1}. ${e.value.exampleSource}'
    ).join('\n');
  }

  /// Combined examples (target)
  String get exampleTarget {
    if (meanings.length == 1) return meanings.first.exampleTarget;
    return meanings.asMap().entries.map((e) =>
        '${e.key + 1}. ${e.value.exampleTarget}'
    ).join('\n');
  }

  factory TranslationResult.fromJson(String rawJson) {
    try {
      String jsonStr = rawJson.trim();
      if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.replaceFirst(RegExp(r'```\w*\n?'), '');
        jsonStr = jsonStr.replaceFirst('```', '');
      }

      final map = jsonDecode(jsonStr);

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

      // Fallback: single meaning from old format
      final single = Meaning(
        text: map['translation']?.toString() ?? rawJson,
        exampleSource: map['example_sentence_source']?.toString() ?? '',
        exampleTarget: map['example_sentence_target']?.toString() ?? '',
      );
      return TranslationResult(meanings: [single]);
    } catch (e) {
      return TranslationResult(meanings: [
        Meaning(text: rawJson, exampleSource: '', exampleTarget: ''),
      ]);
    }
  }
}

/// Daily phrase — generated fresh each day
class DailyPhrase {
  final String phrase;
  bool memorized;

  DailyPhrase({required this.phrase, this.memorized = false});

  Map<String, dynamic> toJson() => {'phrase': phrase, 'memorized': memorized};
  factory DailyPhrase.fromJson(Map<String, dynamic> json) =>
      DailyPhrase(phrase: json['phrase'] as String, memorized: json['memorized'] == true);
}
