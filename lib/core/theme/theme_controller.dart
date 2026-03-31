import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AppThemeController extends ChangeNotifier {
  AppThemeController._();

  static final AppThemeController instance = AppThemeController._();

  static const String _boxName = 'settings_box';
  static const String _themeKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.light;
  bool _loaded = false;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> load() async {
    final box = Hive.isBoxOpen(_boxName)
        ? Hive.box(_boxName)
        : await Hive.openBox(_boxName);
    final savedMode = box.get(_themeKey) as String?;
    _themeMode = _themeModeFromString(savedMode);
    _loaded = true;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    await setThemeMode(isDarkMode ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode && _loaded) {
      return;
    }

    _themeMode = mode;
    final box = Hive.isBoxOpen(_boxName)
        ? Hive.box(_boxName)
        : await Hive.openBox(_boxName);
    await box.put(_themeKey, _themeModeToString(mode));
    await box.flush();
    notifyListeners();
  }

  String get accessibilityLabel =>
      isDarkMode ? 'Switch to light mode' : 'Switch to dark mode';

  IconData get icon =>
      isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded;

  ThemeMode _themeModeFromString(String? value) {
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
      default:
        return ThemeMode.light;
    }
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.light:
      case ThemeMode.system:
        return 'light';
    }
  }
}
