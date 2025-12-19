// lib/features/main/screens/main_layout.dart
import 'package:flutter/material.dart';
import '../../home/screens/home_screen.dart';

// Import the screens without creating duplicate names
import '../../all_features/screens/features_screen.dart' as features;
import '../../cereva/screens/ai_screen.dart' as ai;
import '../../progress/screens/progress_screen.dart' as progress;
import '../../profile/screens/profile_screen.dart' as profile;

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  bool _showAIOptions = false;

  // List of all your main screens - using the aliased imports
  final List<Widget> _screens = [
    const HomeScreen(),                      // Index 0
    const features.FeaturesScreen(),         // Index 1
    const ai.AIScreen(),                     // Index 2
    const progress.ProgressScreen(),         // Index 3
    const profile.ProfileScreen(),           // Index 4
  ];

  void _onItemTapped(int index) {
    if (index == 2) {
      // AI button tapped - toggle options panel
      setState(() {
        _showAIOptions = !_showAIOptions;
      });
    } else {
      // Other buttons tapped - navigate normally
      setState(() {
        _currentIndex = index;
        _showAIOptions = false; // Hide AI options when other tabs are selected
      });
    }
  }

  void _navigateToAIOption(String route) {
    setState(() {
      _showAIOptions = false;
    });
    Navigator.pushNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          _screens[_currentIndex],
          
          // AI Options Panel - Overlay on top of everything
          if (_showAIOptions) _buildAIOptionsOverlay(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildAIOptionsOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _showAIOptions = false;
          });
        },
        child: Container(
          color: Colors.black.withOpacity(0.2),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              // ADJUST THIS VALUE: Reduce to bring options closer to nav
              // Current: 60, try 55, 50, 45 etc. until overflow disappears
              padding: const EdgeInsets.only(bottom: 36), // REDUCED FROM 65
              child: _buildAIOptionsPanel(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAIOptionsPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _aiOptionItem(
            icon: Icons.document_scanner,
            title: 'Scan Document',
            subtitle: 'Extract text from images',
            onTap: () => _navigateToAIOption('/scanner'),
          ),
          // ADJUST THIS VALUE: Reduce to make options closer together
          const SizedBox(height: 4), // REDUCED FROM 6
          _aiOptionItem(
            icon: Icons.smart_toy,
            title: 'Cereva GPT',
            subtitle: 'AI-powered conversations',
            onTap: () => _navigateToAIOption('/gpt'),
          ),
          // ADJUST THIS VALUE: Reduce to make options closer together
          const SizedBox(height: 4), // REDUCED FROM 6
          _aiOptionItem(
            icon: Icons.mic,
            title: 'Voice Chat',
            subtitle: 'Talk to Cereva AI',
            onTap: () => _navigateToAIOption('/ai-voice'),
          ),
        ],
      ),
    );
  }

  Widget _aiOptionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          // ADJUST THIS VALUE: Reduce padding to make options shorter
          padding: const EdgeInsets.all(10), // REDUCED FROM 12
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                // ADJUST THIS VALUE: Reduce icon container padding
                padding: const EdgeInsets.all(8), // REDUCED FROM 10
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFFFF6B35),
                  size: 20, // REDUCED FROM 22
                ),
              ),
              // ADJUST THIS VALUE: Reduce space between icon and text
              const SizedBox(width: 10), // REDUCED FROM 12
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13, // REDUCED FROM 14
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    // ADJUST THIS VALUE: Reduce space between title and subtitle
                    const SizedBox(height: 1), // REDUCED FROM 2
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 10, // REDUCED FROM 11
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 12, // REDUCED FROM 14
                color: Color(0xFF9CA3AF),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          // ADJUST THIS VALUE: Increase nav height if needed
          height: 69, // REDUCED FROM 70 to prevent overflow
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.home_rounded, 'Home', 0),
              _navItem(Icons.apps_rounded, 'Features', 1),
              _buildAIFloatingButton(),
              _navItem(Icons.bar_chart_rounded, 'Progress', 3),
              _navItem(Icons.person_rounded, 'Profile', 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAIFloatingButton() {
    return GestureDetector(
      onTap: () => _onItemTapped(2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            // ADJUST THESE VALUES: Make AI button smaller if needed
            width: 37, // REDUCED FROM 50
            height: 37, // REDUCED FROM 50
            decoration: BoxDecoration(
              gradient: _showAIOptions 
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFF6B35), Color(0xFFFF8E50)],
                    )
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0077B6), Color(0xFF0096C7)],
                    ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (_showAIOptions ? const Color(0xFFFF6B35) : const Color(0xFF0077B6)).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              _showAIOptions ? Icons.close : Icons.auto_awesome,
              color: Colors.white,
              size: 20, // REDUCED FROM 24
            ),
          ),
          const SizedBox(height: 2), // REDUCED FROM 4
          Text(
            'AI',
            style: TextStyle(
              fontSize: 11, // REDUCED FROM 12
              fontWeight: _showAIOptions ? FontWeight.w600 : FontWeight.normal,
              color: _showAIOptions ? const Color(0xFFFF6B35) : const Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final isActive = _currentIndex == index;
    
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? const Color(0xFF0077B6) : const Color(0xFF9CA3AF),
            size: 24, // REDUCED FROM 26
          ),
          const SizedBox(height: 2), // REDUCED FROM 4
          Text(
            label,
            style: TextStyle(
              fontSize: 11, // REDUCED FROM 12
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              color: isActive ? const Color(0xFF0077B6) : const Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }
}