import 'package:flutter/material.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/custom_drawer.dart';

class AIHomeScreen extends StatefulWidget {
  const AIHomeScreen({super.key});

  @override
  State<AIHomeScreen> createState() => _AIHomeScreenState();
}

class _AIHomeScreenState extends State<AIHomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _showChatHistory = false;
  String? _pressedCard;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark
          ? const Color(0xFF09111F)
          : const Color(0xFFF8FAFC),
      appBar: CustomAppBar(
        scaffoldKey: _scaffoldKey,
        title: 'AI Home',
        showNotifications: false,
        showProfile: true,
      ),
      drawer: const CustomDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            _buildWelcomeSection(),
            const SizedBox(height: 32),

            // AI Features Grid - Improved Layout
            _buildFeaturesSection(),
            const SizedBox(height: 40),

            // History Section
            _buildHistorySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Hello User! ',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                ),
              ),
              TextSpan(
                text: 'I am Cereva',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w300,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'How may I help you today?',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 280,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Main Feature Card - Talk to Cereva
              Expanded(
                flex: 3,
                child: _buildMainFeatureCard(
                  key: 'talk',
                  title: 'Talk to Cereva',
                  subtitle: 'Voice conversation',
                  icon: Icons.mic_none,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  onTap: () => _navigateTo('/voice'),
                ),
              ),
              const SizedBox(width: 4),
              // Right Side - 2 Vertical Cards
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    // Top Right Card - Chat with Cereva
                    Expanded(
                      child: _buildRightFeatureCard(
                        key: 'chat',
                        title: 'Chat with Cereva',
                        subtitle: 'Text conversation',
                        icon: Icons.chat_bubble_outline,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF10B981), Color(0xFF34D399)],
                        ),
                        onTap: () => _navigateTo('/chat'),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Bottom Right Card - Scan Document
                    Expanded(
                      child: _buildRightFeatureCard(
                        key: 'scan',
                        title: 'Scan Document',
                        subtitle: 'Scan and analyze',
                        icon: Icons.document_scanner,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
                        ),
                        onTap: () => _navigateTo('/scan-doc'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Read Document as separate row below
        SizedBox(
          height: 100,
          child: _buildBottomFeatureCard(
            key: 'read',
            title: 'Read Document',
            subtitle: 'Document analysis',
            icon: Icons.article_outlined,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
            ),
            onTap: () => _navigateTo('/read-doc'),
          ),
        ),
      ],
    );
  }

  Widget _buildMainFeatureCard({
    required String key,
    required String title,
    required String subtitle,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    bool isPressed = _pressedCard == key;

    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _pressedCard = key;
        });
      },
      onTapUp: (_) {
        setState(() {
          _pressedCard = null;
        });
        onTap();
      },
      onTapCancel: () {
        setState(() {
          _pressedCard = null;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.identity()..scale(isPressed ? 0.95 : 1.0),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(isPressed ? 0.2 : 0.3),
              blurRadius: isPressed ? 8 : 15,
              offset: Offset(0, isPressed ? 3 : 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background pattern
            Positioned(
              top: -10,
              right: -10,
              child: Opacity(
                opacity: 0.1,
                child: Icon(icon, size: 80, color: Colors.white),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: Colors.white, size: 28),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 45 degree arrow
            Positioned(
              top: 16,
              right: 16,
              child: Transform.rotate(
                angle: 0.785,
                child: Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white.withOpacity(0.7),
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightFeatureCard({
    required String key,
    required String title,
    required String subtitle,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    bool isPressed = _pressedCard == key;

    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _pressedCard = key;
        });
      },
      onTapUp: (_) {
        setState(() {
          _pressedCard = null;
        });
        onTap();
      },
      onTapCancel: () {
        setState(() {
          _pressedCard = null;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.identity()..scale(isPressed ? 0.95 : 1.0),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withOpacity(isPressed ? 0.1 : 0.2),
              blurRadius: isPressed ? 6 : 10,
              offset: Offset(0, isPressed ? 2 : 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: Colors.white, size: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            // 45 degree arrow
            Positioned(
              top: 8,
              right: 8,
              child: Transform.rotate(
                angle: 0.785,
                child: Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white.withOpacity(0.7),
                  size: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomFeatureCard({
    required String key,
    required String title,
    required String subtitle,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    bool isPressed = _pressedCard == key;

    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _pressedCard = key;
        });
      },
      onTapUp: (_) {
        setState(() {
          _pressedCard = null;
        });
        onTap();
      },
      onTapCancel: () {
        setState(() {
          _pressedCard = null;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.identity()..scale(isPressed ? 0.97 : 1.0),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withOpacity(isPressed ? 0.1 : 0.2),
              blurRadius: isPressed ? 6 : 10,
              offset: Offset(0, isPressed ? 2 : 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 45 degree arrow
            Positioned(
              top: 16,
              right: 16,
              child: Transform.rotate(
                angle: 0.785,
                child: Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white.withOpacity(0.7),
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ... (Keep all the other methods the same: _buildHistorySection, _buildHistoryToggle, etc.)

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            GestureDetector(
              onTap: () {
                if (_showChatHistory) {
                  _navigateTo('/all-chats');
                } else {
                  _navigateTo('/all-documents');
                }
              },
              child: Row(
                children: [
                  Text(
                    'See all',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward, color: Colors.grey[600], size: 16),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Toggle Buttons
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHistoryToggle('Documents', !_showChatHistory),
              const SizedBox(width: 8),
              _buildHistoryToggle('Chats', _showChatHistory),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Content based on toggle
        _showChatHistory ? _buildChatHistory() : _buildDocumentHistory(),
      ],
    );
  }

  Widget _buildHistoryToggle(String text, bool isActive) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showChatHistory = text == 'Chats';
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isActive ? const Color(0xFF6366F1) : Colors.grey[600],
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentHistory() {
    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildDocumentItem(
            title: 'UI Inspiration',
            subtitle: 'Dark theme ideas',
            type: 'PDF',
            color: const Color(0xFFF59E0B),
          ),
          const SizedBox(width: 12),
          _buildDocumentItem(
            title: 'Color Palettes',
            subtitle: 'AL design system',
            type: 'DOC',
            color: const Color(0xFF10B981),
          ),
          const SizedBox(width: 12),
          _buildDocumentItem(
            title: 'Best Models 2025',
            subtitle: 'Research document',
            type: 'PDF',
            color: const Color(0xFF6366F1),
          ),
          const SizedBox(width: 12),
          _buildDocumentItem(
            title: 'Design Tools 2023',
            subtitle: 'Trending tools',
            type: 'PDF',
            color: const Color(0xFF8B5CF6),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentItem({
    required String title,
    required String subtitle,
    required String type,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () => _navigateTo('/document-view'),
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.description, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      type,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatHistory() {
    return Column(
      children: [
        _buildChatItem('I need some UI inspiration for dark...'),
        const SizedBox(height: 12),
        _buildChatItem('Show me some color palettes for AL...'),
        const SizedBox(height: 12),
        _buildChatItem('What are the best models apps 2025...'),
        const SizedBox(height: 12),
        _buildChatItem(
          'What are the top trending collaborating interface design tools 2023',
        ),
      ],
    );
  }

  Widget _buildChatItem(String message) {
    return GestureDetector(
      onTap: () => _navigateTo('/chat'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.forum_outlined,
                color: const Color(0xFF10B981),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }

  void _navigateTo(String route) {
    print('Navigating to: $route');
  }
}
