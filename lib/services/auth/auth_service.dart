import 'package:firebase_auth/firebase_auth.dart';

/// Abstract authentication service interface.
/// This allows for easy testing and swapping implementations.
abstract class AuthService {
  /// Stream of authentication state changes
  Stream<User?> get authStateChanges;

  /// Currently signed in user
  User? get currentUser;

  /// Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  /// Create a new account with email and password
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  });

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle();

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email);

  /// Sign out
  Future<void> signOut();

  /// Update user profile display name
  Future<void> updateDisplayName(String displayName);

  /// Check if current user is signed in with Google
  bool isSignedInWithGoogle();
}
