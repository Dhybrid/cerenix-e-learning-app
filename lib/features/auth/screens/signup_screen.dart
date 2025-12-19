// lib/features/auth/screens/signup_screen.dart
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/constants/endpoints.dart';
import '../../../core/network/api_service.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  bool _isLoading = false;

  // Use serverClientId instead of clientId to force account selection
  static const String _googleServerClientId = "686211760588-kj6miq7fdnu03a27mu46bu8nhbj10s85.apps.googleusercontent.com";

  Future<void> _handleGoogleSignup() async {
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

  void _handleEmailSignup() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const EmailSignupPage()));
  }

  void _goToSignin() {
    Navigator.pushReplacementNamed(context, '/signin');
  }

  Future<void> _saveUserAndNavigate(Map<String, dynamic> userData, String method, String? password) async {
    final box = await Hive.openBox('user_box');
    await box.put('current_user', {
      ...userData,
      'login_method': method,
      'password': password,
    });

    final bool onboardingDone = userData['onboarding_completed'] ?? false;
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, onboardingDone ? '/home' : '/academic_setup');
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isSmallScreen = size.height < 700;

    return Scaffold(
      backgroundColor: Colors.white,
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
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),

              SizedBox(height: isSmallScreen ? 20 : 40),

              // Title
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Join Cerenix",
                    style: TextStyle(
                      fontSize: isSmallScreen ? 28 : 32,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1F2937),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Create your account to get started",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
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
                  onPressed: _isLoading ? null : _handleGoogleSignup,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1F2937),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    backgroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildGoogleIcon(),
                            const SizedBox(width: 12),
                            const Text("Continue with Google", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 32),

              // OR Divider
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text("OR", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500, fontSize: 14)),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ],
              ),

              const SizedBox(height: 32),

              // Email Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _handleEmailSignup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.email_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 12),
                      Text("Sign up with Email", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),

              SizedBox(height: isSmallScreen ? 40 : 60),

              // Already have account
              Center(
                child: GestureDetector(
                  onTap: _goToSignin,
                  child: RichText(
                    text: TextSpan(
                      text: "Already have an account? ",
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                      children: const [
                        TextSpan(
                          text: "Sign In",
                          style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
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

    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.3), size.width * 0.15, red);
    canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.3), size.width * 0.15, blue);
    canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.7), size.width * 0.15, green);
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.7), size.width * 0.15, yellow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// EmailSignupPage
class EmailSignupPage extends StatefulWidget {
  const EmailSignupPage({super.key});
  @override
  State<EmailSignupPage> createState() => _EmailSignupPageState();
}

class _EmailSignupPageState extends State<EmailSignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final userData = await ApiService().registerWithEmail(email: email, password: password);
      if (userData == null) throw Exception("Registration failed");

      await _saveUserAndNavigate(userData, 'email', password);
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveUserAndNavigate(Map<String, dynamic> userData, String method, String? password) async {
    final box = await Hive.openBox('user_box');
    await box.put('current_user', {
      ...userData,
      'login_method': method,
      'password': password,
    });

    final bool onboardingDone = userData['onboarding_completed'] ?? false;
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, onboardingDone ? '/home' : '/academic_setup');
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

  void _goToSignin() => Navigator.pushReplacementNamed(context, '/signin');

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF374151), fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.grey.shade400),
            prefixIcon: Icon(prefixIcon, color: Colors.grey.shade500),
            suffixIcon: onToggleObscure != null
                ? IconButton(icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility, color: Colors.grey.shade500), onPressed: onToggleObscure)
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6366F1))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            filled: true,
            fillColor: Colors.grey.shade50,
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

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 32, vertical: isSmallScreen ? 20 : 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.grey.shade700),
                  ),
                ),

                SizedBox(height: isSmallScreen ? 20 : 40),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Create Account", style: TextStyle(fontSize: isSmallScreen ? 28 : 32, fontWeight: FontWeight.w700, color: const Color(0xFF1F2937), letterSpacing: -0.5)),
                    const SizedBox(height: 8),
                    Text("Enter your details to get started", style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w400)),
                  ],
                ),

                SizedBox(height: isSmallScreen ? 32 : 48),

                _buildTextField(
                  label: "Email Address",
                  hintText: "Enter your email",
                  prefixIcon: Icons.email_rounded,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v == null || v.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v) ? 'Enter a valid email' : null,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  label: "Password",
                  hintText: "Create a password",
                  prefixIcon: Icons.lock_rounded,
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
                  validator: (v) => v == null || v.length < 6 ? 'Password must be at least 6 characters' : null,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  label: "Confirm Password",
                  hintText: "Confirm your password",
                  prefixIcon: Icons.lock_outline_rounded,
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  onToggleObscure: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  validator: (v) => v != _passwordController.text ? 'Passwords do not match' : null,
                ),

                SizedBox(height: isSmallScreen ? 32 : 48),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signup,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 2),
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                        : const Text("Create Account", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),

                SizedBox(height: isSmallScreen ? 24 : 32),

                Center(
                  child: GestureDetector(
                    onTap: _goToSignin,
                    child: RichText(
                      text: TextSpan(
                        text: "Already have an account? ",
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                        children: const [
                          TextSpan(text: "Sign In", style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}