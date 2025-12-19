// lib/core/widgets/custom_app_bar.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../constants/endpoints.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  final String title;
  final bool showProfile;
  final bool showNotifications;
  final List<Widget>? additionalActions;

  const CustomAppBar({
    super.key,
    required this.scaffoldKey,
    this.title = 'Cerenix',
    this.showProfile = false,
    this.showNotifications = true,
    this.additionalActions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  // Simple method to get profile image URL
  String _getProfileImageUrl() {
    try {
      final box = Hive.box('user_box');
      final userData = box.get('current_user');
      if (userData == null) return 'https://i.pravatar.cc/150?img=3';
      
      final avatarUrl = userData['avatar']?.toString() ?? '';
      if (avatarUrl.isEmpty) return 'https://i.pravatar.cc/150?img=3';
      
      if (avatarUrl.startsWith('http')) return avatarUrl;
      
      return avatarUrl.startsWith('/') 
          ? '${ApiEndpoints.baseUrl}$avatarUrl'
          : '${ApiEndpoints.baseUrl}/$avatarUrl';
    } catch (e) {
      return 'https://i.pravatar.cc/150?img=3';
    }
  }

  // Simple method to get activation grade
  String? _getActivationGrade() {
    try {
      final box = Hive.box('user_box');
      final userData = box.get('current_user');
      if (userData == null) return null;
      
      // Check direct activation field first
      if (userData['activation_grade'] != null) {
        return userData['activation_grade'].toString();
      }
      
      // Check activations array
      if (userData['activations'] is List && (userData['activations'] as List).isNotEmpty) {
        final activation = (userData['activations'] as List).first;
        if (activation is Map && activation['grade'] != null) {
          return activation['grade'].toString();
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  // Simple method to get border color
  Color? _getBorderColor() {
    final grade = _getActivationGrade();
    if (grade == null) return null;
    
    switch (grade.toLowerCase()) {
      case 'gold': return Colors.amber;
      case 'premium': return Colors.purple;
      case 'regular': return Colors.blue;
      default: return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileImageUrl = _getProfileImageUrl();
    final borderColor = _getBorderColor();

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.only(left: 8, top: 8),
        child: IconButton(
          icon: const Icon(Icons.segment, color: Color(0xFF0077B6), size: 28),
          onPressed: () => scaffoldKey.currentState?.openDrawer(),
        ),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0077B6))),
      actions: [
        if (showNotifications) ..._buildNotificationAction(context),
        if (showProfile) _buildProfileAction(profileImageUrl, borderColor),
        if (additionalActions != null) ...additionalActions!,
        const SizedBox(width: 8),
      ],
    );
  }

  List<Widget> _buildNotificationAction(BuildContext context) {
    return [
      Stack(
        children: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Color(0xFF0077B6)), 
            onPressed: () => Navigator.pushNamed(context, '/notification'),
          ),
          Positioned(
            right: 8, top: 8, 
            child: Container(
              width: 10, height: 10, 
              decoration: const BoxDecoration(
                color: Color(0xFFFF6B35), 
                shape: BoxShape.circle
              )
            )
          ),
        ],
      ),
    ];
  }

  // Simple profile action with border if activated
  Widget _buildProfileAction(String profileImageUrl, Color? borderColor) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 4),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor ?? Colors.transparent,
            width: borderColor != null ? 2.5 : 0.0,
          ),
        ),
        child: CircleAvatar(
          radius: 18,
          backgroundImage: NetworkImage(profileImageUrl),
          backgroundColor: const Color(0xFFFF6B35).withOpacity(0.1),
        ),
      ),
    );
  }
}