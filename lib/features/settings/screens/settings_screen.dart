import 'package:flutter/material.dart';
import '../../../core/theme/theme_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF101A2B) : Colors.white;
    final pageBackground = isDark
        ? const Color(0xFF09111F)
        : const Color(0xFFF8FAFC);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE2E8F0);
    final titleColor = isDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF0F172A);
    final bodyColor = isDark
        ? const Color(0xFFCBD5E1)
        : const Color(0xFF64748B);

    return AnimatedBuilder(
      animation: AppThemeController.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: pageBackground,
          appBar: AppBar(
            backgroundColor: surface,
            surfaceTintColor: Colors.transparent,
            foregroundColor: titleColor,
            title: const Text('Settings'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        AppThemeController.instance.icon,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dark mode',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Apply the app theme across supported screens.',
                            style: TextStyle(fontSize: 13, color: bodyColor),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: AppThemeController.instance.isDarkMode,
                      onChanged: (value) =>
                          AppThemeController.instance.setThemeMode(
                            value ? ThemeMode.dark : ThemeMode.light,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _SettingsCard(
                icon: Icons.person_outline_rounded,
                title: 'Profile details',
                subtitle: 'View your personal and academic information',
                onTap: () => Navigator.pushNamed(context, '/profile-details'),
              ),
              const SizedBox(height: 12),
              _SettingsCard(
                icon: Icons.edit_outlined,
                title: 'Edit profile',
                subtitle: 'Update your account information',
                onTap: () => Navigator.pushNamed(context, '/edit-profile'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE2E8F0);
    final titleColor = isDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF0F172A);
    final bodyColor = isDark
        ? const Color(0xFFCBD5E1)
        : const Color(0xFF64748B);

    return Material(
      color: isDark ? const Color(0xFF101A2B) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: scheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13, color: bodyColor),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: bodyColor),
            ],
          ),
        ),
      ),
    );
  }
}
