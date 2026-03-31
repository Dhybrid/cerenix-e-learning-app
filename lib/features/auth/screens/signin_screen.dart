// lib/features/auth/screens/signin_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http; // ADD THIS IMPORT
import 'dart:convert'; // ADD THIS IMPORT

import '../../../core/network/api_service.dart';
import '../../../core/constants/endpoints.dart'; // ADD THIS IMPORT

class SigninPage extends StatefulWidget {
  const SigninPage({super.key});

  @override
  State<SigninPage> createState() => _SigninPageState();
}

class _SigninPageState extends State<SigninPage> {
  bool _isLoading = false;

  // Use serverClientId instead of clientId to force account selection
  static const String _googleServerClientId =
      "788077781659-r3cg2bhkk2oes4l7k9s8r52tdlp26dul.apps.googleusercontent.com";

  Future<void> _handleGoogleSignin() async {
    setState(() => _isLoading = true);

    try {
      final googleSignIn = GoogleSignIn(
        serverClientId: _googleServerClientId,
        scopes: ['email', 'profile'],
      );

      // Force account selection by signing out first if needed
      await googleSignIn.signOut();

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; // User cancelled
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception("Failed to get Google token");
      }

      final userData = await ApiService().googleLogin(idToken);
      if (userData == null) {
        throw Exception("Login failed");
      }

      await _saveUserAndNavigate(userData, 'google', null);
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleEmailSignin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EmailSigninPage()),
    );
  }

  void _goToSignup() {
    Navigator.pushReplacementNamed(context, '/signup');
  }

  Future<void> _saveUserAndNavigate(
    Map<String, dynamic> userData,
    String method,
    String? password,
  ) async {
    final box = await Hive.openBox('user_box');
    await box.put('current_user', {
      ...userData,
      'login_method': method,
      'password': password,
    });

    final bool onboardingDone = userData['onboarding_completed'] ?? false;
    if (!mounted) return;

    if (onboardingDone) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/academic_setup');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildGoogleIcon() {
    return Container(
      width: 24,
      height: 24,
      child: CustomPaint(painter: _GoogleIconPainter()),
    );
  }

  Future<void> _handleBackNavigation() async {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    final shouldExit = await _showExitConfirmation();
    if (shouldExit && mounted) {
      await SystemNavigator.pop();
    }
  }

  Future<bool> _showExitConfirmation() async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Exit Cerenix?'),
            content: const Text(
              'You are already on the last page. Do you want to close the app?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Exit'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isSmallScreen = size.height < 700;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF08111F) : Colors.white;
    final surfaceColor = isDark ? const Color(0xFF111C2D) : Colors.white;
    final secondarySurfaceColor = isDark
        ? const Color(0xFF182436)
        : Colors.grey.shade100;
    final titleColor = isDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF1F2937);
    final bodyColor = isDark ? const Color(0xFFCBD5E1) : Colors.grey.shade600;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.grey.shade300;
    final googleTextColor = isDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF1F2937);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBackNavigation();
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: 32,
              vertical: isSmallScreen ? 20 : 40,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back Button
                IconButton(
                  onPressed: _handleBackNavigation,
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: secondarySurfaceColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: titleColor,
                    ),
                  ),
                ),

                SizedBox(height: isSmallScreen ? 20 : 40),

                // Title Section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Welcome Back",
                      style: TextStyle(
                        fontSize: isSmallScreen ? 28 : 32,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Sign in to continue your learning journey",
                      style: TextStyle(
                        fontSize: 16,
                        color: bodyColor,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: isSmallScreen ? 40 : 60),

                // Google Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _handleGoogleSignin,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: googleTextColor,
                      side: BorderSide(color: borderColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      backgroundColor: surfaceColor,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildGoogleIcon(),
                              SizedBox(width: 12),
                              Text(
                                "Continue with Google",
                                style: TextStyle(
                                  color: googleTextColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                SizedBox(height: 32),

                // Divider
                Row(
                  children: [
                    Expanded(child: Divider(color: borderColor)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        "OR",
                        style: TextStyle(
                          color: bodyColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: borderColor)),
                  ],
                ),

                SizedBox(height: 32),

                // Email Signin Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _handleEmailSignin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF6366F1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.email_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Text(
                          "Sign in with Email",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: isSmallScreen ? 40 : 60),

                // Don't have account
                Center(
                  child: GestureDetector(
                    onTap: _goToSignup,
                    child: RichText(
                      text: TextSpan(
                        text: "Don't have an account? ",
                        style: TextStyle(color: bodyColor, fontSize: 15),
                        children: [
                          TextSpan(
                            text: "Sign Up",
                            style: TextStyle(
                              color: Color(0xFF6366F1),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final red = Paint()..color = const Color(0xFFEA4335);
    final blue = Paint()..color = const Color(0xFF4285F4);
    final green = Paint()..color = const Color(0xFF34A853);
    final yellow = Paint()..color = const Color(0xFFFBBC05);

    canvas.drawCircle(
      Offset(size.width * 0.3, size.height * 0.3),
      size.width * 0.15,
      red,
    );
    canvas.drawCircle(
      Offset(size.width * 0.7, size.height * 0.3),
      size.width * 0.15,
      blue,
    );
    canvas.drawCircle(
      Offset(size.width * 0.7, size.height * 0.7),
      size.width * 0.15,
      green,
    );
    canvas.drawCircle(
      Offset(size.width * 0.3, size.height * 0.7),
      size.width * 0.15,
      yellow,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class EmailSigninPage extends StatefulWidget {
  const EmailSigninPage({super.key});

  @override
  State<EmailSigninPage> createState() => _EmailSigninPageState();
}

class _EmailSigninPageState extends State<EmailSigninPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  Future<Map<String, dynamic>?> _loginWithEmail(
    String email,
    String password,
  ) async {
    try {
      // First try using ApiService if the method exists
      final response = await ApiService().loginWithEmail(
        email: email,
        password: password,
      );
      return response;
    } catch (e) {
      // If loginWithEmail doesn't exist in ApiService, use direct HTTP call
      try {
        final response = await http.post(
          Uri.parse('${ApiEndpoints.baseUrl}/api/users/auth/login/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        );

        if (response.statusCode == 200) {
          final userData = jsonDecode(response.body)['user'];
          // Store user data in Hive
          final box = await Hive.openBox('user_box');
          await box.put('current_user', userData);
          return userData;
        } else {
          final error = jsonDecode(response.body)['error'] ?? 'Login failed';
          throw Exception(error);
        }
      } catch (httpError) {
        throw Exception("Invalid email or password");
      }
    }
  }

  Future<void> _signin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // First try online login with Django using proper login endpoint
      try {
        final userData = await _loginWithEmail(email, password);
        if (userData != null) {
          await _saveUserAndNavigate(userData, 'email', password);
          return;
        }
      } catch (onlineError) {
        print('Online login failed: $onlineError');
        // Online login failed, try offline login
        await _tryOfflineLogin(email, password);
      }
    } catch (e) {
      String errorMessage = e.toString().replaceFirst('Exception: ', '');

      // Provide more user-friendly error messages
      if (errorMessage.contains('Invalid email or password') ||
          errorMessage.contains('Login failed')) {
        errorMessage =
            "Invalid email or password. Please check your credentials.";
      } else if (errorMessage.contains('User not found')) {
        errorMessage = "Account not found. Please sign up first.";
      }

      _showError(errorMessage);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _tryOfflineLogin(String email, String password) async {
    try {
      final box = await Hive.openBox('user_box');
      final userData = box.get('current_user');

      // Check if we have stored credentials for offline login
      if (userData != null &&
          userData['email'] == email &&
          userData['password'] == password) {
        // Offline login successful
        await _saveUserAndNavigate(userData, 'email', password);
      } else {
        throw Exception(
          "Invalid email or password. Please check your credentials.",
        );
      }
    } catch (e) {
      throw Exception(
        "Invalid email or password. Please check your credentials.",
      );
    }
  }

  Future<void> _saveUserAndNavigate(
    Map<String, dynamic> userData,
    String method,
    String? password,
  ) async {
    final box = await Hive.openBox('user_box');
    await box.put('current_user', {
      ...userData,
      'login_method': method,
      'password': password,
    });

    final bool onboardingDone = userData['onboarding_completed'] ?? false;
    if (!mounted) return;

    if (onboardingDone) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/academic_setup');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _goToSignup() {
    Navigator.pushReplacementNamed(context, '/signup');
  }

  Future<void> _handleBackNavigation() async {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    final shouldExit = await _showExitConfirmation();
    if (shouldExit && mounted) {
      await SystemNavigator.pop();
    }
  }

  Future<bool> _showExitConfirmation() async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Exit Cerenix?'),
            content: const Text(
              'You are already on the last page. Do you want to close the app?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Exit'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildTextField({
    required String label,
    required String hintText,
    required IconData prefixIcon,
    required TextEditingController controller,
    bool obscureText = false,
    VoidCallback? onToggleObscure,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final labelColor = isDark
        ? const Color(0xFFE2E8F0)
        : const Color(0xFF374151);
    final fieldTextColor = isDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF0F172A);
    final fieldFillColor = isDark
        ? const Color(0xFF152235)
        : Colors.grey.shade50;
    final hintColor = isDark ? const Color(0xFF94A3B8) : Colors.grey.shade400;
    final iconColor = isDark ? const Color(0xFFCBD5E1) : Colors.grey.shade500;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.grey.shade300;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          cursorColor: const Color(0xFF6366F1),
          style: TextStyle(color: fieldTextColor),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: hintColor),
            prefixIcon: Icon(prefixIcon, color: iconColor),
            suffixIcon: onToggleObscure != null
                ? IconButton(
                    icon: Icon(
                      obscureText ? Icons.visibility_off : Icons.visibility,
                      color: iconColor,
                    ),
                    onPressed: onToggleObscure,
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFF6366F1)),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            filled: true,
            fillColor: fieldFillColor,
          ),
          validator: validator,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isSmallScreen = size.height < 700;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF08111F) : Colors.white;
    final secondarySurfaceColor = isDark
        ? const Color(0xFF182436)
        : Colors.grey.shade100;
    final titleColor = isDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF1F2937);
    final bodyColor = isDark ? const Color(0xFFCBD5E1) : Colors.grey.shade600;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBackNavigation();
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: 32,
              vertical: isSmallScreen ? 20 : 40,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back Button
                  IconButton(
                    onPressed: _handleBackNavigation,
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: secondarySurfaceColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: titleColor,
                      ),
                    ),
                  ),

                  SizedBox(height: isSmallScreen ? 20 : 40),

                  // Title Section
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Sign In",
                        style: TextStyle(
                          fontSize: isSmallScreen ? 28 : 32,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Enter your credentials to access your account",
                        style: TextStyle(
                          fontSize: 16,
                          color: bodyColor,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: isSmallScreen ? 32 : 48),

                  // Form Fields
                  Column(
                    children: [
                      _buildTextField(
                        label: "Email Address",
                        hintText: "Enter your email",
                        prefixIcon: Icons.email_rounded,
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!RegExp(
                            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                          ).hasMatch(value)) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 20),
                      _buildTextField(
                        label: "Password",
                        hintText: "Enter your password",
                        prefixIcon: Icons.lock_rounded,
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        onToggleObscure: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),

                  SizedBox(height: 16),

                  // Forgot Password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        _showError(
                          "Please contact support to reset your password",
                        );
                      },
                      child: Text(
                        "Forgot Password?",
                        style: TextStyle(
                          color: Color(0xFF6366F1),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: isSmallScreen ? 24 : 32),

                  // Sign In Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF6366F1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              "Sign In",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  SizedBox(height: isSmallScreen ? 24 : 32),

                  // Don't have account
                  Center(
                    child: GestureDetector(
                      onTap: _goToSignup,
                      child: RichText(
                        text: TextSpan(
                          text: "Don't have an account? ",
                          style: TextStyle(color: bodyColor, fontSize: 15),
                          children: [
                            TextSpan(
                              text: "Sign Up",
                              style: TextStyle(
                                color: Color(0xFF6366F1),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
