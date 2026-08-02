/// ─── Firebase Service ────────────────────────────────────────────────
///
/// Handles Firebase initialization, Google Sign-In + Anonymous auth,
/// and Firestore cloud backup/restore of vocabulary words.

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../firebase_options.dart';
import '../models/word.dart';
import 'database_service.dart';

class FirebaseService {
  static final FirebaseService instance = FirebaseService._();
  FirebaseService._();

  FirebaseAuth get auth => FirebaseAuth.instance;
  FirebaseFirestore get firestore => FirebaseFirestore.instance;

  /// Whether Firebase was successfully initialized.
  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<bool> init() async {
    try {
      // Platform-specific options from flutterfire configure — required on
      // web (there is no google-services.json there); harmless on Android.
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _initialized = true;
      return true;
    } catch (e) {
      debugPrint('Firebase init failed: $e');
      _initialized = false;
      return false;
    }
  }

  // Guard every Firebase-Auth access with [_initialized]: on web without a
  // firebase_options config, Firebase never initializes and touching
  // FirebaseAuth.instance would throw. In that "local-only" mode we simply
  // report signed-out.
  User? get currentUser => _initialized ? auth.currentUser : null;
  bool get isSignedIn => currentUser != null;
  bool get isAnonymous => currentUser?.isAnonymous ?? false;
  Stream<User?> authStateChanges() =>
      _initialized ? auth.authStateChanges() : const Stream<User?>.empty();

  // ── Google Sign-In ──────────────────────────────────────────────────

  Future<User?> signInWithGoogle() async {
    try {
      // Web: Firebase's own popup flow — no OAuth client-ID meta tag needed
      // (the google_sign_in plugin's web path requires one and throws without
      // it). The popup uses the authDomain from firebase_options.
      if (kIsWeb) {
        final userCredential = await auth.signInWithPopup(GoogleAuthProvider());
        return userCredential.user;
      }

      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await auth.signInWithCredential(credential);
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw Exception('Sign-in failed: ${e.message}');
    }
  }

  // ── Apple Sign-In ───────────────────────────────────────────────────

  Future<User?> signInWithApple() async {
    try {
      final appleProvider = AppleAuthProvider();
      appleProvider.addScope('email');
      appleProvider.addScope('name');

      if (kIsWeb) {
        final userCredential = await auth.signInWithPopup(appleProvider);
        return userCredential.user;
      } else {
        final userCredential = await auth.signInWithProvider(appleProvider);
        return userCredential.user;
      }
    } on FirebaseAuthException catch (e) {
      throw Exception('Apple sign-in failed: ${e.message}');
    } catch (e) {
      throw Exception('Apple sign-in failed: $e');
    }
  }

  // ── Anonymous ───────────────────────────────────────────────────────

  Future<User> signInAnonymously() async {
    final credential = await auth.signInAnonymously();
    final user = credential.user;
    if (user == null) {
      throw Exception('Anonymous sign-in failed — no user returned');
    }
    return user;
  }

  // ── Sign Out ────────────────────────────────────────────────────────

  Future<void> signOut() async {
    // GoogleSignIn's web path asserts without a client-ID meta tag; on web the
    // popup flow is used for sign-in, so only Firebase itself needs signing out.
    if (!kIsWeb) {
      await GoogleSignIn().signOut();
    }
    await auth.signOut();
  }

  // ── Firestore Backup ────────────────────────────────────────────────

  Future<int> backupWords(List<Word> words) async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    final wordsRef = firestore.collection('users').doc(uid).collection('words');
    final snapshot = await wordsRef.get();

    final currentWords = <String, Word>{};
    for (final word in words) {
      final safeId = base64Url.encode(utf8.encode(word.word.trim().toLowerCase()));
      currentWords[safeId] = word;
    }

    final operations = <Future<void>>[];
    var batch = firestore.batch();
    int opCount = 0;

