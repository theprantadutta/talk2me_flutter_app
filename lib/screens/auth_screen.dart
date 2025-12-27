// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/constants/animation_constants.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../widgets/common/gradient_background.dart';
import '../widgets/glass/glass_button.dart';
import '../widgets/glass/glass_card.dart';
import '../widgets/glass/glass_container.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  bool isLogin = true;
  bool isLoading = false;

  // Controllers for form fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  // Animation controller for form transitions
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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

    _animationController = AnimationController(
      duration: AnimationConstants.normal,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _usernameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      _showErrorSnackBar('Please fill in all fields');
      return;
    }

    setState(() => isLoading = true);

    try {
      final UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final User? user = userCredential.user;
      if (user != null) {
        final userDocRef = _firestore.collection('users').doc(user.uid);
        final userDoc = await userDocRef.get();

        if (!userDoc.exists) {
          String emailPrefix =
              user.email?.split('@').first ?? 'user_${user.uid.substring(0, 5)}';
          await userDocRef.set({
            'uid': user.uid,
            'fullName': user.displayName ?? _emailController.text.split('@').first,
            'username': emailPrefix,
            'email': user.email ?? _emailController.text.trim(),
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'isOnline': true,
            'lastSeen': FieldValue.serverTimestamp(),
          });
        } else {
          await userDocRef.update({
            'isOnline': true,
            'lastSeen': FieldValue.serverTimestamp(),
          });
        }

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => HomeScreen(currentUserId: user.uid),
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'An error occurred during login.';
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password.';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email format.';
          break;
        case 'user-disabled':
          errorMessage = 'This user account has been disabled.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many login attempts. Try again later.';
          break;
        default:
          errorMessage = e.message ?? errorMessage;
      }
      _showErrorSnackBar(errorMessage);
    } catch (e) {
      if (kDebugMode) print("Login error: $e");
      _showErrorSnackBar('An unexpected error occurred: ${e.toString()}');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _signup() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty ||
        _fullNameController.text.trim().isEmpty ||
        _usernameController.text.trim().isEmpty) {
      _showErrorSnackBar('Please fill in all fields');
      return;
    }

    if (_passwordController.text.length < 6) {
      _showErrorSnackBar('Password must be at least 6 characters');
      return;
    }

    setState(() => isLoading = true);

    try {
      // Check if username is already taken
      final usernameQuery = await _firestore
          .collection('users')
          .where('username', isEqualTo: _usernameController.text.trim().toLowerCase())
          .limit(1)
          .get();

      if (usernameQuery.docs.isNotEmpty) {
        _showErrorSnackBar('Username is already taken');
        setState(() => isLoading = false);
        return;
      }

      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final User? user = userCredential.user;
      if (user != null) {
        await user.updateDisplayName(_fullNameController.text.trim());

        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'fullName': _fullNameController.text.trim(),
          'username': _usernameController.text.trim().toLowerCase(),
          'email': _emailController.text.trim(),
          'avatarUrl': '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'isOnline': true,
          'lastSeen': FieldValue.serverTimestamp(),
          'authProvider': 'email',
        });

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => HomeScreen(currentUserId: user.uid),
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'An error occurred during signup.';
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'An account already exists with this email.';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email format.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Email/password accounts are not enabled.';
          break;
        case 'weak-password':
          errorMessage = 'Password is too weak.';
          break;
        default:
          errorMessage = e.message ?? errorMessage;
      }
      _showErrorSnackBar(errorMessage);
    } catch (e) {
      if (kDebugMode) print("Signup error: $e");
      _showErrorSnackBar('An unexpected error occurred: ${e.toString()}');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    _showPasswordResetDialog();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => isLoading = true);

    try {
      if (!_googleSignIn.supportsAuthenticate()) {
        _showErrorSnackBar('Google Sign-In is not supported on this platform.');
        return;
      }

      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      if (googleAuth.idToken == null) {
        _showErrorSnackBar('Failed to get Google ID token.');
        return;
      }

      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        final userDocRef = _firestore.collection('users').doc(user.uid);
        final userDoc = await userDocRef.get();

        if (!userDoc.exists) {
          String username = user.email?.split('@').first ??
              'user_${user.uid.substring(0, 8)}';
          // Ensure username is unique
          final usernameCheck = await _firestore
              .collection('users')
              .where('username', isEqualTo: username.toLowerCase())
              .limit(1)
              .get();
          if (usernameCheck.docs.isNotEmpty) {
            username = '${username}_${user.uid.substring(0, 4)}';
          }

          await userDocRef.set({
            'uid': user.uid,
            'fullName': user.displayName ?? 'Google User',
            'username': username.toLowerCase(),
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
            'isOnline': true,
            'lastSeen': FieldValue.serverTimestamp(),
            'avatarUrl': user.photoURL ?? userDoc.data()?['avatarUrl'] ?? '',
          });
        }

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => HomeScreen(currentUserId: user.uid),
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      _showErrorSnackBar('Google Sign-In failed: ${e.message}');
    } catch (e) {
      if (kDebugMode) print("Google Sign-In error: $e");
      _showErrorSnackBar('An unexpected error occurred during Google Sign-In.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
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
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GradientScaffold(
      gradientStyle: GradientStyle.mesh,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    _buildLogo(theme, isDark),
                    const SizedBox(height: AppSpacing.xl),
                    // Title
                    _buildTitle(theme),
                    const SizedBox(height: AppSpacing.xl),
                    // Form card
                    GlassCard(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      blur: 15,
                      child: AnimatedSwitcher(
                        duration: AnimationConstants.normal,
                        transitionBuilder: (child, animation) {
                          final slideIn = Tween<Offset>(
                            begin: Offset(
                              child.key == const ValueKey('login') ? -1.0 : 1.0,
                              0.0,
                            ),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeInOutCubic,
                          ));
                          return SlideTransition(
                            position: slideIn,
                            child: FadeTransition(opacity: animation, child: child),
                          );
                        },
                        child: isLogin ? _buildLoginForm(theme) : _buildSignupForm(theme),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // Toggle login/signup
                    _buildToggleAuth(theme),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(ThemeData theme, bool isDark) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        borderRadius: AppRadius.xl,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppRadius.xl,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: AppRadius.xl,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.8),
                  theme.colorScheme.secondary.withValues(alpha: 0.6),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Image.asset(
              'assets/logo.png',
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.chat_bubble_rounded,
                size: 50,
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(ThemeData theme) {
    return Column(
      children: [
        Text(
          isLogin ? 'Welcome Back!' : 'Create Account',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          isLogin
              ? 'Sign in to continue your conversations'
              : 'Fill in the details to get started',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLoginForm(ThemeData theme) {
    return Column(
      key: const ValueKey('login'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GlassTextField(
          controller: _emailController,
          label: 'Email',
          hint: 'Enter your email',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: AppSpacing.md),
        _GlassTextField(
          controller: _passwordController,
          label: 'Password',
          hint: 'Enter your password',
          icon: Icons.lock_outline,
          isPassword: true,
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: isLoading ? null : _resetPassword,
            child: Text(
              'Forgot Password?',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        GlassButton(
          text: 'Login',
          onPressed: isLoading ? null : _login,
          isLoading: isLoading,
          fullWidth: true,
          showGlow: true,
        ),
        const SizedBox(height: AppSpacing.lg),
        _buildSocialLogin(theme),
      ],
    );
  }

  Widget _buildSignupForm(ThemeData theme) {
    return Column(
      key: const ValueKey('signup'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GlassTextField(
          controller: _fullNameController,
          label: 'Full Name',
          hint: 'Enter your full name',
          icon: Icons.person_outline,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: AppSpacing.md),
        _GlassTextField(
          controller: _usernameController,
          label: 'Username',
          hint: 'Choose a username',
          icon: Icons.alternate_email,
        ),
        const SizedBox(height: AppSpacing.md),
        _GlassTextField(
          controller: _emailController,
          label: 'Email',
          hint: 'Enter your email',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: AppSpacing.md),
        _GlassTextField(
          controller: _passwordController,
          label: 'Password',
          hint: 'Min. 6 characters',
          icon: Icons.lock_outline,
          isPassword: true,
        ),
        const SizedBox(height: AppSpacing.lg),
        GlassButton(
          text: 'Create Account',
          onPressed: isLoading ? null : _signup,
          isLoading: isLoading,
          fullWidth: true,
          showGlow: true,
        ),
        const SizedBox(height: AppSpacing.lg),
        _buildSocialLogin(theme),
      ],
    );
  }

  Widget _buildSocialLogin(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Divider(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.1),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                'OR',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
        if (!Platform.isWindows) ...[
          const SizedBox(height: AppSpacing.md),
          GlassContainer(
            blur: 10,
            opacity: isDark ? 0.1 : 0.5,
            borderRadius: AppRadius.lg,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isLoading ? null : _handleGoogleSignIn,
                borderRadius: AppRadius.lg,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FaIcon(
                        FontAwesomeIcons.google,
                        size: 18,
                        color: theme.colorScheme.onSurface,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Continue with Google',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildToggleAuth(ThemeData theme) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isLogin ? "Don't have an account? " : "Already have an account? ",
            style: theme.textTheme.bodyMedium,
          ),
          TextButton(
            onPressed: isLoading
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
            ),
            child: Text(
              isLogin ? 'Sign Up' : 'Login',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPasswordResetDialog() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final emailController = TextEditingController();
    bool dialogLoading = false;

    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: ClipRRect(
                borderRadius: AppRadius.xl,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.xl,
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.9),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.white.withValues(alpha: 0.8),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Reset Password',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Enter your email to receive a password reset link.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _GlassTextField(
                          controller: emailController,
                          label: 'Email',
                          hint: 'Enter your email',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: dialogLoading
                                    ? null
                                    : () => Navigator.pop(dialogContext),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: GlassButton(
                                text: 'Send Link',
                                onPressed: dialogLoading
                                    ? null
                                    : () async {
                                        if (emailController.text.trim().isEmpty) {
                                          _showErrorSnackBar('Please enter an email');
                                          return;
                                        }
                                        setDialogState(() => dialogLoading = true);
                                        try {
                                          await _auth.sendPasswordResetEmail(
                                            email: emailController.text.trim(),
                                          );
                                          if (mounted) {
                                            Navigator.pop(dialogContext);
                                            _showSuccessSnackBar(
                                              'Password reset email sent!',
                                            );
                                          }
                                        } catch (e) {
                                          _showErrorSnackBar(
                                            'Failed to send reset email.',
                                          );
                                        } finally {
                                          setDialogState(() => dialogLoading = false);
                                        }
                                      },
                                isLoading: dialogLoading,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Glass-styled text field for auth forms.
class _GlassTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool isPassword;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  const _GlassTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.isPassword = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  State<_GlassTextField> createState() => _GlassTextFieldState();
}

class _GlassTextFieldState extends State<_GlassTextField> {
  bool _obscured = true;
  bool _isFocused = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: _isFocused
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        AnimatedContainer(
          duration: AnimationConstants.fast,
          decoration: BoxDecoration(
            borderRadius: AppRadius.md,
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: AppRadius.md,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: AppRadius.md,
                  color: isDark
                      ? Colors.white.withValues(alpha: _isFocused ? 0.12 : 0.08)
                      : Colors.white.withValues(alpha: _isFocused ? 0.95 : 0.8),
                  border: Border.all(
                    color: _isFocused
                        ? theme.colorScheme.primary
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.05)),
                    width: _isFocused ? 2 : 1.5,
                  ),
                ),
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  obscureText: widget.isPassword && _obscured,
                  keyboardType: widget.keyboardType,
                  textCapitalization: widget.textCapitalization,
                  style: theme.textTheme.bodyLarge,
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    prefixIcon: Icon(
                      widget.icon,
                      color: _isFocused
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    suffixIcon: widget.isPassword
                        ? IconButton(
                            icon: Icon(
                              _obscured
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                            ),
                            onPressed: () {
                              setState(() => _obscured = !_obscured);
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
