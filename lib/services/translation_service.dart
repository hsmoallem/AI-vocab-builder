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
///   - Requests go over HTTPS through Cloudflare (api.houssammoallem.com)
///   - Signed-in requests carry a verified Firebase ID token
///     (Authorization: Bearer …); the legacy X-App-Token is only a fallback
///     for signed-out / local-only sessions
///   - The server enforces per-IP / per-UID rate limiting
///
/// ## Base URL
///   - Change _baseUrl if the proxy moves to a different host/domain

import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class TranslationService {
  static const String _baseUrl = 'http://13.140.134.57:9000/translate';
  static const String _appToken = 'vocab-builder-shared-secret-2026';
  static const String _defaultSourceLang = 'de';
  static const String _defaultTargetLang = 'en';

  /// Request headers. Prefer a verified Firebase ID token
  /// (Authorization: Bearer …); fall back to the legacy shared token when no
  /// user is signed in (or Firebase is unavailable) so translation still works.
  Future<Map<String, String>> _authHeaders() async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
        return headers;
      }
    } catch (_) {
      // fall through to the legacy token
    }
    headers['X-App-Token'] = _appToken;
    return headers;
  }

  /// Translate a word/phrase with multi-meaning support.
  Future<TranslationResult> translate({
    required String word,
    String sourceLang = _defaultSourceLang,
    String targetLang = _defaultTargetLang,
    String? firebaseUid,
  }) async {
    final body = <String, dynamic>{
      'word': word,
      'sourceLang': sourceLang,
      'targetLang': targetLang,
      'mode': 'translate',
    };
    if (firebaseUid != null) body['firebaseUid'] = firebaseUid;
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: await _authHeaders(),
      body: jsonEncode(body),
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
    String? firebaseUid,
    List<String>? exclude,
  }) async {
    final body = <String, dynamic>{
      'sourceLang': lang,
      'targetLang': lang,  // not used for phrases; mode=phrases ignores it
      'mode': 'phrases',
    };
    if (firebaseUid != null) body['firebaseUid'] = firebaseUid;
    if (theme != null && theme.trim().isNotEmpty) {
      body['theme'] = theme.trim();
    }
    // Phrases the server should NOT repeat (already shown/blocked). The proxy
    // injects these into the prompt to force fresh, non-duplicate phrases.
    if (exclude != null && exclude.isNotEmpty) {
      body['exclude'] = exclude.take(40).toList();
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
  // Corrected spelling of the source word, if the server provides one.
  final String? corrected;

  TranslationResult({required this.meanings, this.corrected});

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
    // Optional corrected spelling of the source word (server may include it).
    final corrected = map['corrected']?.toString();
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
        return TranslationResult(meanings: meanings, corrected: corrected);
      }
    }
    // Fallback
    return TranslationResult(meanings: [
      Meaning(text: map.toString(), exampleSource: '', exampleTarget: ''),
    ], corrected: corrected);
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
