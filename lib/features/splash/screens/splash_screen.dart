// lib/features/splash/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/network/api_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6)),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.3, 1.0, curve: Curves.elasticOut)),
    );

    _controller.forward();

    // Keep the original 6200ms timing for smooth animation experience
    Timer(const Duration(milliseconds: 6200), () {
      if (mounted) {
        _checkAuthAndNavigate();
      }
    });
  }

  Future<void> _checkAuthAndNavigate() async {
    try {
      // Initialize Hive box first
      final box = await Hive.openBox('user_box');
      final userData = box.get('current_user');
      
      print('=== SPLASH SCREEN DEBUG ===');
      print('User data from Hive: $userData');
      
      if (userData != null && userData['id'] != null) {
        // User is logged in
        bool onboardingCompleted = userData['onboarding_completed'] == true;
        print('Onboarding completed: $onboardingCompleted');
        
        if (onboardingCompleted) {
          // User completed onboarding, go to home
          print('Navigating to HOME');
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          // User logged in but didn't complete onboarding
          print('Navigating to ACADEMIC_SETUP');
          Navigator.pushReplacementNamed(context, '/onboarding');
        }
      } else {
        // User not logged in, go to SIGNIN screen (not onboarding)
        print('Navigating to SIGNIN (not logged in)');
        Navigator.pushReplacementNamed(context, '/onboarding');
      }
      print('==========================');
    } catch (e) {
      print('Error checking auth status: $e');
      // If any error occurs, default to signin screen
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/signin');
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0077B6), // Deep Blue
      body: SafeArea(
        child: Stack(
          children: [
            // CENTER: Logo OR Text
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Image with fallback
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: Image.asset(
                          'assets/images/cerenixSplash.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Text(
                              'CERENIX',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 3,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      const SizedBox(height: 8),
                      const Text(
                        'Brought to you by RBA Academy',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // BOTTOM CENTER: Powered by
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: const Text(
                    'Powered & Licensed by\nRadiant Bridge Africa',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white60,
                      height: 1.5,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}