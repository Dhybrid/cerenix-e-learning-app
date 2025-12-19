import 'package:flutter/material.dart';
import '../models/onboarding_models.dart';

class TermsAndConditionsScreen extends StatefulWidget {
  final UserOnboardingData userData;

  const TermsAndConditionsScreen({super.key, required this.userData});

  @override
  State<TermsAndConditionsScreen> createState() => _TermsAndConditionsScreenState();
}

class _TermsAndConditionsScreenState extends State<TermsAndConditionsScreen> {
  bool _acceptedTerms = false;
  final ScrollController _scrollController = ScrollController();
  bool _showScrollIndicator = true;
  bool _isAtBottom = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    
    // Check initial scroll position
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfAtBottom();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    _checkIfAtBottom();
  }

  void _checkIfAtBottom() {
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final threshold = maxScroll - 50; // 50 pixels from bottom

    if (currentScroll >= threshold && !_isAtBottom) {
      setState(() {
        _isAtBottom = true;
        _showScrollIndicator = false;
      });
    } else if (currentScroll < threshold && _isAtBottom) {
      setState(() {
        _isAtBottom = false;
        _showScrollIndicator = true;
      });
    }
  }

  void _scrollToNextSection() {
    final currentPosition = _scrollController.position.pixels;
    final viewportHeight = _scrollController.position.viewportDimension;
    final maxScroll = _scrollController.position.maxScrollExtent;

    // Calculate next scroll position (scroll by 80% of viewport height)
    double nextPosition = currentPosition + (viewportHeight * 0.8);

    // If we're near the bottom, scroll to exact bottom
    if (nextPosition >= maxScroll - 100) {
      nextPosition = maxScroll;
    }

    _scrollController.animateTo(
      nextPosition,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
  }

  void _continueToHome() {
    if (_acceptedTerms) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // App Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      IconButton(
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
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Terms & Conditions',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Stack(
                    children: [
                      SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Profile Summary Card
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    const Color(0xFF6366F1).withOpacity(0.08),
                                    const Color(0xFF8B5CF6).withOpacity(0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFF6366F1).withOpacity(0.2),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF6366F1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.school_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Academic Profile',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1F2937),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _buildSummaryItem('🏛️', 'University', widget.userData.university?.name),
                                  _buildSummaryItem('🎓', 'Faculty', widget.userData.faculty?.name),
                                  _buildSummaryItem('📚', 'Department', widget.userData.department?.name),
                                  _buildSummaryItem('📅', 'Level', widget.userData.level?.name),
                                ],
                              ),
                            ),

                            const SizedBox(height: 32),

                            // Terms Header
                            Center(
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6366F1).withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.description_rounded,
                                      color: Color(0xFF6366F1),
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Cerenix AI Learning Platform',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1F2937),
                                      letterSpacing: -0.5,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Terms & Conditions Agreement',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF6366F1),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 32),

                            // Terms Content
                            _buildTermsSection(
                              '1. Platform Usage Agreement',
                              'By accessing Cerenix AI Learning Platform, you agree to comply with all applicable laws and regulations. The platform is designed for educational purposes to enhance learning experiences through AI-powered assistance.',
                            ),

                            _buildTermsSection(
                              '2. Academic Integrity',
                              'While Cerenix provides AI assistance, users must maintain academic integrity. The platform should be used to supplement learning, not to complete academic work dishonestly or violate institutional honor codes.',
                            ),

                            _buildTermsSection(
                              '3. Data Privacy & Security',
                              'Your academic data is protected with enterprise-grade security. We collect information to personalize your learning experience and do not share personal data with third parties without explicit consent.',
                            ),

                            _buildTermsSection(
                              '4. AI Assistance Limitations',
                              'Our AI provides educational support but may not always be accurate. Users should verify critical information and use the platform as a learning aid rather than an absolute source of truth.',
                            ),

                            _buildTermsSection(
                              '5. User Responsibilities',
                              'You are responsible for maintaining account security, using the platform ethically, and respecting intellectual property rights. Any misuse may result in account termination.',
                            ),

                            _buildTermsSection(
                              '6. Content Ownership',
                              'Cerenix owns platform content and AI models. User-generated content remains user property, but you grant Cerenix license to use it for platform improvement.',
                            ),

                            _buildTermsSection(
                              '7. Service Availability',
                              'We strive for 24/7 availability but may perform maintenance. Premium features may require subscription, with clear communication about any changes.',
                            ),

                            _buildTermsSection(
                              '8. Termination Policy',
                              'Accounts may be suspended for violations of these terms. Users will be notified of significant changes to terms and conditions.',
                            ),

                            const SizedBox(height: 40),

                            // Acceptance Section
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Checkbox(
                                        value: _acceptedTerms,
                                        onChanged: (value) {
                                          setState(() {
                                            _acceptedTerms = value ?? false;
                                          });
                                        },
                                        activeColor: const Color(0xFF6366F1),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _acceptedTerms = !_acceptedTerms;
                                            });
                                          },
                                          child: const Text(
                                            'I have read, understood, and agree to be bound by the Terms & Conditions of the Cerenix AI Learning Platform. I acknowledge that my academic data will be used to personalize my learning experience.',
                                            style: TextStyle(
                                              color: Color(0xFF374151),
                                              fontSize: 14,
                                              height: 1.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: ElevatedButton(
                                      onPressed: _acceptedTerms ? _continueToHome : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF6366F1),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        elevation: 2,
                                        shadowColor: const Color(0xFF6366F1).withOpacity(0.3),
                                      ),
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Continue to Cerenix',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Icon(Icons.arrow_forward_rounded, size: 20),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Floating Scroll Button - Only shows when not at bottom
            if (_showScrollIndicator && !_isAtBottom)
              Positioned(
                bottom: 20,
                right: 20,
                child: _buildFloatingScrollButton(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingScrollButton() {
    return GestureDetector(
      onTap: _scrollToNextSection,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF6366F1),
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.arrow_downward_rounded,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String emoji, String label, String? value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value ?? 'Not selected',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF1F2937),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsSection(String title, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  size: 16,
                  color: Color(0xFF6366F1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}