// Verifies AuthProvider is safe in "local-only" mode — i.e. when Firebase
// is not initialized (as on web without a firebase_options config). It must
// construct without touching Firebase and report a signed-out, not-loading
// state, so consumers (LoginScreen/HomeScreen) never crash.

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_vocab_builder/providers/auth_provider.dart';

void main() {
  test('constructs without Firebase and reports signed-out / not-loading', () {
    // Firebase.initializeApp() is never called in tests, so isInitialized is
    // false and AuthProvider must take its local-only path.
    final auth = AuthProvider();
    expect(auth.isSignedIn, isFalse);
    expect(auth.isLoading, isFalse); // must NOT hang waiting on an auth stream
    expect(auth.isAnonymous, isFalse);
    expect(auth.user, isNull);
  });
}
