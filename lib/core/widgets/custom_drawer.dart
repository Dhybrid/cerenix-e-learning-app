// lib/core/widgets/custom_drawer.dart
import 'package:flutter/material.dart';
import '../theme/theme_controller.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppThemeController.instance,
      builder: (context, _) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;
        final surface = isDark ? const Color(0xFF101A2B) : Colors.white;
        final panelColor = isDark
            ? surface.withOpacity(0.98)
            : Colors.white.withOpacity(0.97);
        final shadowColor = Colors.black.withOpacity(isDark ? 0.28 : 0.10);

        return Container(
          margin: const EdgeInsets.only(
            top: 60,
            left: 16,
            right: 16,
            bottom: 16,
          ),
          decoration: BoxDecoration(
            color: panelColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
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
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cerenix Menu',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.04)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withOpacity(0.08)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: SwitchListTile(
                            value: AppThemeController.instance.isDarkMode,
                            onChanged: (_) =>
                                AppThemeController.instance.toggleTheme(),
                            title: Text(
                              'Dark mode',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                            subtitle: Text(
                              'Saved on this device',
                              style: TextStyle(
                                color: theme.textTheme.bodySmall?.color,
                              ),
                            ),
                            activeColor: scheme.primary,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _drawerItem(
                    Icons.home,
                    'Home',
                    '/home',
                    context,
                    scheme.primary,
                  ),
                  _drawerItem(
                    Icons.book,
                    'My Courses',
                    '/courses',
                    context,
                    scheme.primary,
                  ),
                  _drawerItem(
                    Icons.calendar_month,
                    'Calendar',
                    '/coming-soon',
                    context,
                    scheme.primary,
                  ),
                  _drawerItem(
                    Icons.credit_card,
                    'Billing',
                    '/activate',
                    context,
                    scheme.primary,
                  ),
                  _drawerItem(
                    Icons.smart_toy,
                    'AI Board',
                    '/ai-board',
                    context,
                    scheme.primary,
                  ),
                  _drawerItem(
                    Icons.scanner,
                    'Scan Document',
                    '/coming-soon',
                    context,
                    scheme.primary,
                  ),
                  _drawerItem(
                    Icons.calculate,
                    'CGPA Calculator',
                    '/cgpa',
                    context,
                    scheme.primary,
                  ),
                  _drawerItem(
                    Icons.settings,
                    'Settings',
                    '/settings',
                    context,
                    scheme.primary,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _drawerItem(
    IconData icon,
    String title,
    String route,
    BuildContext context,
    Color iconColor,
  ) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
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
