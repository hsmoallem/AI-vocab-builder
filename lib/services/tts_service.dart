/// ─── Text-to-Speech Service ─────────────────────────────────────────
///
/// Uses Android's built-in TextToSpeech engine via MethodChannel —
/// same pattern as the file picker. Zero external dependencies.
///
/// ## Why native MethodChannel (not flutter_tts package)
///   - `flutter_tts` applies Kotlin Gradle Plugin directly, which causes
///     "Future versions of Flutter will fail to build" warnings
///   - `flutter_tts` doesn't support Swift Package Manager for iOS
///   - Native TTS is ~30 lines of Kotlin, trivial to maintain
///   - Same architecture as our file picker — consistent approach
///
/// ## Usage
///   ```dart
///   final tts = TtsService();
///   await tts.speak('Guten Morgen', language: 'de');
///   await tts.speak('Good morning', language: 'en');
///   ```

import 'package:flutter/services.dart';

class TtsService {
  static const _channel = MethodChannel('com.vocabreader/tts');

  /// Speak the given text in the specified language.
  ///
  /// [language] is a 2-letter ISO code (e.g., 'de', 'en', 'fr').
  /// Android's TextToSpeech engine matches the best available voice.
  /// Works offline — no network call, no API key.
  Future<void> speak(String text, {required String language}) async {
    if (text.trim().isEmpty) return;

    await _channel.invokeMethod('speak', {
      'text': text.trim(),
      'language': language,
    });
  }

  /// Stop any currently playing speech.
  Future<void> stop() async {
    await _channel.invokeMethod('stop');
  }
}