    void commitBatchIfNeeded() {
      if (opCount == 500) {
        operations.add(batch.commit());
        batch = firestore.batch();
        opCount = 0;
      }
    }

    for (final doc in snapshot.docs) {
      if (!currentWords.containsKey(doc.id)) {
        batch.delete(doc.reference);
        opCount++;
        commitBatchIfNeeded();
      }
    }

    for (final entry in currentWords.entries) {
      batch.set(wordsRef.doc(entry.key), _wordToFirestore(entry.value));
      opCount++;
      commitBatchIfNeeded();
    }

    if (opCount > 0) {
      operations.add(batch.commit());
    }

    await Future.wait(operations);
    return currentWords.length;
  }

  Future<List<Word>> restoreWords() async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    final snapshot = await firestore
        .collection('users')
        .doc(uid)
        .collection('words')
        .get();

    return snapshot.docs.map((doc) => _wordFromFirestore(doc.data())).toList();
  }

  // ── Firestore Settings Backup / Restore ───────────────────────────────

  Future<void> backupSettings() async {
    final uid = currentUser?.uid;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    final settingsMap = <String, dynamic>{
      'app_locale': prefs.getString('app_locale') ?? 'en',
      'translate_target_lang': prefs.getString('translate_target_lang') ?? 'en',
      'new_cards_per_session': prefs.getInt('new_cards_per_session') ?? 30,
      'study_mode_default': prefs.getInt('study_mode_default') ?? 0,
      'auto_backup_frequency': prefs.getString('auto_backup_frequency') ?? 'off',
    };
    await firestore.collection('users').doc(uid).set({
      'settings': settingsMap,
    }, SetOptions(merge: true));
  }

  Future<void> restoreSettings() async {
    final uid = currentUser?.uid;
    if (uid == null) return;
    final doc = await firestore.collection('users').doc(uid).get();
    if (!doc.exists) return;
    final data = doc.data();
    if (data == null || data['settings'] == null || data['settings'] is! Map) return;

    final s = Map<String, dynamic>.from(data['settings'] as Map);
    final prefs = await SharedPreferences.getInstance();
    if (s['app_locale'] != null) await prefs.setString('app_locale', s['app_locale'].toString());
    if (s['translate_target_lang'] != null) await prefs.setString('translate_target_lang', s['translate_target_lang'].toString());
    if (s['new_cards_per_session'] != null) await prefs.setInt('new_cards_per_session', (s['new_cards_per_session'] as num).toInt());
    if (s['study_mode_default'] != null) await prefs.setInt('study_mode_default', (s['study_mode_default'] as num).toInt());
    if (s['auto_backup_frequency'] != null) await prefs.setString('auto_backup_frequency', s['auto_backup_frequency'].toString());
  }

  // ── Firestore Streak Sync ───────────────────────────────────────────

  Future<void> updateStreak(StreakSnapshot streak) async {
    final uid = currentUser?.uid;
    if (uid == null) return;
    await firestore.collection('users').doc(uid).set({
      'current_streak': streak.current,
      'longest_streak': streak.longest,
      'last_study_date': streak.lastStudyDate,
    }, SetOptions(merge: true));
  }

  Future<StreakSnapshot?> getStreak() async {
    final uid = currentUser?.uid;
    if (uid == null) return null;
    final doc = await firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    return StreakSnapshot(
      current: data['current_streak'] as int? ?? 0,
      longest: data['longest_streak'] as int? ?? 0,
      lastStudyDate: data['last_study_date'] as String?,
    );
  }

  Map<String, dynamic> _wordToFirestore(Word word) => {
        'word': word.word,
        'translation': word.translation,
        'example_source': word.exampleSource,
        'example_target': word.exampleTarget,
        'source_lang': word.sourceLang,
        'target_lang': word.targetLang,
        'is_reviewed': word.isReviewed,
        'note': word.note,
        'grammar_tip': word.grammarTip,
        'archived': word.archived,
        'second_lang': word.secondLang,
        'second_translation': word.secondTranslation,
        'created_at': word.createdAt.toIso8601String(),
        'updated_at': word.updatedAt.toIso8601String(),
        // SRS state (DB v4) — preserves spaced-repetition progress across
        // devices. Optional fields, so older backups without them still
        // restore cleanly via the null-coalescing in _wordFromFirestore.
        if (word.srsInterval != 0) 'srs_interval': word.srsInterval,
        if (word.srsEaseFactor != 2.5) 'srs_ease_factor': word.srsEaseFactor,
        if (word.srsRepetitions != 0) 'srs_repetitions': word.srsRepetitions,
        if (word.srsNextDue != null)
          'srs_next_due': word.srsNextDue!.toIso8601String(),
        if (word.srsLastReview != null)
          'srs_last_review': word.srsLastReview!.toIso8601String(),
        // AI Tutor canonical grammar fields (DB v6)
        if (word.partOfSpeech != null) 'part_of_speech': word.partOfSpeech,
        if (word.grammarData != null) 'grammar_data': jsonEncode(word.grammarData),
        if (word.usageNote != null) 'usage_note': word.usageNote,
        if (word.grammarVersion != 0) 'grammar_version': word.grammarVersion,
        if (word.grammarConfidence != null) 'grammar_confidence': word.grammarConfidence,
      };

  Word _wordFromFirestore(Map<String, dynamic> data) {
    DateTime parseDate(String? val) {
      if (val == null) return DateTime.now();
      try { return DateTime.parse(val); } catch (_) { return DateTime.now(); }
    }
    // SRS timestamps must preserve null (null srs_next_due = "new"/unscheduled).
    // Coercing to now() would restore every card as scheduled/studied.
    DateTime? parseNullableDate(String? val) {
      if (val == null) return null;
      try { return DateTime.parse(val); } catch (_) { return null; }
    }
    Map<String, dynamic>? parseGrammarData(dynamic val) {
      if (val == null) return null;
      if (val is Map<String, dynamic>) return val;
      if (val is Map) return Map<String, dynamic>.from(val);
      if (val is String && val.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(val);
          if (decoded is Map) return Map<String, dynamic>.from(decoded);
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    return Word(
      word: (data['word'] as String?) ?? '',
      translation: (data['translation'] as String?) ?? '',
      exampleSource: (data['example_source'] as String?) ?? '',
      exampleTarget: (data['example_target'] as String?) ?? '',
      sourceLang: (data['source_lang'] as String?) ?? '',
      targetLang: (data['target_lang'] as String?) ?? '',
      isReviewed: (data['is_reviewed'] as bool?) ?? false,
      note: data['note'] as String?,
      grammarTip: data['grammar_tip'] as String?,
      archived: (data['archived'] as bool?) ?? false,
      secondLang: data['second_lang'] as String?,
      secondTranslation: data['second_translation'] as String?,
      createdAt: parseDate(data['created_at'] as String?),
      updatedAt: parseDate(data['updated_at'] as String?),
      // SRS — absent in older backups → defaults via the model.
      srsInterval: (data['srs_interval'] as num?)?.toInt() ?? 0,
      srsEaseFactor: (data['srs_ease_factor'] as num?)?.toDouble() ?? 2.5,
      srsRepetitions: (data['srs_repetitions'] as num?)?.toInt() ?? 0,
      srsNextDue: parseNullableDate(data['srs_next_due'] as String?),
      srsLastReview: parseNullableDate(data['srs_last_review'] as String?),
      // AI Tutor enrichment (DB v6)
      partOfSpeech: data['part_of_speech'] as String?,
      grammarData: parseGrammarData(data['grammar_data']),
      usageNote: data['usage_note'] as String?,
      grammarVersion: (data['grammar_version'] as num?)?.toInt() ?? 0,
      grammarConfidence: (data['grammar_confidence'] as num?)?.toDouble(),
    );
  }
}
