/// ─── Firebase Service ────────────────────────────────────────────────
///
/// Handles Firebase initialization, Google Sign-In authentication,
/// and Firestore cloud backup/restore of vocabulary words.
///
/// ## Architecture
/// - **Auth:** Google Sign-In → Firebase Auth credential → signed-in user
/// - **Backup:** Each user's words stored under `users/{uid}/words/{wordId}`
/// - **Restore:** Reads all words from Firestore, returns them for local merge
///
/// ## Security note
/// Firestore security rules should restrict read/write to the authenticated
/// user's own data only. The `google-services.json` file is NOT committed
/// to git — it's provided by the developer via Firebase Console.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/word.dart';

class FirebaseService {
  static final FirebaseService instance = FirebaseService._();
  FirebaseService._();

  FirebaseAuth get auth => FirebaseAuth.instance;
  FirebaseFirestore get firestore => FirebaseFirestore.instance;

  /// Initialize Firebase. Must be called before any other Firebase operation.
  /// Call once at app startup (in main.dart).
  Future<void> init() async {
    await Firebase.initializeApp();
  }

  /// Get the currently signed-in user, or null if not signed in.
  User? get currentUser => auth.currentUser;

  /// Whether the user is currently signed in.
  bool get isSignedIn => currentUser != null;

  /// Stream of auth state changes. Emits null when signed out.
  Stream<User?> authStateChanges() => auth.authStateChanges();

  /// Sign in with Google.
  /// Returns the signed-in [User], or null if the user cancelled.
  Future<User?> signInWithGoogle() async {
    try {
      // Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        // User cancelled the sign-in dialog
        return null;
      }

      // Get auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a Firebase credential from the Google token
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the credential
      final userCredential = await auth.signInWithCredential(credential);
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      // Re-throw so the UI can show a meaningful error
      throw Exception('Sign-in failed: ${e.message}');
    }
  }

  /// Sign out of both Firebase and Google.
  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await auth.signOut();
  }

  // ═════════════════════════════════════════════════════════════════════
  // Firestore Cloud Backup
  // ═════════════════════════════════════════════════════════════════════

  /// Upload all words to Firestore under the current user's collection.
  /// Overwrites existing words with the same ID.
  Future<void> backupWords(List<Word> words) async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    final batch = firestore.batch();
    final wordsRef = firestore.collection('users').doc(uid).collection('words');

    for (final word in words) {
      final docRef = wordsRef.doc(word.id?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString());
      batch.set(docRef, _wordToFirestore(word));
    }

    await batch.commit();
  }

  /// Restore all words from Firestore for the current user.
  /// Returns an empty list if the user has no backed-up words.
  Future<List<Word>> restoreWords() async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    final snapshot = await firestore
        .collection('users')
        .doc(uid)
        .collection('words')
        .get();

    return snapshot.docs.map((doc) {
      return _wordFromFirestore(doc.id, doc.data());
    }).toList();
  }

  /// Check if the user has any backed-up data.
  Future<bool> hasBackup() async {
    final uid = currentUser?.uid;
    if (uid == null) return false;

    final snapshot = await firestore
        .collection('users')
        .doc(uid)
        .collection('words')
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  /// Delete all backed-up words for the current user.
  Future<void> deleteBackup() async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    final snapshot = await firestore
        .collection('users')
        .doc(uid)
        .collection('words')
        .get();

    final batch = firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ═════════════════════════════════════════════════════════════════════
  // Firestore ↔ Word conversion helpers
  // ═════════════════════════════════════════════════════════════════════

  Map<String, dynamic> _wordToFirestore(Word word) {
    return {
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
  }

  Word _wordFromFirestore(String docId, Map<String, dynamic> data) {
    DateTime parseDate(String? val) {
      if (val == null) return DateTime.now();
      try {
        return DateTime.parse(val);
      } catch (_) {
        return DateTime.now();
      }
    }

    return Word(
      // Firestore doc ID is stored but local SQLite will assign its own
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
