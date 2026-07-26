/// ─── App Strings ────────────────────────────────────────────────────
///
/// All user-facing text in English (en), German (de), and Arabic (ar).
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
  String get languageAr => 'العربية';

  // ── App ───────────────────────────────────────────────────────────
  String get appName {
    if (locale == 'de') return 'AI Vokabeltrainer';
    if (locale == 'ar') return 'باني المفردات الذكي';
    return 'AI Vocab Builder';
  }
  String get appTagline {
    if (locale == 'de') return 'PDFs lesen. Wörter lernen. Nie vergessen.';
    if (locale == 'ar') return 'اقرأ PDF. تعلم الكلمات. لا تنس أبداً.';
    return 'Read PDFs. Learn words. Never forget.';
  }

  // ── Login ─────────────────────────────────────────────────────────
  String get signInWithGoogle {
    if (locale == 'de') return 'Mit Google anmelden';
    if (locale == 'ar') return 'تسجيل الدخول بـ Google';
    return 'Sign in with Google';
  }
  String get signInWithApple {
    if (locale == 'de') return 'Mit Apple anmelden';
    if (locale == 'ar') return 'تسجيل الدخول بـ Apple';
    return 'Continue with Apple';
  }
  String get continueWithoutAccount {
    if (locale == 'de') return 'Ohne Konto fortfahren';
    if (locale == 'ar') return 'متابعة بدون حساب';
    return 'Continue without account';
  }
  String get anonymousWarningTitle {
    if (locale == 'de') return 'Ohne Konto fortfahren?';
    if (locale == 'ar') return 'متابعة بدون حساب؟';
    return 'Continue without account?';
  }
  String get anonymousWarningBody {
    if (locale == 'de')
      return 'Du kannst die App nutzen, aber deine Wörter werden nur auf diesem '
          'Gerät gespeichert. Wenn du die App löschst oder ein neues Handy '
          'bekommst, gehen deine Daten verloren.\n\n'
          'Melde dich mit Google an, um deine Wörter in der Cloud zu sichern.';
    if (locale == 'ar')
      return 'يمكنك استخدام التطبيق، لكن كلماتك ستحفظ فقط على هذا الجهاز. '
          'إذا حذفت التطبيق أو حصلت على هاتف جديد، ستفقد بياناتك.\n\n'
          'سجل الدخول بـ Google لحفظ كلماتك في السحابة.';
    return 'You can use the app, but your words will only be saved on this '
        'device. If you delete the app or get a new phone, your data will '
        'be lost.\n\n'
        'Sign in with Google to back up your words to the cloud.';
  }
  String get goBack {
    if (locale == 'de') return 'Zurück';
    if (locale == 'ar') return 'رجوع';
    return 'Go back';
  }
  String get continueAnyway {
    if (locale == 'de') return 'Trotzdem fortfahren';
    if (locale == 'ar') return 'متابعة على أي حال';
    return 'Continue anyway';
  }
  String get googleNotAvailable {
    if (locale == 'de')
      return 'Google-Anmeldung nicht verfügbar — Firebase nicht konfiguriert';
    if (locale == 'ar')
      return 'تسجيل Google غير متاح — Firebase غير مهيأ';
    return 'Google sign-in not available — Firebase not configured';
  }
  String get appleNotAvailable {
    if (locale == 'de')
      return 'Apple-Anmeldung nicht verfügbar — Firebase nicht konfiguriert';
    if (locale == 'ar')
      return 'تسجيل Apple غير متاح — Firebase غير مهيأ';
    return 'Apple sign-in not available — Firebase not configured';
  }
  String get appleNote {
    if (locale == 'de') return '(Verfügbar auf iOS- & Apple-Geräten)';
    if (locale == 'ar') return '(متاح على أجهزة iOS و Apple)';
    return '(available on iOS and Apple devices)';
  }
  String get appleLimitTitle {
    if (locale == 'de') return 'Hinweis zur Apple-Anmeldung';
    if (locale == 'ar') return 'تنبيه تسجيل الدخول بـ Apple';
    return 'Apple Sign-In Notice';
  }
  String get appleLimitBody {
    if (locale == 'de')
      return 'Derzeit ist die „Anmeldung mit Apple“ nur direkt von iOS-Geräten und Apple-Computern (Mac/iPhone) aus verfügbar.\n\nBitte nutze auf Android oder Windows „Mit Google anmelden“, um dich einloggen und deinen Fortschritt geräteübergreifend sichern zu können!';
    if (locale == 'ar')
      return 'حالياً، „تسجيل الدخول بـ Apple“ متاح فقط من أجهزة iOS وأجهزة كمبيوتر Apple (iPhone / Mac).\n\nإذا كنت تستخدم أندرويد أو ويندوز، يُرجى استخدام „تسجيل الدخول بـ Google“ لمزامنة وحفظ تقدمك عبر جميع الأجهزة!';
    return 'Currently, "Continue with Apple" is only available directly from iOS devices and Apple computers (iPhone / Mac).\n\nIf you are on Android or Windows, please use "Continue with Google" to sign in and back up your progress across all devices!';
  }
  String get gotIt {
    if (locale == 'de') return 'Verstanden';
    if (locale == 'ar') return 'حسناً';
    return 'Got it';
  }


  // ── Home ──────────────────────────────────────────────────────────
  String get tabReader {
    if (locale == 'de') return 'Lesen';
    if (locale == 'ar') return 'القارئ';
    return 'Reader';
  }
  String get tabDaily {
    if (locale == 'de') return 'Täglich';
    if (locale == 'ar') return 'يومي';
    return 'Daily';
  }
  String get tabMyWords {
    if (locale == 'de') return 'Meine Wörter';
    if (locale == 'ar') return 'كلماتي';
    return 'My Words';
  }
  String get flashcards {
    if (locale == 'de') return 'Karteikarten';
    if (locale == 'ar') return 'بطاقات تعليمية';
    return 'Flashcards';
  }
  String get addWord {
    if (locale == 'de') return 'Wort hinzufügen';
    if (locale == 'ar') return 'إضافة كلمة';
    return 'Add Word';
  }
  String get account {
    if (locale == 'de') return 'Konto';
    if (locale == 'ar') return 'الحساب';
    return 'Account';
  }
  String get anonymousUser {
    if (locale == 'de') return 'Anonymer Nutzer';
    if (locale == 'ar') return 'مستخدم مجهول';
    return 'Anonymous user';
  }
  String get cloudBackupNotAvailable {
    if (locale == 'de') return 'Cloud-Backup nicht verfügbar';
    if (locale == 'ar') return 'النسخ الاحتياطي السحابي غير متاح';
    return 'Cloud backup not available';
  }
  String get backupNow {
    if (locale == 'de') return 'Jetzt sichern';
    if (locale == 'ar') return 'نسخ احتياطي الآن';
    return 'Backup now';
  }
  String get restoreFromCloud {
    if (locale == 'de') return 'Aus Cloud wiederherstellen';
    if (locale == 'ar') return 'استعادة من السحابة';
    return 'Restore from cloud';
  }
  String get signOut {
    if (locale == 'de') return 'Abmelden';
    if (locale == 'ar') return 'تسجيل الخروج';
    return 'Sign out';
  }
  String get settings {
    if (locale == 'de') return 'Einstellungen';
    if (locale == 'ar') return 'الإعدادات';
    return 'Settings';
  }
  String get anonymousBanner {
    if (locale == 'de')
      return 'Anonyme Nutzung — deine Wörter sind nur auf diesem Gerät. '
          'Melde dich an, um sie in der Cloud zu sichern.';
    if (locale == 'ar')
      return 'استخدام مجهول — كلماتك على هذا الجهاز فقط. '
          'سجل الدخول لحفظها في السحابة.';
    return 'Using anonymously — your words are only on this device. '
        'Sign in to back up to the cloud.';
  }
  String get savedWordToMyWords {
    if (locale == 'de') return '„{word}“ zu Meine Wörter hinzugefügt';
    if (locale == 'ar') return 'تمت إضافة "{word}" إلى كلماتي';
    return 'Saved "{word}" to My Words';
  }

  // ── Daily Phrases ─────────────────────────────────────────────────
  String get dailyPhrasesTitle {
    if (locale == 'de') return 'Tägliche Phrasen';
    if (locale == 'ar') return 'عبارات يومية';
    return 'Daily Phrases';
  }
  String get themeHint {
    if (locale == 'de')
      return 'Thema (z.B. im Restaurant) — leer für allgemein';
    if (locale == 'ar')
      return 'الموضوع (مثلاً: في المطعم) — اتركه فارغاً لعبارات عامة';
    return 'Theme (e.g. at the restaurant) — leave empty for general';
  }
  String get generateNew {
    if (locale == 'de') return 'Neue generieren';
    if (locale == 'ar') return 'توليد جديدة';
    return 'Generate new';
  }
  String get retry {
    if (locale == 'de') return 'Wiederholen';
    if (locale == 'ar') return 'إعادة المحاولة';
    return 'Retry';
  }
  String memorizedCounter(int done, int total) {
    if (locale == 'de') return '$done / $total gelernt';
    if (locale == 'ar') return '$done / $total تم الحفظ';
    return '$done / $total memorized';
  }
  String get allDone {
    if (locale == 'de') return '🎉 Alle gelernt!';
    if (locale == 'ar') return '🎉!تم الانتهاء من الكل';
    return '🎉 All done!';
  }
  String get saveToWords {
    if (locale == 'de') return 'Zu Meine Wörter';
    if (locale == 'ar') return 'حفظ إلى كلماتي';
    return 'Save to My Words';
  }

  // ── Word List ─────────────────────────────────────────────────────
  String get searchHint {
    if (locale == 'de') return 'Wörter durchsuchen...';
    if (locale == 'ar') return '...البحث عن كلمات';
    return 'Search words...';
  }
  String get sortNewest {
    if (locale == 'de') return 'Neueste';
    if (locale == 'ar') return 'الأحدث';
    return 'Newest';
  }
  String get sortOldest {
    if (locale == 'de') return 'Älteste';
    if (locale == 'ar') return 'الأقدم';
    return 'Oldest';
  }
  String get sortAlphabetical {
    if (locale == 'de') return 'Alphabetisch';
    if (locale == 'ar') return 'أبجدياً';
    return 'Alphabetical';
  }
  String get deleteWord {
    if (locale == 'de') return 'Wort löschen';
    if (locale == 'ar') return 'حذف الكلمة';
    return 'Delete word';
  }
  String get deleteConfirmTitle {
    if (locale == 'de') return 'Wort löschen?';
    if (locale == 'ar') return 'حذف الكلمة؟';
    return 'Delete word?';
  }
  String deleteConfirmBody(String word) {
    if (locale == 'de') return '"$word" wirklich löschen?';
    if (locale == 'ar') return 'هل تريد حذف "$word"؟';
    return 'Really delete "$word"?';
  }
  String get cancel {
    if (locale == 'de') return 'Abbrechen';
    if (locale == 'ar') return 'إلغاء';
    return 'Cancel';
  }
  String get delete {
    if (locale == 'de') return 'Löschen';
    if (locale == 'ar') return 'حذف';
    return 'Delete';
  }
  String get noWords {
    if (locale == 'de')
      return 'Noch keine Wörter. Tippe auf + um ein Wort hinzuzufügen.';
    if (locale == 'ar')
      return 'لا توجد كلمات بعد. اضغط + لإضافة كلمة.';
    return 'No words yet. Tap + to add a word.';
  }

  // ── Word Card ─────────────────────────────────────────────────────
  String get markReviewed {
    if (locale == 'de') return 'Als gelernt markieren';
    if (locale == 'ar') return 'تعليم كمُراجع';
    return 'Mark as reviewed';
  }
  String get markUnreviewed {
    if (locale == 'de') return 'Als ungelernt markieren';
    if (locale == 'ar') return 'تعليم كغير مُراجع';
    return 'Mark as unreviewed';
  }
  String get listenWord {
    if (locale == 'de') return 'Wort anhören';
    if (locale == 'ar') return 'استماع للكلمة';
    return 'Listen to word';
  }
  String get listenExample {
    if (locale == 'de') return 'Beispiel anhören';
    if (locale == 'ar') return 'استماع للمثال';
    return 'Listen to example';
  }

  // ── Flashcards ────────────────────────────────────────────────────
  String get tapToReveal {
    if (locale == 'de') return 'Antippen zum Aufdecken';
    if (locale == 'ar') return 'اضغط للكشف';
    return 'Tap to reveal';
  }
  String get previousCard {
    if (locale == 'de') return 'Vorherige Karte';
    if (locale == 'ar') return 'البطاقة السابقة';
    return 'Previous card';
  }
  String get nextCard {
    if (locale == 'de') return 'Nächste Karte';
    if (locale == 'ar') return 'البطاقة التالية';
    return 'Next card';
  }
  String cardXofY(int current, int total) {
    if (locale == 'de') return 'Karte $current von $total';
    if (locale == 'ar') return 'بطاقة $current من $total';
    return 'Card $current of $total';
  }

  // ── PDF Reader ────────────────────────────────────────────────────
  String get pdfView {
    if (locale == 'de') return 'PDF-Ansicht';
    if (locale == 'ar') return 'عرض PDF';
    return 'PDF View';
  }
  String get textView {
    if (locale == 'de') return 'Textansicht';
    if (locale == 'ar') return 'عرض النص';
    return 'Text View';
  }
  String get pickPdf {
    if (locale == 'de') return 'PDF auswählen';
    if (locale == 'ar') return 'اختيار PDF';
    return 'Pick PDF';
  }

  // ── Add Word ──────────────────────────────────────────────────────
  String get addWordTitle {
    if (locale == 'de') return 'Wort hinzufügen';
    if (locale == 'ar') return 'إضافة كلمة';
    return 'Add Word';
  }
  String get wordLabel {
    if (locale == 'de') return 'Wort';
    if (locale == 'ar') return 'الكلمة';
    return 'Word';
  }
  String get translating {
    if (locale == 'de') return 'Übersetze...';
    if (locale == 'ar') return '...جار الترجمة';
    return 'Translating...';
  }
  String get saveWord {
    if (locale == 'de') return 'Speichern';
    if (locale == 'ar') return 'حفظ';
    return 'Save';
  }

  // ── Settings ──────────────────────────────────────────────────────
  String get settingsTitle {
    if (locale == 'de') return 'Einstellungen';
    if (locale == 'ar') return 'الإعدادات';
    return 'Settings';
  }
  String get appLanguage {
    if (locale == 'de') return 'App-Sprache';
    if (locale == 'ar') return 'لغة التطبيق';
    return 'App Language';
  }
  String get appLanguageDesc {
    if (locale == 'de') return 'Sprache der Benutzeroberfläche';
    if (locale == 'ar') return 'لغة واجهة المستخدم';
    return 'User interface language';
  }
  String get translateLanguage {
    if (locale == 'de') return 'Standard-Übersetzungssprache';
    if (locale == 'ar') return 'لغة الترجمة الافتراضية';
    return 'Default Translate To Language';
  }
  String get translateLanguageDesc {
    if (locale == 'de') return 'Zielsprache für KI-Übersetzungen';
    if (locale == 'ar') return 'اللغة الهدف لترجمات الذكاء الاصطناعي';
    return 'Target language for AI translations';
  }

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
