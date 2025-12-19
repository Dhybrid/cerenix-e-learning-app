// lib/core/routes.dart
import 'package:flutter/material.dart';

class AppRoutes {
  static const String home = '/home';
  static const String features = '/features';
  static const String ai = '/ai';           // ← AI (not ai-voice)
  static const String progress = '/progress';
  static const String profile = '/profile';

  static final List<String> routes = [home, features, ai, progress, profile];

  static void navigate(BuildContext context, int index) {
    Navigator.pushReplacementNamed(context, routes[index]);
  }
}