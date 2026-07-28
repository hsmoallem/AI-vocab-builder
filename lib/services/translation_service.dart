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
import 'package:http/http.dart' as http;
import 'firebase_service.dart';

class TranslationService {
  static const String _baseUrl = 'https://api.houssammoallem.com/translate';
  static const String _appToken = 'vocab-builder-shared-secret-2026';
  static const String _defaultSourceLang = 'de';
  static const String _defaultTargetLang = 'en';

  /// Request headers. Prefer a verified Firebase ID token
  /// (Authorization: Bearer …); fall back to the legacy shared token when no
  /// user is signed in (or Firebase is unavailable) so translation still works.
  Future<Map<String, String>> _authHeaders() async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    try {
      final token = await FirebaseService.instance.currentUser?.getIdToken();
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
    String? level,
    List<String>? avoid,
  }) async {
    final body = <String, dynamic>{
      'word': word,
      'sourceLang': sourceLang,
      'targetLang': targetLang,
      'mode': 'translate',
    };
    if (firebaseUid != null) body['firebaseUid'] = firebaseUid;
    if (level != null) body['level'] = level;
    // When regenerating, the current example(s) are sent so the server produces
    // a genuinely new example in a different context — not a reworded copy.
    if (avoid != null && avoid.isNotEmpty) body['avoid'] = avoid;
    final response = await _postWithRetry(body);

    if (response.statusCode != 200) {
      final msg = _friendlyError(response.statusCode, response.body);
      throw Exception(msg);
    }

    final data = jsonDecode(response.body);
    return TranslationResult.fromMeanings(data);
  }

  /// Generate a short grammar/usage tip for a word (server `grammar` mode).
  ///
  /// Returns the tip text, or an empty string when there's nothing noteworthy.
  /// Uses the exact same endpoint + auth as [translate], so it works wherever
  /// translation already works.
  Future<String> generateGrammarTip({
    required String word,
    String sourceLang = _defaultSourceLang,
    String targetLang = _defaultTargetLang,
    String? firebaseUid,
    String? level,
  }) async {
    final body = <String, dynamic>{
      'word': word,
      'sourceLang': sourceLang,
      'targetLang': targetLang,
      'mode': 'grammar',
    };
    if (firebaseUid != null) body['firebaseUid'] = firebaseUid;
    if (level != null) body['level'] = level;

    final response = await _postWithRetry(body);

    if (response.statusCode != 200) {
      throw Exception(_friendlyError(response.statusCode, response.body));
    }

    final data = jsonDecode(response.body);
    return (data['grammar_tip'] ?? '').toString().trim();
  }

  /// Generate 5 daily-life phrases in the given language.
  Future<List<DailyPhrase>> generateDailyPhrases({
    String lang = 'de',
    String? theme,
    String? firebaseUid,
    List<String>? exclude,
    String? level,
  }) async {
    final body = <String, dynamic>{
      'sourceLang': lang,
      'targetLang': lang,
      'mode': 'phrases',
    };
    if (firebaseUid != null) body['firebaseUid'] = firebaseUid;
    if (level != null) body['level'] = level;
    if (theme != null && theme.trim().isNotEmpty) {
      body['theme'] = theme.trim();
    }
    // Phrases the server should NOT repeat (already shown/blocked). The proxy
    // injects these into the prompt to force fresh, non-duplicate phrases.
    if (exclude != null && exclude.isNotEmpty) {
      body['exclude'] = exclude.take(40).toList();
    }

    final response = await _postWithRetry(body);

    if (response.statusCode != 200) {
      final msg = _friendlyError(response.statusCode, response.body);
      throw Exception(msg);
    }

    final data = jsonDecode(response.body);
    final phrases = List<String>.from(data['phrases'] ?? []);
    return phrases.map((p) => DailyPhrase(phrase: p)).toList();
  }

  /// Evaluate an original user sentence using a target vocabulary word.
  /// Evaluates grammar, natural tone, and correct word usage.
  Future<List<String>> evaluateSentence({
    required String word,
    required String userSentence,
    String lang = 'de',
    String? firebaseUid,
  }) async {
    final prompt =
        "The language learning student wrote an original sentence attempting to use the vocabulary item '$word': '$userSentence'. Please grade and evaluate their sentence for: 1) Grammatical correctness, 2) Natural tone and phrasing, and 3) Correct vocabulary word usage. Provide 2-4 friendly, concise feedback bullet points explaining any mistakes and suggesting corrections, or praising accurate usage.";
    final phrases = await generateDailyPhrases(
      lang: lang,
      theme: prompt,
      firebaseUid: firebaseUid,
    );
    return phrases.map((p) => p.phrase).toList();
  }

  /// Helper method to execute POST requests with 60-second timeouts and automatic retries.
  Future<http.Response> _postWithRetry(Map<String, dynamic> body) async {
    int attempts = 0;
    while (true) {
      attempts++;
      try {
        final response = await http
            .post(
              Uri.parse(_baseUrl),
              headers: await _authHeaders(),
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 60));
        return response;
      } catch (e) {
        if (attempts < 2) {
          await Future.delayed(const Duration(seconds: 1));
          continue; // Automatically retry once on timeout or connection drop
        }
        final errStr = e.toString();
        if (errStr.contains('TimeoutException')) {
          throw Exception('The AI translation server took too long to respond. Please check your connection and try again.');
        }
        if (errStr.contains('SocketException') || errStr.contains('ClientException') || errStr.contains('Network') || errStr.contains('Failed host lookup')) {
          throw Exception('Unable to reach translation server. Please check your internet connection and try again.');
        }
        throw Exception(errStr.replaceFirst('Exception: ', ''));
      }
    }
  }

  /// Map HTTP errors to user-friendly messages.
  String _friendlyError(int statusCode, String body) {
    if (statusCode == 503 || statusCode == 502 || statusCode == 500) {
      return 'The translation service is temporarily busy. Please try again in a moment.';
    }
    if (statusCode == 429) {
      return 'Too many translation requests. Please pause for a moment and try again.';
    }
    if (statusCode == 401 || statusCode == 403) {
      return 'Authentication failed with the translation server. Please sign in again.';
    }
    return 'We encountered an unexpected error (Code $statusCode). Please try again later.';
  }
}

