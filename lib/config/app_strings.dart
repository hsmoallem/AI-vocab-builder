/// ─── App Strings ────────────────────────────────────────────────────
///
/// All user-facing text in English (en) and German (de).
/// Accessed via `AppStrings.of(context)` anywhere in the app.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';

class AppStrings {
  final String locale;

  const AppStrings(this.locale);

  /// Convenience: `AppStrings.of(context).appName`
  static AppStrings of(BuildContext context) {
    final provider = context.watch<LocaleProvider>();
    return AppStrings(provider.locale);
  }

  // ── Language names ────────────────────────────────────────────────
  String get languageEn => 'English';
  String get languageDe => 'Deutsch';

  // ── App ───────────────────────────────────────────────────────────
  String get appName => locale == 'de' ? 'AI Vokabeltrainer' : 'AI Vocab Builder';
  String get appTagline => locale == 'de'
      ? 'PDFs lesen. Wörter lernen. Nie vergessen.'
      : 'Read PDFs. Learn words. Never forget.';

  // ── Login ─────────────────────────────────────────────────────────
  String get signInWithGoogle =>
      locale == 'de' ? 'Mit Google anmelden' : 'Sign in with Google';
  String get continueWithoutAccount =>
      locale == 'de' ? 'Ohne Konto fortfahren' : 'Continue without account';
  String get anonymousWarningTitle =>
      locale == 'de' ? 'Ohne Konto fortfahren?' : 'Continue without account?';
  String get anonymousWarningBody => locale == 'de'
      ? 'Du kannst die App nutzen, aber deine Wörter werden nur auf diesem '
          'Gerät gespeichert. Wenn du die App löschst oder ein neues Handy '
          'bekommst, gehen deine Daten verloren.\n\n'
          'Melde dich mit Google an, um deine Wörter in der Cloud zu sichern.'
      : 'You can use the app, but your words will only be saved on this '
          'device. If you delete the app or get a new phone, your data will '
          'be lost.\n\n'
          'Sign in with Google to back up your words to the cloud.';
  String get goBack => locale == 'de' ? 'Zurück' : 'Go back';
  String get continueAnyway =>
      locale == 'de' ? 'Trotzdem fortfahren' : 'Continue anyway';
  String get googleNotAvailable => locale == 'de'
      ? 'Google-Anmeldung nicht verfügbar — Firebase nicht konfiguriert'
      : 'Google sign-in not available — Firebase not configured';

  // ── Home ──────────────────────────────────────────────────────────
  String get tabReader => locale == 'de' ? 'Lesen' : 'Reader';
  String get tabDaily => locale == 'de' ? 'Täglich' : 'Daily';
  String get tabMyWords => locale == 'de' ? 'Meine Wörter' : 'My Words';
  String get flashcards => locale == 'de' ? 'Karteikarten' : 'Flashcards';
  String get addWord => locale == 'de' ? 'Wort hinzufügen' : 'Add Word';
  String get account => locale == 'de' ? 'Konto' : 'Account';
  String get anonymousUser =>
      locale == 'de' ? 'Anonymer Nutzer' : 'Anonymous user';
  String get cloudBackupNotAvailable => locale == 'de'
      ? 'Cloud-Backup nicht verfügbar'
      : 'Cloud backup not available';
  String get backupNow =>
      locale == 'de' ? 'Jetzt sichern' : 'Backup now';
  String get restoreFromCloud =>
      locale == 'de' ? 'Aus Cloud wiederherstellen' : 'Restore from cloud';
  String get signOut => locale == 'de' ? 'Abmelden' : 'Sign out';
  String get settings => locale == 'de' ? 'Einstellungen' : 'Settings';
  String get anonymousBanner => locale == 'de'
      ? 'Anonyme Nutzung — deine Wörter sind nur auf diesem Gerät. '
          'Melde dich an, um sie in der Cloud zu sichern.'
      : 'Using anonymously — your words are only on this device. '
          'Sign in to back up to the cloud.';
  String get savedWordToMyWords => locale == 'de'
      ? '„{word}“ zu Meine Wörter hinzugefügt'
      : 'Saved "{word}" to My Words';

  // ── Daily Phrases ─────────────────────────────────────────────────
  String get dailyPhrasesTitle =>
      locale == 'de' ? 'Tägliche Phrasen' : 'Daily Phrases';
  String get themeHint => locale == 'de'
      ? 'Thema (z.B. im Restaurant) — leer für allgemein'
      : 'Theme (e.g. at the restaurant) — leave empty for general';
  String get generateNew =>
      locale == 'de' ? 'Neue generieren' : 'Generate new';
  String get retry =>
      locale == 'de' ? 'Wiederholen' : 'Retry';
  String memorizedCounter(int done, int total) => locale == 'de'
      ? '$done / $total gelernt'
      : '$done / $total memorized';
  String get allDone =>
      locale == 'de' ? '🎉 Alle gelernt!' : '🎉 All done!';
  String get saveToWords =>
      locale == 'de' ? 'Zu Meine Wörter' : 'Save to My Words';

