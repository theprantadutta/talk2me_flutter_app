// lib/auth_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../app_colors.dart';

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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  // Login function (logic unchanged)
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
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        _showSuccessSnackBar('Login successful!');
        // Navigate to home screen or handle successful login
        // Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'An error occurred';

      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled';
          break;
        default:
          errorMessage = e.message ?? 'Login failed';
      }

      if (mounted) {
        _showErrorSnackBar(errorMessage);
      }
    } catch (e) {
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

  // Signup function (logic unchanged)
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
        _showErrorSnackBar('Username already taken');
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
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
          'username': _usernameController.text.trim(),
          'email': _emailController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Update display name
        await user.updateDisplayName(_fullNameController.text.trim());

        if (mounted) {
          _showSuccessSnackBar('Account created successfully!');
          // Navigate to home screen or handle successful signup
          // Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'An error occurred';

      switch (e.code) {
        case 'weak-password':
          errorMessage = 'The password provided is too weak';
          break;
        case 'email-already-in-use':
          errorMessage = 'An account already exists with this email';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address';
          break;
        default:
          errorMessage = e.message ?? 'Signup failed';
      }

      if (mounted) {
        _showErrorSnackBar(errorMessage);
      }
    } catch (e) {
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

  // Reset password function (logic unchanged)
  Future<void> _resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter your email address');
      return;
    }

    setState(() => isLoading = true);
    try {
      await _auth.sendPasswordResetEmail(email: _emailController.text.trim());
      if (mounted) {
        _showSuccessSnackBar('Password reset email sent!');
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'An error occurred';
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address';
          break;
        default:
          errorMessage = e.message ?? 'Failed to send reset email';
      }
      if (mounted) {
        _showErrorSnackBar(errorMessage);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('An unexpected error occurred: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0), // Increased padding
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      // Gradient example
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryVariant],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16), // Softer radius
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          spreadRadius: 2,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.lock_outline_rounded,
                        size: 40,
                        color: AppColors.logoIcon,
                      ),
                    ),
                  ).animate().fade(duration: 400.ms).scale(delay: 200.ms),

                  const SizedBox(height: 24),

                  // Welcome Text
                  Text(
                    isLogin ? 'Welcome Back!' : 'Create Your Account',
                    style: const TextStyle(
                      fontSize: 26, // Slightly larger
                      fontWeight: FontWeight.bold, // Bolder
                      color: AppColors.textPrimary,
                    ),
                  ).animate().fade(duration: 400.ms, delay: 300.ms),

                  const SizedBox(height: 8),

                  Text(
                    isLogin
                        ? 'Sign in to continue your journey.'
                        : 'Fill in the details to get started.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15, // Slightly larger
                      color: AppColors.textSecondary,
                    ),
                  ).animate().fade(duration: 400.ms, delay: 400.ms),

                  const SizedBox(height: 32),

                  // Form Fields
                  AnimatedSwitcher(
                    duration: const Duration(
                      milliseconds: 500,
                    ), // Slightly longer for smoother slide
                    transitionBuilder: (
                      Widget child,
                      Animation<double> animation,
                    ) {
                      final bool isNewChildLogin =
                          child.key == const ValueKey('login');

                      final offsetAnimation = Tween<Offset>(
                        begin: Offset(
                          isNewChildLogin ? -1.0 : 1.0,
                          0.0,
                        ), // Login from left, Signup from right
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeInOutCubic,
                        ),
                      );

                      // Animate the outgoing child
                      // We need to use a Stack and animate both children if we want them to slide simultaneously.
                      // For simplicity, this will slide the new one in, and the old one will fade out (default for AnimatedSwitcher if not handled by layoutBuilder)
                      // or use the reverse of the new child's animation.

                      return SlideTransition(
                        position: offsetAnimation,
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
                    // To make them slide past each other, you might need a Stack and control both animations.
                    // The default layoutBuilder stacks them, which works okay with fade and slide.
                    // layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                    //   return Stack(
                    //     alignment: Alignment.center,
                    //     children: <Widget>[
                    //       ...previousChildren.map((child) => FadeTransition(opacity:เด็ก(child.key as ValueKey<String>) == ValueKey('login') ? Tween(begin: 1.0, end: 0.0).animate(animation) : Tween(begin: 0.0, end: 1.0).animate(animation) , child: child)),
                    //       if (currentChild != null) currentChild,
                    //     ],
                    //   );
                    // },
                    child: isLogin ? _buildLoginForm() : _buildSignupForm(),
                  ),

                  const SizedBox(height: 24), // Increased spacing
                  // Switch between Login and Signup
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isLogin
                            ? "Don't have an account? "
                            : "Already have an account? ",
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      TextButton(
                        onPressed:
                            isLoading
                                ? null
                                : () {
                                  setState(() {
                                    isLogin = !isLogin;
                                    // Clear controllers when switching
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
                          foregroundColor:
                              AppColors
                                  .primary, // Use primary color for the button text
                        ),
                        child: Text(
                          isLogin ? "Sign Up" : "Login",
                          style: const TextStyle(
                            color: AppColors.primary, // Explicitly set color
                            fontWeight: FontWeight.bold, // Bolder
                            fontSize: 14,
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

  Widget _buildLoginForm() {
    return Column(
      key: const ValueKey('login'), // Important for AnimatedSwitcher
      children: [
        CustomTextField(
          label: 'Email Address',
          icon: Icons.email_outlined,
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16), // Increased spacing
        CustomTextField(
          label: 'Password',
          icon: Icons.lock_outline,
          obscureText: true,
          controller: _passwordController,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: isLoading ? null : _resetPassword,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: AppColors.textSecondary,
            ),
            child: const Text(
              'Forgot Password?',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 24), // Increased spacing
        CustomButton(
          text: isLoading ? 'Logging in...' : 'Login',
          onPressed: isLoading ? null : _login,
          isLoading: isLoading,
        ),
        const SizedBox(height: 24), // Increased spacing
        _buildSocialLogin(),
      ],
    );
  }

  Widget _buildSignupForm() {
    return Column(
      key: const ValueKey('signup'), // Important for AnimatedSwitcher
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
          icon: Icons.alternate_email_outlined, // More appropriate icon
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
    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Divider(thickness: 1, color: AppColors.border),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'OR',
                style: TextStyle(
                  color: AppColors.textSecondary.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Expanded(
              child: Divider(thickness: 1, color: AppColors.border),
            ),
          ],
        ),
        const SizedBox(height: 20), // Increased spacing
        SocialButton(
          text: 'Continue with Google',
          icon: FontAwesomeIcons.google, // Using the brand icon directly
          iconColor: AppColors.error, // Google's red, or keep it neutral
          onPressed:
              isLoading
                  ? null
                  : () {
                    // TODO: Implement Google Sign In
                    _showErrorSnackBar('Google Sign-In not implemented yet.');
                  },
        ),
        // Example for Apple Sign In (requires font_awesome_flutter update for apple icon)
        // const SizedBox(height: 12),
        // SocialButton(
        //   text: 'Continue with Apple',
        //   icon: FontAwesomeIcons.apple,
        //   iconColor: AppColors.textPrimary,
        //   onPressed: isLoading ? null : () {
        //     // TODO: Implement Apple Sign In
        //      _showErrorSnackBar('Apple Sign-In not implemented yet.');
        //   },
        // ),
      ],
    );
  }
}

// CustomTextField, CustomButton, SocialButton updated to use AppColors

class CustomTextField extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool obscureText;
  final IconData?
  suffixIcon; // Not used in current setup, but kept for flexibility
  final VoidCallback? onSuffixIconPressed; // Not used
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
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12), // Softer radius
        border: Border.all(
          color: _isFocused ? AppColors.primary : AppColors.border,
          width: _isFocused ? 1.5 : 1,
        ),
        boxShadow:
            _isFocused
                ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.2),
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
        style: const TextStyle(color: AppColors.textOnSurface, fontSize: 15),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 16,
          ),
          border: InputBorder.none,
          hintText: widget.label,
          hintStyle: TextStyle(
            color: AppColors.textSecondary.withOpacity(0.7),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            widget.icon,
            color: _isFocused ? AppColors.primary : AppColors.icon,
            size: 20,
          ),
          suffixIcon: _buildSuffixIcon(),
        ),
      ),
    );
  }

  Widget? _buildSuffixIcon() {
    if (widget.obscureText) {
      return IconButton(
        icon: Icon(
          _isObscured
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: _isFocused ? AppColors.primary : AppColors.icon,
          size: 20,
        ),
        onPressed: () {
          setState(() {
            _isObscured = !_isObscured;
          });
        },
      );
    } else if (widget.suffixIcon != null) {
      // Kept for future use
      return IconButton(
        icon: Icon(
          widget.suffixIcon,
          color: _isFocused ? AppColors.primary : AppColors.icon,
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
    return SizedBox(
      width: double.infinity,
      height: 52, // Slightly taller
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ), // Softer radius
          elevation: onPressed == null ? 0 : 2, // Subtle elevation
          shadowColor: AppColors.primary.withOpacity(0.5),
          padding: const EdgeInsets.symmetric(vertical: 14), // Adjusted padding
        ),
        child:
            isLoading
                ? const SizedBox(
                  height: 22, // Adjusted size
                  width: 22, // Adjusted size
                  child: CircularProgressIndicator(
                    color: AppColors.textOnPrimary,
                    strokeWidth: 2.5, // Slightly thicker
                  ),
                )
                : Text(
                  text,
                  style: const TextStyle(
                    fontSize: 16, // Slightly larger
                    fontWeight: FontWeight.w600, // Bolder
                  ),
                ),
      ),
    );
  }
}

class SocialButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color? iconColor; // Allow custom icon color
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
    return SizedBox(
      width: double.infinity,
      height: 52, // Slightly taller
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: FaIcon(
          icon,
          color: iconColor ?? AppColors.primary, // Use primary if not specified
          size: 18,
        ),
        label: Text(
          text,
          style: const TextStyle(
            color:
                AppColors
                    .textPrimary, // Darker text for better contrast on white
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary, // For ripple effect
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), // Softer radius
            side: BorderSide(color: AppColors.border, width: 1),
          ),
          elevation: 0, // Flat design
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}
