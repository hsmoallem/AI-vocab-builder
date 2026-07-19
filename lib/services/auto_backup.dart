/// ─── Automatic Cloud Backup ─────────────────────────────────────────
///
/// A user-chosen schedule (Off / Daily / Weekly). The frequency is stored in
/// SharedPreferences. On app launch, if it's due and the user is signed in
/// with a real (non-anonymous) account, a silent Firestore backup runs.

import 'package:shared_preferences/shared_preferences.dart';
import '../models/word.dart';
import 'firebase_service.dart';

class AutoBackup {
  static const String freqOff = 'off';
  static const String freqDaily = 'daily';
  static const String freqWeekly = 'weekly';

  static const _freqKey = 'auto_backup_frequency';
  static const _lastKey = 'auto_backup_last_ms';

  static Future<String> getFrequency() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_freqKey) ?? freqOff;
  }

  static Future<void> setFrequency(String value) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_freqKey, value);
  }

  static Future<DateTime?> lastBackup() async {
    final p = await SharedPreferences.getInstance();
    final ms = p.getInt(_lastKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Run a backup if it's enabled and due. Silent — never throws, so a failed
  /// backup can never disrupt the app.
  static Future<void> maybeRun(List<Word> words) async {
    try {
      final fb = FirebaseService.instance;
      if (!fb.isSignedIn || fb.isAnonymous) return; // needs a real account
      if (words.isEmpty) return;
      final freq = await getFrequency();
      if (freq == freqOff) return;
      final interval = freq == freqDaily
          ? const Duration(days: 1)
          : const Duration(days: 7);
      final last = await lastBackup();
      if (last != null && DateTime.now().difference(last) < interval) return;
      await fb.backupWords(words);
      final p = await SharedPreferences.getInstance();
      await p.setInt(_lastKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {
      // Silent by design.
    }
  }
}
