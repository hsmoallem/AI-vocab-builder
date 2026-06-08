/// ─── App Configuration ──────────────────────────────────────────────
///
/// Central place for app-wide constants.
///
/// ## Translation
/// All translation requests go through the proxy server at
/// 13.140.134.57:9000/translate — the DeepSeek key lives there,
/// never in the APK. Safe to share.
///
/// ## Language defaults
/// German → English is the default because the app was built for
/// learning German vocabulary. These are overridable in the Add Word
/// dialog's dropdown selectors.

class AppConfig {
  // Default languages for the Add Word dialog
  static const String defaultSourceLang = 'de';
  static const String defaultTargetLang = 'en';

  // App info — used by platform channels and package configuration
  static const String appName = 'AI Vocab Builder';
  static const String packageName = 'com.vocabreader.ai_vocab_builder';
}
