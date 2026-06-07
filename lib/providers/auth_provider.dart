/// ─── Auth Provider ───────────────────────────────────────────────────
///
/// ChangeNotifier that wraps Firebase Auth state.
/// Widgets rebuild when the user signs in or out.
///
/// ## Usage
/// ```dart
/// final auth = context.watch<AuthProvider>();
/// if (auth.isSignedIn) { ... }
/// ```

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/firebase_service.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseService _firebase = FirebaseService.instance;
  User? _user;
  bool _isLoading = true;
  String? _error;

  AuthProvider() {
    _init();
  }

  User? get user => _user;
  bool get isSignedIn => _user != null;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get email => _user?.email;
  String? get displayName => _user?.displayName;
  String? get photoUrl => _user?.photoURL;

  /// Listen to Firebase auth state and update accordingly.
  void _init() {
    _firebase.authStateChanges().listen((User? user) {
      _user = user;
      _isLoading = false;
      _error = null;
      notifyListeners();
    });
  }

  /// Sign in with Google.
  /// Returns true on success, false if user cancelled.
  Future<bool> signIn() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final user = await _firebase.signInWithGoogle();
      _user = user;
      _isLoading = false;
      notifyListeners();
      return user != null;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Sign out.
  Future<void> signOut() async {
    await _firebase.signOut();
    _user = null;
    notifyListeners();
  }

  /// Clear any displayed error.
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
