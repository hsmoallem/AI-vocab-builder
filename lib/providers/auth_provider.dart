/// ─── Auth Provider ───────────────────────────────────────────────────
///
/// ChangeNotifier wrapping Firebase Auth state.
/// Supports Google Sign-In and Anonymous sign-in.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/firebase_service.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseService _firebase = FirebaseService.instance;
  User? _user;
  bool _isLoading = true;
  String? _error;

  AuthProvider() {
    // Local-only mode (e.g. web without a Firebase config): no auth backend,
    // so don't wait on an auth stream — report signed-out immediately.
    if (!_firebase.isInitialized) {
      _isLoading = false;
      return;
    }
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

  Future<bool> signInWithGoogle() => _guard(() => _firebase.signInWithGoogle());
  Future<bool> signInAnonymously() => _guard(() => _firebase.signInAnonymously());

  Future<void> signOut() async {
    await _firebase.signOut();
    _user = null;
    notifyListeners();
  }

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
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }
}
