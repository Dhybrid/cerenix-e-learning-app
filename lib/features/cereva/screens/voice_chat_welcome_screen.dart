// lib/features/voice_chat/screens/voice_welcome_screen.dart
import 'package:flutter/material.dart';
import 'ai_voice_screen.dart'; // Import the voice chat screen

class VoiceWelcomeScreen extends StatelessWidget {
  const VoiceWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0F0F1A),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
                      color: Colors.white,
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),

            // Main Content - Expanded to prevent overflow
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    
                    // Title Section
                    const Column(
                      children: [
                        Text(
                          'Cerenix Voice',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'AI Voice Assistant',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // GIF Container - Transparent background
                    Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.transparent, // Transparent background
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/waveAI.gif', // Your GIF path
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback if GIF fails to load
                            return Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF6366F1),
                                    Color(0xFF8B5CF6),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.mic_rounded,
                                color: Colors.white,
                                size: 60,
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Features
                    const Column(
                      children: [
                        FeatureItem(icon: Icons.record_voice_over_rounded, text: 'Natural voice conversations'),
                        SizedBox(height: 16),
                        FeatureItem(icon: Icons.smart_toy_rounded, text: 'AI-powered responses'),
                        SizedBox(height: 16),
                        FeatureItem(icon: Icons.translate_rounded, text: 'Real-time processing'),
                      ],
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // Start Button - Fixed at bottom
            Container(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to voice chat screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VoiceChatScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mic_rounded, size: 20),
                      SizedBox(width: 12),
                      Text(
                        'Start Voice Chat',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
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

class FeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const FeatureItem({
    super.key,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: const Color(0xFF6366F1), size: 20),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}