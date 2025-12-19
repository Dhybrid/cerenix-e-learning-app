// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF0077B6),
      secondary: const Color(0xFFFF6B35),
    ),
    scaffoldBackgroundColor: const Color(0xFFF8FAFC),
  );
}