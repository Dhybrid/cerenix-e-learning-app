import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/network/api_service.dart';
import '../../../core/constants/endpoints.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/custom_drawer.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Simple navigation with named routes
  void _navigateTo(String routeName) {
    Navigator.pushNamed(context, routeName);
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _performLogout();
              },
              child: const Text(
                'Yes, Logout',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  // ========== UPDATED LOGOUT METHOD ==========
  Future<void> _performLogout() async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(width: 16),
              Text('Logging out...'),
            ],
          ),
          duration: Duration(seconds: 3),
        ),
      );

      // Call the updated ApiService logout (it handles everything - both Django and local storage)
      await ApiService().logout();
      print('✅ Logout completed successfully');

      // Navigate to signin page and remove all routes
      Navigator.pushNamedAndRemoveUntil(context, '/signin', (route) => false);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logged out successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('❌ Logout error: $e');
      // Fallback - clear storage and navigate anyway
      final box = await Hive.openBox('user_box');
      await box.clear();

      Navigator.pushNamedAndRemoveUntil(context, '/signin', (route) => false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logged out from app'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
  // ========== END OF UPDATED METHOD ==========

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF101A2B) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE2E8F0);
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark
          ? const Color(0xFF09111F)
          : const Color(0xFFF8FAFC),
      appBar: CustomAppBar(
        scaffoldKey: _scaffoldKey,
        title: 'Profile',
        showNotifications: false,
        showProfile: true,
      ),
      drawer: const CustomDrawer(),
      body: Column(
        children: [
          // Top gradient section with perfect curve
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.shade800,
                  Colors.lightBlue.shade600,
                  Colors.cyan.shade400,
                ],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(60),
                bottomRight: Radius.circular(60),
              ),
            ),
            child: Stack(
              children: [
                // Background decorative elements
                Positioned(
                  top: -20,
                  right: -20,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  bottom: -30,
                  left: -20,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                // Profile title
                const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: 20),
                      Text(
                        'PROFILE',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 2,
                          shadows: [
                            Shadow(
                              blurRadius: 8,
                              color: Colors.black26,
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Manage your account settings',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Profile options section
          Expanded(
            child: Container(
              color: Colors.transparent,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(height: 10),

                    // Profile Options Card
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: borderColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.20 : 0.10,
                            ),
                            blurRadius: 25,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildProfileOption(
                            icon: Icons.person_outline_rounded,
                            title: 'Profile',
                            subtitle: 'Manage your personal information',
                            color: Colors.blue,
                            onTap: () => _navigateTo('/profile-details'),
                          ),
                          _buildDivider(),
                          _buildProfileOption(
                            icon: Icons.info_outline_rounded,
                            title: 'General Information',
                            subtitle: 'Basic account details',
                            color: Colors.green,
                            onTap: () => _navigateTo('/general-info'),
                          ),
                          // _buildDivider(),
                          // _buildProfileOption(
                          //   icon: Icons.bookmark_outline_rounded,
                          //   title: 'Bookmarked Questions',
                          //   subtitle: 'Your saved learning materials',
                          //   color: Colors.purple,
                          //   onTap: () => _navigateTo('/bookmarks'),
                          // ),
                          _buildDivider(),
                          _buildProfileOption(
                            icon: Icons.rocket_launch_outlined,
                            title: 'Activate App',
                            subtitle: 'Unlock premium features',
                            color: Colors.red,
                            onTap: () => _navigateTo('/activate'),
                          ),
                          // _buildDivider(),
                          // _buildProfileOption(
                          //   icon: Icons.admin_panel_settings_outlined,
                          //   title: 'Hidden Functions',
                          //   subtitle: 'Advanced settings and tools',
                          //   color: Colors.teal,
                          //   onTap: () => _navigateTo('/hidden-functions'),
                          // ),
                          _buildDivider(),
                          _buildProfileOption(
                            icon: Icons.trending_up_outlined,
                            title: 'Update Level',
                            subtitle: 'Upgrade your learning level',
                            color: Colors.indigo,
                            onTap: () => _navigateTo('/update-level'),
                          ),
                          _buildDivider(),
                          _buildProfileOption(
                            icon: Icons.settings_outlined,
                            title: 'Settings',
                            subtitle: 'App preferences and configuration',
                            color: Colors.brown,
                            onTap: () => _navigateTo('/settings'),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Logout button
                    Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.red.shade400, Colors.red.shade600],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: _showLogoutDialog,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.logout_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Logout',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 1,
                                ),
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
          ),
        ],
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? const Color(0xFFF8FAFC) : Colors.black87;
    final subtitleColor = isDark
        ? const Color(0xFFCBD5E1)
        : Colors.grey.shade600;
    final arrowColor = isDark
        ? Colors.white.withValues(alpha: 0.55)
        : Colors.grey.shade400;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Icon container with color
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),

              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: subtitleColor,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),

              // 45-degree arrow
              Transform.rotate(
                angle: -45 * 3.14159 / 180,
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 18,
                  color: arrowColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Divider(
        height: 1,
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.grey.shade200,
      ),
    );
  }
}
