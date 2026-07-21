/// ─── Firebase Service ────────────────────────────────────────────────
///
/// Handles Firebase initialization, Google Sign-In + Anonymous auth,
/// and Firestore cloud backup/restore of vocabulary words.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/word.dart';

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
      await Firebase.initializeApp();
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
    await GoogleSignIn().signOut();
    await auth.signOut();
  }

  // ── Firestore Backup ────────────────────────────────────────────────

  Future<void> backupWords(List<Word> words) async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    final batch = firestore.batch();
    final wordsRef = firestore.collection('users').doc(uid).collection('words');

    for (final word in words) {
      final docRef = wordsRef.doc(
        word.id?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      );
      batch.set(docRef, _wordToFirestore(word));
    }

    await batch.commit();
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
      createdAt: parseDate(data['created_at'] as String?),
      updatedAt: parseDate(data['updated_at'] as String?),
      // SRS — absent in older backups → defaults via the model.
      srsInterval: (data['srs_interval'] as num?)?.toInt() ?? 0,
      srsEaseFactor: (data['srs_ease_factor'] as num?)?.toDouble() ?? 2.5,
      srsRepetitions: (data['srs_repetitions'] as num?)?.toInt() ?? 0,
      srsNextDue: parseNullableDate(data['srs_next_due'] as String?),
      srsLastReview: parseNullableDate(data['srs_last_review'] as String?),
    );
  }
}
