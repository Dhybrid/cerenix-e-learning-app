// lib/shared/widgets/bottom_nav.dart
import 'package:flutter/material.dart';
import '../../core/routes.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        child: Stack(
          children: [
            // BACKGROUND NAV
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _navItem(context, 0, Icons.home_rounded, 'Home'),
                  _navItem(context, 1, Icons.apps_rounded, 'Features'),
                  const SizedBox(width: 80),
                  _navItem(context, 3, Icons.bar_chart_rounded, 'Progress'),
                  _navItem(context, 4, Icons.person_rounded, 'Profile'),
                ],
              ),
            ),

            // AI BUTTON — FLOATING, GLOWING
            Center(
              child: GestureDetector(
                onTap: () => onTap(2),
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B35), Color(0xFFFF8A65)],
                    ),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFFF6B35).withOpacity(0.6), blurRadius: 20, offset: const Offset(0, 8)),
                      const BoxShadow(color: Colors.white, blurRadius: 10, offset: Offset(0, -4)),
                    ],
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 36),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(BuildContext context, int index, IconData icon, String label) {
    final isActive = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isActive ? const Color(0xFF0077B6) : const Color(0xFF9CA3AF), size: 28),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isActive ? const Color(0xFF0077B6) : const Color(0xFF9CA3AF),
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}