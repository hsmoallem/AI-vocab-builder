import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
        'max_tokens': 300,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('DeepSeek API error: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body);
    final content = data['choices'][0]['message']['content'] as String;

    // Parse the JSON from DeepSeek's response
    return TranslationResult.fromJson(content.trim(), word);
  }

  String _buildPrompt(String word, String sourceLang, String targetLang) {
    final sourceName = _langName(sourceLang);
    final targetName = _langName(targetLang);

    return '''Translate the word "$word" from $sourceName to $targetName.
Return ONLY a JSON object (no other text) with these fields:
{
  "translation": "the translated word",
  "example_sentence_source": "a natural example sentence using '$word' in $sourceName",
  "example_sentence_target": "the natural English translation of the example sentence"
}''';
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

class TranslationResult {
  final String translation;
  final String exampleSource;
  final String exampleTarget;

  TranslationResult({
    required this.translation,
    required this.exampleSource,
    required this.exampleTarget,
  });

  factory TranslationResult.fromJson(String rawJson, String word) {
    try {
      // Clean up: remove markdown code blocks if present
      String jsonStr = rawJson.trim();
      if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.replaceFirst(RegExp(r'```\w*\n?'), '');
        jsonStr = jsonStr.replaceFirst('```', '');
      }

      final map = jsonDecode(jsonStr);
      return TranslationResult(
        translation: map['translation'] ?? '',
        exampleSource: map['example_sentence_source'] ?? '',
        exampleTarget: map['example_sentence_target'] ?? '',
      );
    } catch (e) {
      // If JSON parsing fails, return whatever we got as translation
      return TranslationResult(
        translation: rawJson,
        exampleSource: '',
        exampleTarget: '',
      );
    }
  }
}
