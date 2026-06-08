/// ─── Locale Provider ─────────────────────────────────────────────────
///
/// Manages the app's UI language (en/de/ar) and the default translation
/// target language. Both are persisted via shared_preferences.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  String _locale = 'en'; // en or de
  String _targetLang = 'en'; // en, de, fr, es, etc.

  String get locale => _locale;
  String get targetLang => _targetLang;

  static const _keyLocale = 'app_locale';
  static const _keyTargetLang = 'translate_target_lang';

  LocaleProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _locale = prefs.getString(_keyLocale) ?? 'en';
    _targetLang = prefs.getString(_keyTargetLang) ?? 'en';
    notifyListeners();
  }

  Future<void> setLocale(String value) async {
    _locale = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocale, value);
  }

  Future<void> setTargetLang(String value) async {
    _targetLang = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTargetLang, value);
  }
}
