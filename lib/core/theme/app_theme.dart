// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  static const Color _lightPrimary = Color(0xFF0077B6);
  static const Color _lightAccent = Color(0xFFFF6B35);
  static const Color _lightSurface = Colors.white;
  static const Color _lightBackground = Color(0xFFF8FAFC);

  static const Color _darkPrimary = Color(0xFF4DA3FF);
  static const Color _darkAccent = Color(0xFFFF8A5B);
  static const Color _darkSurface = Color(0xFF101A2B);
  static const Color _darkBackground = Color(0xFF09111F);

  static ThemeData light = _buildTheme(
    brightness: Brightness.light,
    primary: _lightPrimary,
    secondary: _lightAccent,
    surface: _lightSurface,
    background: _lightBackground,
  );

  static ThemeData dark = _buildTheme(
    brightness: Brightness.dark,
    primary: _darkPrimary,
    secondary: _darkAccent,
    surface: _darkSurface,
    background: _darkBackground,
  );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color primary,
    required Color secondary,
    required Color surface,
    required Color background,
  }) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      primary: primary,
      secondary: secondary,
      surface: surface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      textTheme: ThemeData(brightness: brightness, useMaterial3: true).textTheme
          .apply(
            bodyColor: isDark
                ? const Color(0xFFF8FAFC)
                : const Color(0xFF0F172A),
            displayColor: isDark
                ? const Color(0xFFF8FAFC)
                : const Color(0xFF0F172A),
          ),
      iconTheme: IconThemeData(
        color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
      ),
      dividerColor: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : const Color(0xFFE2E8F0),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: primary,
        textColor: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary;
          }
          return isDark ? const Color(0xFFE2E8F0) : Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary.withValues(alpha: 0.45);
          }
          return isDark
              ? Colors.white.withValues(alpha: 0.14)
              : const Color(0xFFD6E4F0);
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark
            ? const Color(0xFF162235)
            : const Color(0xFF0F172A),
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.14)
                : const Color(0xFFD6E4F0),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF162235) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFE2E8F0),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFE2E8F0),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primary, width: 1.4),
        ),
      ),
    );
  }
}
