/// ─── App Configuration ──────────────────────────────────────────────
///
/// Central place for app-wide constants.
///
/// ## API Key
/// The real key lives in `lib/config/secrets.dart` (gitignored).
/// If that file is missing or has a placeholder, the TranslationService
/// will use the shared_preferences override instead (set via Settings).
///
/// ## Language defaults
/// German → English is the default because the app was built for
/// learning German vocabulary. These are overridable in the Add Word
/// dialog's dropdown selectors.

import 'secrets.dart';

class AppConfig {
  // DeepSeek API — real key from gitignored secrets.dart
  static const String deepseekApiKey = deepseekApiKeyReal;

  // Default languages for the Add Word dialog
  static const String defaultSourceLang = 'de';
  static const String defaultTargetLang = 'en';

  // App info — used by platform channels and package configuration
  static const String appName = 'AI Vocab Builder';
  static const String packageName = 'com.vocabreader.ai_vocab_builder';
}
