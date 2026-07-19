/// ─── Study Preferences ──────────────────────────────────────────────
///
/// Persisted study-session settings. Currently: how many NEW (never-studied)
/// cards a review session may introduce, so the user can choose small sessions
/// or "All".

import 'package:shared_preferences/shared_preferences.dart';

class StudyPrefs {
  static const _newPerSessionKey = 'new_cards_per_session';

  /// Sentinel meaning "no limit — include every new card".
  static const int all = 1000000;

  /// New cards introduced per session. Default 30.
  static Future<int> newCardsPerSession() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_newPerSessionKey) ?? 30;
  }

  static Future<void> setNewCardsPerSession(int n) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_newPerSessionKey, n);
  }
}
