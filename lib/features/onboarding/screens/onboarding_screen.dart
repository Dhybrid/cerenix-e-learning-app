import 'dart:async';
import 'package:flutter/material.dart';

class CerenixOnboardingScreen extends StatefulWidget {
  const CerenixOnboardingScreen({super.key});

  @override
  State<CerenixOnboardingScreen> createState() =>
      _CerenixOnboardingScreenState();
}

class _CerenixOnboardingScreenState extends State<CerenixOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  Timer? _autoTimer;

  final List<Map<String, dynamic>> _slides = [
    {
      "image": "assets/images/AI1.jpg",
      "title": "AI Learning, Redefined, Scholarship Update",
      "desc":
          "Experience personalized education powered by Cerenix AI (cereva)— made for university & college learners.",
      "color": Color(0xFF6366F1),
    },
    {
      "image": "assets/images/cerenixVoiceAssistance.png",
      "title": "Voice interaction",
      "desc":
          "Talk easily with our AI and get feedback with our cereva voice room",
      "color": Color(0xFFEC4899),
    },
    {
      "image": "assets/images/cerenixProgress.png",
      "title": "Track Your Growth",
      "desc":
          "Analyze your progress, improve performance, and connect globally with other students.",
      "color": Color(0xFF10B981),
    },
  ];

  @override
  void initState() {
    super.initState();
    _autoTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) return;
      if (_currentIndex < _slides.length - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      } else {
        _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentIndex < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    } else {
      _goToSignup();
    }
  }

  void _goToSignup() {
    Navigator.pushReplacementNamed(context, '/signup');
  }

  void _skip() => _goToSignup();

  Widget _buildImage(String imagePath) {
    return Image.asset(
      imagePath,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(Icons.school_rounded, color: Colors.white, size: 60),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isSmallScreen = size.height < 700;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF08111F) : Colors.white;
    final titleColor = isDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF1F2937);
    final bodyColor = isDark ? const Color(0xFFCBD5E1) : Colors.grey.shade600;
    final inactiveDotColor = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.grey.shade300;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Skip Button - Top Right
            Padding(
              padding: const EdgeInsets.only(top: 16, right: 24),
              child: Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _skip,
                  child: Text(
                    "Skip",
                    style: TextStyle(
                      color: bodyColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),

            // PageView Section
            Expanded(
              flex: 7,
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                itemBuilder: (_, index) {
                  final data = _slides[index];
                  return SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Image Container
                          Container(
                            width: double.infinity,
                            height: isSmallScreen ? 220 : 280,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: data["color"]!.withOpacity(0.3),
                                  blurRadius: 20,
                                  offset: Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: _buildImage(data["image"]!),
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 40 : 60),

                          // Title
                          Text(
                            data["title"]!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 24 : 28,
                              fontWeight: FontWeight.w700,
                              color: titleColor,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 16 : 24),

                          // Description
                          Text(
                            data["desc"]!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 15 : 16,
                              color: bodyColor,
                              height: 1.6,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            SizedBox(height: isSmallScreen ? 20 : 40),

            // Dots Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentIndex == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentIndex == index
                        ? _slides[index]["color"]
                        : inactiveDotColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),

            SizedBox(height: isSmallScreen ? 20 : 40),

            // Get Started Button
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _nextPage,
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
                      Text(
                        _currentIndex == _slides.length - 1
                            ? "Get Started"
                            : "Next",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        _currentIndex == _slides.length - 1
                            ? Icons.arrow_forward_rounded
                            : Icons.arrow_forward_ios_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ],
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