/// Extension: treat empty strings as null for grammar fields.
extension StringNullIfEmpty on String {
  String? get nullIfEmpty => isEmpty ? null : this;
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

/// Structured grammar data auto-generated by the proxy for every translation.
class GrammarData {
  final String? article;
  final String? plural;
  final String? feminineForm;
  final String? masculineForm;
  final String? partOfSpeech;
  final String? infinitive;
  final String? pastTense;
  final String? pastParticiple;
  final String? auxiliaryVerb;
  final String? verbType;
  final bool isReflexive;
  final bool isSeparable;
  final String? posPrepositions;

  GrammarData({
    this.article,
    this.plural,
    this.feminineForm,
    this.masculineForm,
    this.partOfSpeech,
    this.infinitive,
    this.pastTense,
    this.pastParticiple,
    this.auxiliaryVerb,
    this.verbType,
    this.isReflexive = false,
    this.isSeparable = false,
    this.posPrepositions,
  });

  factory GrammarData.fromJson(Map<String, dynamic>? json) {
    if (json == null) return GrammarData();
    return GrammarData(
      article: (json['article'] as String?)?.nullIfEmpty,
      plural: (json['plural'] as String?)?.nullIfEmpty,
      feminineForm: (json['feminine_form'] as String?)?.nullIfEmpty,
      masculineForm: (json['masculine_form'] as String?)?.nullIfEmpty,
      partOfSpeech: (json['part_of_speech'] as String?)?.nullIfEmpty,
      infinitive: (json['infinitive'] as String?)?.nullIfEmpty,
      pastTense: (json['past_tense'] as String?)?.nullIfEmpty,
      pastParticiple: (json['past_participle'] as String?)?.nullIfEmpty,
      auxiliaryVerb: (json['auxiliary_verb'] as String?)?.nullIfEmpty,
      verbType: (json['verb_type'] as String?)?.nullIfEmpty,
      isReflexive: json['is_reflexive'] == true,
      isSeparable: json['is_separable'] == true,
      posPrepositions: (json['pos_prepositions'] as String?)?.nullIfEmpty,
    );
  }

  /// True if this word has any grammar data worth displaying.
  bool get hasData =>
      article != null ||
      plural != null ||
      feminineForm != null ||
      masculineForm != null ||
      partOfSpeech != null ||
      infinitive != null ||
      pastTense != null ||
      pastParticiple != null ||
      auxiliaryVerb != null ||
      verbType != null ||
      posPrepositions != null;
}

/// Result from DeepSeek translation — contains one or more meanings.
class TranslationResult {
  final List<Meaning> meanings;
  // Corrected spelling of the source word, if the server provides one.
  final String? corrected;
  // Auto-detected grammar data (part of speech, verb forms, plural, etc.)
  final GrammarData? grammar;

  TranslationResult({required this.meanings, this.corrected, this.grammar});

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
    // Auto-enriched grammar data (new in proxy v6).
    final grammar = map['grammar'] is Map<String, dynamic>
        ? GrammarData.fromJson(map['grammar'] as Map<String, dynamic>)
        : null;
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
        return TranslationResult(meanings: meanings, corrected: corrected, grammar: grammar);
      }
    }
    // Fallback
    return TranslationResult(meanings: [
      Meaning(text: map.toString(), exampleSource: '', exampleTarget: ''),
    ], corrected: corrected, grammar: grammar);
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
