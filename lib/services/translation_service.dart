/// ─── Translation Service — Proxy to DeepSeek ──────────────────────
///
/// Handles all AI-powered features:
///   1. Word translation with multiple meanings
///   2. Daily phrase generation
///
/// ## API key safety
///   - The DeepSeek key lives on a proxy server, never in the APK
///   - App sends only {word, sourceLang, targetLang, mode} — no prompts or models
///   - Prompt building happens server-side, so the proxy is not an open LLM relay
///   - X-App-Token is a shared secret (speed bump — extractable from APK)
///   - The server enforces per-IP rate limiting
///
/// ## Base URL
///   - Change _baseUrl if the proxy moves to a different host/domain

import 'dart:convert';
import 'package:http/http.dart' as http;

class TranslationService {
  static const String _baseUrl = 'http://13.140.134.57:9000/translate';
  static const String _appToken = 'vocab-builder-shared-secret-2026';
  static const String _defaultSourceLang = 'de';
  static const String _defaultTargetLang = 'en';

  /// Translate a word/phrase with multi-meaning support.
  Future<TranslationResult> translate({
    required String word,
    String sourceLang = _defaultSourceLang,
    String targetLang = _defaultTargetLang,
  }) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'X-App-Token': _appToken,
      },
      body: jsonEncode({
        'word': word,
        'sourceLang': sourceLang,
        'targetLang': targetLang,
        'mode': 'translate',
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      final msg = _friendlyError(response.statusCode, response.body);
      throw Exception(msg);
    }

    final data = jsonDecode(response.body);
    return TranslationResult.fromMeanings(data);
  }

  /// Generate 5 daily-life phrases in the given language.
  Future<List<DailyPhrase>> generateDailyPhrases({
    String lang = 'de',
    String? theme,
  }) async {
    final body = <String, dynamic>{
      'sourceLang': lang,
      'targetLang': lang,  // not used for phrases; mode=phrases ignores it
      'mode': 'phrases',
    };
    if (theme != null && theme.trim().isNotEmpty) {
      body['theme'] = theme.trim();
    }

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'X-App-Token': _appToken,
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      final msg = _friendlyError(response.statusCode, response.body);
      throw Exception(msg);
    }

    final data = jsonDecode(response.body);
    final phrases = List<String>.from(data['phrases'] ?? []);
    return phrases.map((p) => DailyPhrase(phrase: p)).toList();
  }

  /// Map HTTP errors to user-friendly messages.
  String _friendlyError(int statusCode, String body) {
    if (statusCode == 503 || statusCode == 502) {
      return 'Translation server unavailable — try again in a moment';
    }
    if (statusCode == 429) {
      return 'Too many requests — please wait a moment';
    }
    return 'Translation failed (code $statusCode)';
  }
}

/// A single meaning with its own example.
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

/// Result from DeepSeek translation — contains one or more meanings.
class TranslationResult {
  final List<Meaning> meanings;

  TranslationResult({required this.meanings});

  String get translation => meanings.map((m) => m.text).join(', ');

  String get exampleSource {
    if (meanings.length == 1) return meanings.first.exampleSource;
    return meanings.asMap().entries
        .map((e) => '${e.key + 1}. ${e.value.exampleSource}')
        .join('\n');
  }

  String get exampleTarget {
    if (meanings.length == 1) return meanings.first.exampleTarget;
    return meanings.asMap().entries
        .map((e) => '${e.key + 1}. ${e.value.exampleTarget}')
        .join('\n');
  }

  /// Parse from the proxy's JSON response — proxy returns parsed JSON directly.
  factory TranslationResult.fromMeanings(Map<String, dynamic> map) {
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
    // Fallback
    return TranslationResult(meanings: [
      Meaning(text: map.toString(), exampleSource: '', exampleTarget: ''),
    ]);
  }
}

/// Daily phrase — generated fresh each day by the AI.
class DailyPhrase {
  final String phrase;
  bool memorized;

  DailyPhrase({required this.phrase, this.memorized = false});

  Map<String, dynamic> toJson() => {'phrase': phrase, 'memorized': memorized};

  factory DailyPhrase.fromJson(Map<String, dynamic> json) =>
      DailyPhrase(
          phrase: json['phrase'] as String,
          memorized: json['memorized'] == true);
}