  // ── Word List ─────────────────────────────────────────────────────
  String get searchHint =>
      locale == 'de' ? 'Wörter durchsuchen...' : 'Search words...';
  String get sortNewest =>
      locale == 'de' ? 'Neueste' : 'Newest';
  String get sortAlphabetical =>
      locale == 'de' ? 'Alphabetisch' : 'Alphabetical';
  String get deleteWord =>
      locale == 'de' ? 'Wort löschen' : 'Delete word';
  String get deleteConfirmTitle =>
      locale == 'de' ? 'Wort löschen?' : 'Delete word?';
  String deleteConfirmBody(String word) => locale == 'de'
      ? '"$word" wirklich löschen?'
      : 'Really delete "$word"?';
  String get cancel => locale == 'de' ? 'Abbrechen' : 'Cancel';
  String get delete => locale == 'de' ? 'Löschen' : 'Delete';
  String get noWords => locale == 'de'
      ? 'Noch keine Wörter. Tippe auf + um ein Wort hinzuzufügen.'
      : 'No words yet. Tap + to add a word.';

  // ── Word Card ─────────────────────────────────────────────────────
  String get markReviewed =>
      locale == 'de' ? 'Als gelernt markieren' : 'Mark as reviewed';
  String get markUnreviewed =>
      locale == 'de' ? 'Als ungelernt markieren' : 'Mark as unreviewed';
  String get listenWord =>
      locale == 'de' ? 'Wort anhören' : 'Listen to word';
  String get listenExample =>
      locale == 'de' ? 'Beispiel anhören' : 'Listen to example';

  // ── Flashcards ────────────────────────────────────────────────────
  String get tapToReveal =>
      locale == 'de' ? 'Antippen zum Aufdecken' : 'Tap to reveal';
  String get previousCard =>
      locale == 'de' ? 'Vorherige Karte' : 'Previous card';
  String get nextCard =>
      locale == 'de' ? 'Nächste Karte' : 'Next card';
  String cardXofY(int current, int total) => locale == 'de'
      ? 'Karte $current von $total'
      : 'Card $current of $total';

  // ── PDF Reader ────────────────────────────────────────────────────
  String get pdfView => locale == 'de' ? 'PDF-Ansicht' : 'PDF View';
  String get textView => locale == 'de' ? 'Textansicht' : 'Text View';
  String get pickPdf =>
      locale == 'de' ? 'PDF auswählen' : 'Pick PDF';

  // ── Add Word ──────────────────────────────────────────────────────
  String get addWordTitle =>
      locale == 'de' ? 'Wort hinzufügen' : 'Add Word';
  String get wordLabel =>
      locale == 'de' ? 'Wort' : 'Word';
  String get translating =>
      locale == 'de' ? 'Übersetze...' : 'Translating...';
  String get saveWord =>
      locale == 'de' ? 'Speichern' : 'Save';

  // ── Settings ──────────────────────────────────────────────────────
  String get settingsTitle =>
      locale == 'de' ? 'Einstellungen' : 'Settings';
  String get appLanguage =>
      locale == 'de' ? 'App-Sprache' : 'App Language';
  String get appLanguageDesc => locale == 'de'
      ? 'Sprache der Benutzeroberfläche'
      : 'User interface language';
  String get translateLanguage =>
      locale == 'de' ? 'Übersetzungssprache' : 'Translate Language';
  String get translateLanguageDesc => locale == 'de'
      ? 'Zielsprache für KI-Übersetzungen'
      : 'Target language for AI translations';
  String get exportWords =>
      locale == 'de' ? 'Wörter exportieren' : 'Export Words';
  String get exportWordsShort =>
      locale == 'de' ? 'Export' : 'Export';
  String get exportWordsDesc => locale == 'de'
      ? 'Alle Wörter als JSON-Datei speichern'
      : 'Save all words as a JSON file';
  String exportSuccess({required int count}) => locale == 'de'
      ? '$count Wörter exportiert'
      : 'Exported $count words';
  String get exportFailed =>
      locale == 'de' ? 'Export fehlgeschlagen' : 'Export failed';

  // ── Languages for translate dropdown ─────────────────────────────
  static const Map<String, String> targetLanguages = {
    'en': 'English',
    'de': 'Deutsch',
    'fr': 'Français',
    'es': 'Español',
    'it': 'Italiano',
    'ar': 'العربية',
    'tr': 'Türkçe',
    'ru': 'Русский',
    'zh': '中文',
    'ja': '日本語',
  };
}
