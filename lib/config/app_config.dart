/// ─── App Configuration ──────────────────────────────────────────────
///
/// Central place for app-wide constants. No environment variables or
/// .env files — keeps the setup dead simple for a single-developer,
/// local-first Android app.
///
/// ## API Key
/// The DeepSeek API key is embedded here for simplicity in development.
/// In production, this would move to a backend or secure storage.
/// The TranslationService also supports overriding the key via
/// shared_preferences (Settings screen, not yet built).
///
/// ## Language defaults
/// German → English is the default because the app was built for
/// learning German vocabulary. These are overridable in the Add Word
/// dialog's dropdown selectors.

class AppConfig {
  // DeepSeek API
  // [REDACTED] — replace with your own key from https://platform.deepseek.com
  static const String deepseekApiKey = 'sk-b7f...b6d8';

  // Default languages for the Add Word dialog
  static const String defaultSourceLang = 'de';
  static const String defaultTargetLang = 'en';

  // App info — used by platform channels and package configuration
  static const String appName = 'Vocab Builder';
  static const String packageName = 'com.vocabreader.ai_vocab_builder';
}
