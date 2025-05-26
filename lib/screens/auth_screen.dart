import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../components/auth_screen/social_button.dart';
import '../components/shared/custom_button.dart';
import '../components/shared/custom_text_field.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7FB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                        height: 100,
                        width: 100,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              spreadRadius: 5,
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.lock_outline_rounded,
                            size: 60,
                            color: Colors.white,
                          ),
                        ),
                      )
                      .animate()
                      .fade(duration: 500.ms)
                      .slideY(begin: -0.2, end: 0),

                  const SizedBox(height: 30),

                  // Welcome Text
                  Text(
                        isLogin ? 'Welcome Back!' : 'Create Account',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      )
                      .animate()
                      .fade(duration: 500.ms, delay: 200.ms)
                      .slideY(begin: 0.2, end: 0),

                  const SizedBox(height: 10),

                  Text(
                        isLogin
                            ? 'Sign in to continue accessing your account'
                            : 'Fill the form to get started with us',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      )
                      .animate()
                      .fade(duration: 500.ms, delay: 300.ms)
                      .slideY(begin: 0.2, end: 0),

                  const SizedBox(height: 40),

                  // Form Fields
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    transitionBuilder: (
                      Widget child,
                      Animation<double> animation,
                    ) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.0, 0.1),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: isLogin ? _buildLoginForm() : _buildSignupForm(),
                  ),

                  const SizedBox(height: 20),

                  // Switch between Login and Signup
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isLogin
                            ? "Don't have an account? "
                            : "Already have an account? ",
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            isLogin = !isLogin;
                          });
                        },
                        child: Text(
                          isLogin ? "Sign Up" : "Login",
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ).animate().fade(duration: 500.ms, delay: 500.ms),
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
      key: const ValueKey('login'),
      children: [
        CustomTextField(label: 'Email', icon: Icons.email_outlined)
            .animate()
            .fade(duration: 500.ms, delay: 300.ms)
            .slideY(begin: 0.2, end: 0),

        const SizedBox(height: 16),

        CustomTextField(
              label: 'Password',
              icon: Icons.lock_outline,
              obscureText: true,
            )
            .animate()
            .fade(duration: 500.ms, delay: 400.ms)
            .slideY(begin: 0.2, end: 0),

        const SizedBox(height: 10),

        Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {},
                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            )
            .animate()
            .fade(duration: 500.ms, delay: 500.ms)
            .slideY(begin: 0.2, end: 0),

        const SizedBox(height: 20),

        CustomButton(text: 'Login', onPressed: () {})
            .animate()
            .fade(duration: 500.ms, delay: 600.ms)
            .slideY(begin: 0.2, end: 0),

        const SizedBox(height: 20),

        _buildSocialLogin(),
      ],
    );
  }

  Widget _buildSignupForm() {
    return Column(
      key: const ValueKey('signup'),
      children: [
        CustomTextField(label: 'Full Name', icon: Icons.person_outline)
            .animate()
            .fade(duration: 500.ms, delay: 300.ms)
            .slideY(begin: 0.2, end: 0),

        const SizedBox(height: 16),

        CustomTextField(label: 'Username', icon: Icons.alternate_email)
            .animate()
            .fade(duration: 500.ms, delay: 400.ms)
            .slideY(begin: 0.2, end: 0),

        const SizedBox(height: 16),

        CustomTextField(label: 'Email', icon: Icons.email_outlined)
            .animate()
            .fade(duration: 500.ms, delay: 500.ms)
            .slideY(begin: 0.2, end: 0),

        const SizedBox(height: 16),

        CustomTextField(
              label: 'Password',
              icon: Icons.lock_outline,
              obscureText: true,
            )
            .animate()
            .fade(duration: 500.ms, delay: 600.ms)
            .slideY(begin: 0.2, end: 0),

        const SizedBox(height: 20),

        CustomButton(text: 'Create Account', onPressed: () {})
            .animate()
            .fade(duration: 500.ms, delay: 700.ms)
            .slideY(begin: 0.2, end: 0),

        const SizedBox(height: 20),

        _buildSocialLogin(),
      ],
    );
  }

  Widget _buildSocialLogin() {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: Divider(thickness: 1, color: Colors.grey)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'OR',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Expanded(child: Divider(thickness: 1, color: Colors.grey)),
          ],
        ).animate().fade(duration: 500.ms, delay: 800.ms),

        const SizedBox(height: 20),

        SocialButton(
              text: 'Continue with Google',
              icon: FontAwesomeIcons.google,
              color: const Color(0xFFDB4437),
              onPressed: () {},
            )
            .animate()
            .fade(duration: 500.ms, delay: 900.ms)
            .slideY(begin: 0.2, end: 0),
      ],
    );
  }
}
