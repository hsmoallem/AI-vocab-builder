/// ─── Firebase Service ────────────────────────────────────────────────
///
/// Handles Firebase initialization, all authentication methods
/// (Google, Email/Password, Anonymous), and Firestore cloud backup/restore.
///
/// ## Auth Methods
/// - **Google:** One-tap sign-in with Google account
/// - **Email/Password:** Traditional email + password with registration support
/// - **Anonymous:** Temporary account, no credentials needed
///
/// ## Security
/// Firestore security rules should restrict read/write to the authenticated
/// user's own data only. `google-services.json` is NOT committed to git.

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

  /// Initialize Firebase. Call once at app startup.
  Future<void> init() async {
    await Firebase.initializeApp();
  }

  /// Get the currently signed-in user, or null if not signed in.
  User? get currentUser => auth.currentUser;

  /// Whether the user is currently signed in (any method).
  bool get isSignedIn => currentUser != null;

  /// Whether the current user is anonymous (signed in with signInAnonymously).
  bool get isAnonymous => currentUser?.isAnonymous ?? false;

  /// Stream of auth state changes. Emits null when signed out.
  Stream<User?> authStateChanges() => auth.authStateChanges();

  // ═════════════════════════════════════════════════════════════════════
  // Google Sign-In
  // ═════════════════════════════════════════════════════════════════════

  /// Sign in with Google. Returns the signed-in [User], or null if cancelled.
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

  // ═════════════════════════════════════════════════════════════════════
  // Email/Password
  // ═════════════════════════════════════════════════════════════════════

  /// Sign in with email and password.
  /// Throws [FirebaseAuthException] if credentials are wrong.
  Future<User> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return credential.user!;
  }

  /// Register a new account with email and password.
  /// Throws [FirebaseAuthException] if email already in use or password too weak.
  Future<User> registerWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return credential.user!;
  }

  /// Send a password reset email to the given address.
  Future<void> sendPasswordResetEmail(String email) async {
    await auth.sendPasswordResetEmail(email: email.trim());
  }

  // ═════════════════════════════════════════════════════════════════════
  // Anonymous Sign-In
  // ═════════════════════════════════════════════════════════════════════

  /// Sign in anonymously — no credentials needed.
  /// Creates a temporary account. Data is lost if the user signs out
  /// or uninstalls the app without linking to a permanent account.
  Future<User> signInAnonymously() async {
    final credential = await auth.signInAnonymously();
    return credential.user!;
  }

  // ═════════════════════════════════════════════════════════════════════
  // Sign Out
  // ═════════════════════════════════════════════════════════════════════

  /// Sign out of all providers.
  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await auth.signOut();
  }

  // ═════════════════════════════════════════════════════════════════════
  // Firestore Cloud Backup
  // ═════════════════════════════════════════════════════════════════════

  /// Upload all words to Firestore under the current user.
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

  /// Restore all words from Firestore for the current user.
  Future<List<Word>> restoreWords() async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    final snapshot = await firestore
        .collection('users')
        .doc(uid)
        .collection('words')
        .get();

    return snapshot.docs.map((doc) {
      return _wordFromFirestore(doc.data());
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
  // Firestore ↔ Word conversion
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

  Word _wordFromFirestore(Map<String, dynamic> data) {
    DateTime parseDate(String? val) {
      if (val == null) return DateTime.now();
      try {
        return DateTime.parse(val);
      } catch (_) {
        return DateTime.now();
      }
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
