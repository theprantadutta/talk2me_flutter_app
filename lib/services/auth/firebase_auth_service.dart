import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_service.dart';

/// Firebase implementation of [AuthService].
class FirebaseAuthService implements AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _isGoogleSignInInitialized = false;

  FirebaseAuthService() {
    _initializeGoogleSignIn();
  }

  void _initializeGoogleSignIn() {
    if (!_isGoogleSignInInitialized) {
      _googleSignIn.initialize(
        serverClientId: dotenv.env['GOOGLE_WEB_CLIENT_ID'],
      );
      _isGoogleSignInInitialized = true;
    }
  }

  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Check if platform supports authentication
      if (!_googleSignIn.supportsAuthenticate()) {
        if (kDebugMode) {
          print('Google Sign-In is not supported on this platform.');
        }
        return null;
      }

      // Trigger the authentication flow
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // Validate ID token
      if (googleAuth.idToken == null) {
        throw Exception('Failed to get Google ID token');
      }

      // Create a new credential using only the ID token
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      if (kDebugMode) {
        print('Google Sign-In error: $e');
      }
      rethrow;
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  @override
  Future<void> signOut() async {
    // Sign out from Google if signed in with Google
    if (isSignedInWithGoogle()) {
      await _googleSignIn.signOut();
    }
    await _auth.signOut();
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    await currentUser?.updateDisplayName(displayName);
  }

  @override
  bool isSignedInWithGoogle() {
    final user = currentUser;
    if (user == null) return false;
    return user.providerData.any(
      (provider) => provider.providerId == 'google.com',
    );
  }
}
