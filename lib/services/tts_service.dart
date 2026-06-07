/// ─── Text-to-Speech Service ─────────────────────────────────────────
///
/// Thin wrapper around flutter_tts. Uses Android's built-in Google TTS
/// engine — works offline, no API keys, no network. German, English,
/// and all major languages supported out of the box.
///
/// ## Why flutter_tts
///   - Most popular Flutter TTS (3K+ likes on pub.dev)
///   - Uses Android's system TTS engine (already on every phone)
///   - Works offline — no network call
///   - Language switching is instant — no model downloads
///   - Zero configuration needed
///
/// ## Usage
///   ```dart
///   final tts = TtsService();
///   await tts.speak('Guten Morgen', language: 'de');
///   await tts.speak('Good morning', language: 'en');
///   ```

import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();

  /// Speak the given text in the specified language.
  ///
  /// [language] is a 2-letter ISO code (e.g., 'de', 'en', 'fr').
  /// The method sets the language before speaking — this adds
  /// ~50ms but ensures correct pronunciation every time.
  Future<void> speak(String text, {required String language}) async {
    if (text.trim().isEmpty) return;

    // Stop any current speech before starting new one.
    // This prevents overlapping audio when user taps quickly.
    await _tts.stop();

    // Configure voice for this language.
    // Android matches the best available voice automatically.
    await _tts.setLanguage(language);

    // Speak with moderate speed — clear and natural.
    await _tts.setSpeechRate(0.5);   // 0.0=slowest, 1.0=normal
    await _tts.setPitch(1.0);        // 1.0=normal

    await _tts.speak(text);
  }

  /// Stop any currently playing speech.
  Future<void> stop() async {
    await _tts.stop();
  }

  /// Release TTS resources. Call when the app is disposed.
  Future<void> dispose() async {
    await _tts.stop();
  }
}
