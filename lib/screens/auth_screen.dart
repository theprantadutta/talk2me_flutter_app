// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  bool isLoading = false;

  // Controllers for form fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  @override
  void initState() {
    super.initState();
    // Initialize Google Sign In with web client ID from environment
    _googleSignIn.initialize(
      serverClientId: dotenv.env['GOOGLE_WEB_CLIENT_ID'],
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      _showErrorSnackBar('Please fill in all fields');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Attempt to sign in
      final UserCredential userCredential = await _auth
          .signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      // After successful Firebase sign-in, ensure user data exists in Firestore
      final User? user = userCredential.user;
      if (user != null) {
        final userDocRef = _firestore.collection('users').doc(user.uid);
        final userDoc = await userDocRef.get();

        if (!userDoc.exists) {
          // This case should ideally not happen if users are created correctly during signup.
          // However, as a fallback, create a basic user profile.
          String emailPrefix =
              user.email?.split('@').first ??
              'user_${user.uid.substring(0, 5)}';
          await userDocRef.set({
            'uid': user.uid,
            'fullName':
                user.displayName ??
                _emailController.text.split('@').first, // Fallback name
            'username': emailPrefix, // Fallback username
            'email': user.email ?? _emailController.text.trim(),
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'isOnline': true,
            'lastSeen': FieldValue.serverTimestamp(),
          });
        } else {
          // User exists, update their online status and last seen
          await userDocRef.update({
            'isOnline': true,
            'lastSeen': FieldValue.serverTimestamp(),
          });
        }

        if (mounted) {
          _showSuccessSnackBar('Login successful!');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => HomeScreen(currentUserId: user.uid),
            ),
          );
        }
      } else {
        if (mounted) _showErrorSnackBar('Login failed. User not found.');
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'An error occurred';
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password. Please try again.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is not valid.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled.';
          break;
        default:
          errorMessage = e.message ?? 'Login failed. Please try again.';
      }
      if (mounted) _showErrorSnackBar(errorMessage);
    } catch (e) {
      if (kDebugMode) print("Login error: $e");
      if (mounted) {
        _showErrorSnackBar('An unexpected error occurred: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _signup() async {
    if (_fullNameController.text.trim().isEmpty ||
        _usernameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      _showErrorSnackBar('Please fill in all fields');
      return;
    }

    if (_passwordController.text.length < 6) {
      _showErrorSnackBar('Password must be at least 6 characters');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Check if username already exists
      final usernameQuery =
          await _firestore
              .collection('users')
              .where('username', isEqualTo: _usernameController.text.trim())
              .get();

      if (usernameQuery.docs.isNotEmpty) {
        _showErrorSnackBar('Username already taken. Please choose another.');
        if (mounted) setState(() => isLoading = false);
        return;
      }

      // Create user with Firebase Auth
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      final User? user = userCredential.user;

      if (user != null) {
        // Add user to Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'fullName': _fullNameController.text.trim(),
          'username':
              _usernameController.text
                  .trim()
                  .toLowerCase(), // Store username in lowercase
          'email': _emailController.text.trim(),
          'avatarUrl':
              user.photoURL ??
              '', // Store avatar if available (e.g., from social sign-up later)
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'isOnline': true,
          'lastSeen': FieldValue.serverTimestamp(),
        });

        // Update display name in Firebase Auth profile
        await user.updateDisplayName(_fullNameController.text.trim());
        // You could also update photoURL here if you have one at signup

        if (mounted) {
          _showSuccessSnackBar('Account created successfully!');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => HomeScreen(currentUserId: user.uid),
            ),
          );
        }
      } else {
        if (mounted) {
          _showErrorSnackBar('Account creation failed. User not returned.');
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'An error occurred';
      switch (e.code) {
        case 'weak-password':
          errorMessage = 'The password provided is too weak.';
          break;
        case 'email-already-in-use':
          errorMessage = 'An account already exists with this email.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is not valid.';
          break;
        default:
          errorMessage = e.message ?? 'Signup failed. Please try again.';
      }
      if (mounted) _showErrorSnackBar(errorMessage);
    } catch (e) {
      if (kDebugMode) print("Signup error: $e");
      if (mounted) {
        _showErrorSnackBar('An unexpected error occurred: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter your email address to reset password.');
      return;
    }

    setState(() => isLoading = true);
    try {
      await _auth.sendPasswordResetEmail(email: _emailController.text.trim());
      if (mounted) {
        _showSuccessSnackBar('Password reset email sent! Check your inbox.');
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'An error occurred';
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is not valid.';
          break;
        default:
          errorMessage = e.message ?? 'Failed to send reset email.';
      }
      if (mounted) _showErrorSnackBar(errorMessage);
    } catch (e) {
      if (kDebugMode) print("Reset password error: $e");
      if (mounted) {
        _showErrorSnackBar('An unexpected error occurred: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      // Check if platform supports authentication
      if (!_googleSignIn.supportsAuthenticate()) {
        if (mounted) {
          _showErrorSnackBar('Google Sign-In is not supported on this platform.');
        }
        return;
      }

      // Trigger the authentication flow
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // Validate ID token
      if (googleAuth.idToken == null) {
        if (mounted) {
          _showErrorSnackBar('Failed to get Google ID token.');
        }
        return;
      }

      // Create a new credential using only the ID token
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final User? user = userCredential.user;

      if (user == null) {
        if (mounted) {
          _showErrorSnackBar(
            'Failed to sign in with Google. No user returned.',
          );
        }
        return;
      }

      // Create or update user profile in Firestore
      final userDocRef = _firestore.collection('users').doc(user.uid);
      final userDoc = await userDocRef.get();

      if (!userDoc.exists) {
        await userDocRef.set({
          'uid': user.uid,
          'fullName': user.displayName ?? 'Google User',
          'username':
              user.email?.split('@').first ??
              'googleuser_${user.uid.substring(0, 5)}',
          'email': user.email ?? '',
          'avatarUrl': user.photoURL ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'isOnline': true,
          'lastSeen': FieldValue.serverTimestamp(),
          'authProvider': 'google',
        });
      } else {
        await userDocRef.update({
          'lastSeen': FieldValue.serverTimestamp(),
          'isOnline': true,
          if (user.displayName != null &&
              user.displayName != userDoc.data()?['fullName'])
            'fullName': user.displayName,
          if (user.photoURL != null &&
              user.photoURL != userDoc.data()?['avatarUrl'])
            'avatarUrl': user.photoURL,
        });
      }

      if (mounted) {
        _showSuccessSnackBar('Google Sign-In successful!');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => HomeScreen(currentUserId: user.uid),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Google Sign-In failed.';
      if (e.code == 'account-exists-with-different-credential') {
        errorMessage =
            'An account already exists with the same email address using a different sign-in method.';
      } else if (e.code == 'invalid-credential') {
        errorMessage = 'Invalid Google credentials.';
      } else {
        errorMessage = e.message ?? errorMessage;
      }
      if (mounted) _showErrorSnackBar(errorMessage);
    } catch (e) {
      if (kDebugMode) print('Google Sign-In error: $e');
      if (mounted) {
        _showErrorSnackBar(
          'An unexpected error occurred during Google Sign-In: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error, // Use theme color
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green, // Or a success color from your theme
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Get the current theme

    return Scaffold(
      backgroundColor: theme.colorScheme.surface, // Use theme background
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.2,
                          ),
                          spreadRadius: 1,
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        // Make sure this asset exists
                        'assets/logo.png',
                        height: 100,
                        width: 100,
                        errorBuilder:
                            (context, error, stackTrace) => Icon(
                              Icons.lock_person_rounded,
                              size: 80,
                              color: theme.colorScheme.primary,
                            ),
                      ).animate().fade(duration: 400.ms).scale(delay: 200.ms),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isLogin ? 'Welcome Back!' : 'Create Your Account',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ).animate().fade(duration: 400.ms, delay: 300.ms),
                  const SizedBox(height: 8),
                  Text(
                    isLogin
                        ? 'Sign in to continue your journey.'
                        : 'Fill in the details to get started.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.hintColor,
                    ),
                  ).animate().fade(duration: 400.ms, delay: 400.ms),
                  const SizedBox(height: 32),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    transitionBuilder: (
                      Widget child,
                      Animation<double> animation,
                    ) {
                      final bool isNewChildLogin =
                          child.key == const ValueKey('login');
                      final offsetAnimation = Tween<Offset>(
                        begin: Offset(isNewChildLogin ? -1.0 : 1.0, 0.0),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeInOutCubic,
                        ),
                      );
                      return SlideTransition(
                        position: offsetAnimation,
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
                    child: isLogin ? _buildLoginForm() : _buildSignupForm(),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isLogin
                            ? "Don't have an account? "
                            : "Already have an account? ",
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                      TextButton(
                        onPressed:
                            isLoading
                                ? null
                                : () {
                                  setState(() {
                                    isLogin = !isLogin;
                                    _emailController.clear();
                                    _passwordController.clear();
                                    _fullNameController.clear();
                                    _usernameController.clear();
                                  });
                                },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: theme.colorScheme.primary,
                        ),
                        child: Text(
                          isLogin ? "Sign Up" : "Login",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ).animate().fade(duration: 300.ms, delay: 600.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showPasswordResetDialog() async {
    final theme = Theme.of(context);
    final TextEditingController emailController = TextEditingController();
    // Create a new GlobalKey for the form within the dialog
    final GlobalKey<FormState> dialogFormKey = GlobalKey<FormState>();

    return showDialog<void>(
      context: context,
      barrierDismissible: !isLoading, // Prevent dismissing while loading
      builder: (BuildContext dialogContext) {
        // Use a StatefulBuilder to manage the isLoading state within the dialog
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: theme.dialogTheme.backgroundColor ?? theme.colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Reset Password',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    Text(
                      'Enter your email address and we will send you a link to reset your password.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Form(
                      key: dialogFormKey,
                      child: TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          labelStyle: TextStyle(color: theme.hintColor),
                          hintText: 'you@example.com',
                          hintStyle: TextStyle(
                            color: theme.hintColor.withValues(alpha: 0.7),
                          ),
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: theme.iconTheme.color?.withValues(
                              alpha: 0.7,
                            ),
                          ),
                          filled: true,
                          fillColor:
                              theme.inputDecorationTheme.fillColor ??
                              theme.colorScheme.surfaceContainerHighest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: theme.colorScheme.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your email address.';
                          }
                          if (!RegExp(
                            r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
                          ).hasMatch(value)) {
                            return 'Please enter a valid email address.';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              actions: <Widget>[
                TextButton(
                  onPressed:
                      isLoading
                          ? null
                          : () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: theme.hintColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  icon:
                      isLoading
                          ? Container(
                            width: 18,
                            height: 18,
                            padding: const EdgeInsets.all(2.0),
                            child: CircularProgressIndicator(
                              color: theme.colorScheme.onPrimary,
                              strokeWidth: 2,
                            ),
                          )
                          : Icon(
                            Icons.send_rounded,
                            size: 18,
                            color: theme.colorScheme.onPrimary,
                          ),
                  label: Text(
                    'Send Link',
                    style: TextStyle(color: theme.colorScheme.onPrimary),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  onPressed:
                      isLoading
                          ? null
                          : () async {
                            if (dialogFormKey.currentState!.validate()) {
                              // Use setDialogState to update the dialog's internal loading state
                              setDialogState(() {
                                isLoading =
                                    true; // This isLoading should be local to the dialog or passed to it
                              });
                              // Call the main screen's reset password logic
                              await _handlePasswordResetFromDialog(
                                emailController.text.trim(),
                                dialogContext,
                                setDialogState,
                              );
                            }
                          },
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      // Ensure isLoading on the main screen is reset if the dialog is dismissed by other means
      // This might be redundant if _handlePasswordResetFromDialog always resets it,
      // but good for safety.
      if (mounted && isLoading) {
        // Check isLoading of the AuthScreen's state
        setState(() {
          isLoading = false;
        });
      }
    });
  }

  // Helper function to handle the actual password reset logic
  // It takes setDialogState to manage the dialog's loading indicator
  Future<void> _handlePasswordResetFromDialog(
    String email,
    BuildContext dialogContext,
    StateSetter setDialogState,
  ) async {
    // No need to set isLoading = true here for the main screen's state,
    // as the dialog is managing its own loading indicator via setDialogState.
    // The main screen's isLoading is primarily for the main login/signup buttons.

    try {
      await _auth.sendPasswordResetEmail(email: email);
      if (mounted) {
        Navigator.of(dialogContext).pop(); // Close the dialog
        _showSuccessSnackBar(
          'Password reset email sent to $email! Check your inbox (and spam folder).',
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Failed to send reset email.';
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email address.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is not valid.';
          break;
        default:
          errorMessage = e.message ?? errorMessage;
      }
      // Don't pop the dialog on error, so user can see the message or try again
      if (mounted) {
        _showErrorSnackBar(
          errorMessage,
        ); // Show error on the main screen's scaffold
      }
    } catch (e) {
      if (kDebugMode) print("Password Reset Dialog error: $e");
      if (mounted) {
        _showErrorSnackBar('An unexpected error occurred: ${e.toString()}');
      }
    } finally {
      // Reset the dialog's loading state
      if (mounted) {
        // Check if the main screen is still mounted
        setDialogState(() {
          isLoading = false; // Reset dialog's isLoading state
        });
        // Also ensure the main screen's isLoading is false if it was set by the dialog's button.
        // This is tricky because the dialog has its own isLoading.
        // The main _resetPassword function in AuthScreen should handle its own isLoading state.
        // This dialog's isLoading is primarily for the "Send Link" button within the dialog.
      }
    }
  }

  Widget _buildLoginForm() {
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('login'),
      children: [
        CustomTextField(
          label: 'Email Address',
          icon: Icons.email_outlined,
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          label: 'Password',
          icon: Icons.lock_outline,
          obscureText: true,
          controller: _passwordController,
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _showPasswordResetDialog,
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: isLoading ? null : _resetPassword,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: theme.hintColor,
              ),
              child: Text(
                'Forgot Password?',
                style: TextStyle(color: theme.hintColor, fontSize: 13),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        CustomButton(
          text: isLoading ? 'Logging in...' : 'Login',
          onPressed: isLoading ? null : _login,
          isLoading: isLoading,
        ),
        const SizedBox(height: 24),
        _buildSocialLogin(),
      ],
    );
  }

  Widget _buildSignupForm() {
    return Column(
      key: const ValueKey('signup'),
      children: [
        CustomTextField(
          label: 'Full Name',
          icon: Icons.person_outline,
          controller: _fullNameController,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          label: 'Username',
          icon: Icons.alternate_email_outlined,
          controller: _usernameController,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          label: 'Email Address',
          icon: Icons.email_outlined,
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          label: 'Password (min. 6 characters)',
          icon: Icons.lock_outline,
          obscureText: true,
          controller: _passwordController,
        ),
        const SizedBox(height: 24),
        CustomButton(
          text: isLoading ? 'Creating Account...' : 'Create Account',
          onPressed: isLoading ? null : _signup,
          isLoading: isLoading,
        ),
        const SizedBox(height: 24),
        _buildSocialLogin(),
      ],
    );
  }

  Widget _buildSocialLogin() {
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Divider(
                thickness: 1,
                color: theme.dividerColor.withValues(alpha: 0.2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'OR',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.hintColor.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                thickness: 1,
                color: theme.dividerColor.withValues(alpha: 0.2),
              ),
            ),
          ],
        ),
        if (!Platform.isWindows)
          Column(
            children: [
              const SizedBox(height: 20),
              SocialButton(
                text: 'Continue with Google',
                icon: FontAwesomeIcons.google,
                // iconColor: theme.colorScheme.error, // Google's red, or let theme decide
                onPressed: isLoading ? null : _handleGoogleSignIn,
              ),
            ],
          ),
      ],
    );
  }
}

class CustomTextField extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool obscureText;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconPressed;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  const CustomTextField({
    super.key,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.suffixIcon,
    this.onSuffixIconPressed,
    this.controller,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _isObscured = false;
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _isObscured = widget.obscureText;
    _focusNode.addListener(() {
      if (mounted) {
        setState(() {
          _isFocused = _focusNode.hasFocus;
        });
      }
    });
  }

  @override
  void dispose() {
    _focusNode.removeListener(() {});
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inputDecorationTheme = theme.inputDecorationTheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color:
            inputDecorationTheme.fillColor ??
            theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(
          inputDecorationTheme.border is OutlineInputBorder
              ? (inputDecorationTheme.border as OutlineInputBorder)
                  .borderRadius
                  .topLeft
                  .x
              : 12,
        ),
        border: Border.all(
          color:
              _isFocused
                  ? theme.colorScheme.primary
                  : (inputDecorationTheme.enabledBorder as OutlineInputBorder?)
                          ?.borderSide
                          .color ??
                      theme.dividerColor.withValues(alpha: 0.2),
          width:
              _isFocused
                  ? 1.5
                  : (inputDecorationTheme.enabledBorder as OutlineInputBorder?)
                          ?.borderSide
                          .width ??
                      1,
        ),
        boxShadow:
            _isFocused
                ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
                : [],
      ),
      child: TextField(
        focusNode: _focusNode,
        controller: widget.controller,
        obscureText: _isObscured,
        keyboardType: widget.keyboardType,
        textCapitalization: widget.textCapitalization,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          contentPadding:
              inputDecorationTheme.contentPadding ??
              const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          border: InputBorder.none, // Handled by container
          hintText: widget.label,
          hintStyle:
              inputDecorationTheme.hintStyle ??
              TextStyle(
                color: theme.hintColor.withValues(alpha: 0.7),
                fontSize: 14,
              ),
          prefixIcon: Icon(
            widget.icon,
            color:
                _isFocused
                    ? theme.colorScheme.primary
                    : theme.iconTheme.color?.withValues(alpha: 0.7),
            size: 20,
          ),
          suffixIcon: _buildSuffixIcon(),
        ),
      ),
    );
  }

  Widget? _buildSuffixIcon() {
    final theme = Theme.of(context);
    if (widget.obscureText) {
      return IconButton(
        icon: Icon(
          _isObscured
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color:
              _isFocused
                  ? theme.colorScheme.primary
                  : theme.iconTheme.color?.withValues(alpha: 0.7),
          size: 20,
        ),
        onPressed: () {
          setState(() {
            _isObscured = !_isObscured;
          });
        },
      );
    } else if (widget.suffixIcon != null) {
      return IconButton(
        icon: Icon(
          widget.suffixIcon,
          color:
              _isFocused
                  ? theme.colorScheme.primary
                  : theme.iconTheme.color?.withValues(alpha: 0.7),
          size: 20,
        ),
        onPressed: widget.onSuffixIconPressed,
      );
    }
    return null;
  }
}

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: onPressed == null ? 0 : 2,
          shadowColor: theme.colorScheme.primary.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child:
            isLoading
                ? SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    color: theme.colorScheme.onPrimary,
                    strokeWidth: 2.5,
                  ),
                )
                : Text(
                  text,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
      ),
    );
  }
}

class SocialButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color? iconColor; // Allow custom icon color, but prefer theme
  final VoidCallback? onPressed;

  const SocialButton({
    super.key,
    required this.text,
    required this.icon,
    this.iconColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Determine icon color: use provided, then try to infer from brand, then fallback to theme.
    Color finalIconColor;
    if (iconColor != null) {
      finalIconColor = iconColor!;
    } else if (icon == FontAwesomeIcons.google) {
      // Google's red is often #DB4437 or similar.
      // You might want to define specific brand colors in your theme if you use them often.
      finalIconColor = const Color(0xFFDB4437); // Example Google Red
    } else {
      finalIconColor =
          theme.colorScheme.primary; // Default to primary theme color
    }

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: FaIcon(icon, color: finalIconColor, size: 18),
        label: Text(
          text,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.surface,
          foregroundColor: theme.colorScheme.onSurface, // For ripple effect
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: theme.dividerColor.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}
