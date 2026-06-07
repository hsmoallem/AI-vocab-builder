/// ─── Auth Provider ───────────────────────────────────────────────────
///
/// ChangeNotifier wrapping Firebase Auth state.
/// Widgets rebuild when the user signs in, switches accounts, or signs out.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/firebase_service.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseService _firebase = FirebaseService.instance;
  User? _user;
  bool _isLoading = true;
  String? _error;

  AuthProvider() {
    _firebase.authStateChanges().listen((User? user) {
      _user = user;
      _isLoading = false;
      _error = null;
      notifyListeners();
    });
  }

  User? get user => _user;
  bool get isSignedIn => _user != null;
  bool get isAnonymous => _firebase.isAnonymous;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get email => _user?.email;
  String? get displayName => _user?.displayName;
  String? get photoUrl => _user?.photoURL;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── Google ──────────────────────────────────────────────────────────

  Future<bool> signInWithGoogle() => _guard(() => _firebase.signInWithGoogle());

  // ── Email/Password ──────────────────────────────────────────────────

  Future<bool> signInWithEmail(String email, String password) async {
    return _guard(() => _firebase.signInWithEmail(email: email, password: password));
  }

  Future<bool> registerWithEmail(String email, String password) async {
    return _guard(() => _firebase.registerWithEmail(email: email, password: password));
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _firebase.sendPasswordResetEmail(email);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Anonymous ───────────────────────────────────────────────────────

  Future<bool> signInAnonymously() => _guard(() => _firebase.signInAnonymously());

  // ── Sign Out ────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _firebase.signOut();
    _user = null;
    notifyListeners();
  }

  // ── Internal ────────────────────────────────────────────────────────

  /// Wrap any auth call that returns a User? or User.
  /// Sets loading/error state and returns true on success.
  Future<bool> _guard(Future<User?> Function() fn) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final user = await fn();
      _isLoading = false;
      notifyListeners();
      return user != null;
    } catch (e) {
      _isLoading = false;
      _error = _friendlyError(e.toString());
      notifyListeners();
      return false;
    }
  }

  /// Translate Firebase error codes into user-friendly German messages
  /// (since the app's target audience is German speakers).
  String _friendlyError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('invalid-credential') || lower.contains('wrong-password') || lower.contains('user-not-found')) {
      return 'Wrong email or password.';
    }
    if (lower.contains('email-already-in-use')) {
      return 'This email is already registered.';
    }
    if (lower.contains('weak-password')) {
      return 'Password must be at least 6 characters.';
    }
    if (lower.contains('invalid-email')) {
      return 'Please enter a valid email address.';
    }
    if (lower.contains('network-request-failed')) {
      return 'No internet connection. Check your Wi-Fi.';
    }
    if (lower.contains('too-many-requests')) {
      return 'Too many attempts. Please try again later.';
    }
    // Fallback: strip the "Exception: " prefix and Firebase domain
    return raw.replaceFirst('Exception: ', '').replaceFirst(RegExp(r'\[.*\] '), '');
  }
}
