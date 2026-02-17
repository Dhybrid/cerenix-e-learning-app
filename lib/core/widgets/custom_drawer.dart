// lib/core/widgets/custom_drawer.dart
import 'package:flutter/material.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 60, left: 16, right: 16, bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.97),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Cerenix Menu',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0077B6),
                  ),
                ),
              ),
              _drawerItem(Icons.home, 'Home', '/home', context),
              _drawerItem(Icons.book, 'My Courses', '/courses', context),
              _drawerItem(
                Icons.calendar_month,
                'Calendar',
                '/coming-soon',
                context,
              ),
              // _drawerItem(Icons.timer, 'Documents Reader', '/debug', context),
              _drawerItem(Icons.credit_card, 'Billing', '/activate', context),
              _drawerItem(Icons.smart_toy, 'AI Board', '/ai-board', context),
              _drawerItem(
                Icons.scanner,
                'Scan Document',
                '/coming-soon',
                context,
              ),
              _drawerItem(Icons.calculate, 'CGPA Calculator', '/cgpa', context),
              _drawerItem(Icons.settings, 'Settings', '/settings', context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drawerItem(
    IconData icon,
    String title,
    String route,
    BuildContext context,
  ) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF0077B6)),
      title: Text(title),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Color(0xFF9CA3AF),
      ),
      onTap: () {
        Navigator.pop(context);
        Navigator.pushNamed(context, route);
      },
    );
  }
}
