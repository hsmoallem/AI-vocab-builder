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

  User? get currentUser => auth.currentUser;
  bool get isSignedIn => currentUser != null;
  bool get isAnonymous => currentUser?.isAnonymous ?? false;
  Stream<User?> authStateChanges() => auth.authStateChanges();

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
    return credential.user!;
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
        'created_at': word.createdAt.toIso8601String(),
        'updated_at': word.updatedAt.toIso8601String(),
      };

  Word _wordFromFirestore(Map<String, dynamic> data) {
    DateTime parseDate(String? val) {
      if (val == null) return DateTime.now();
      try { return DateTime.parse(val); } catch (_) { return DateTime.now(); }
    }

    return Word(
      word: (data['word'] as String?) ?? '',
      translation: (data['translation'] as String?) ?? '',
      exampleSource: (data['example_source'] as String?) ?? '',
      exampleTarget: (data['example_target'] as String?) ?? '',
      sourceLang: (data['source_lang'] as String?) ?? '',
      targetLang: (data['target_lang'] as String?) ?? '',
      isReviewed: (data['is_reviewed'] as bool?) ?? false,
      createdAt: parseDate(data['created_at'] as String?),
      updatedAt: parseDate(data['updated_at'] as String?),
    );
  }
}
