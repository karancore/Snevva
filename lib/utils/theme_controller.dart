import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends GetxController with WidgetsBindingObserver {
  final isDarkMode = false.obs;

  ThemeMode get themeMode =>
      isDarkMode.value ? ThemeMode.dark : ThemeMode.light;

  static const String _themeKey = 'is_dark_mode';

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _loadTheme();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  Future<void> _loadTheme() async {
    final resolvedTheme = await _resolveCurrentThemeIsDark();
    _applyTheme(resolvedTheme);
  }

  bool _isSystemDarkMode() {
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    return brightness == Brightness.dark;
  }

  Future<bool> _resolveCurrentThemeIsDark() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_themeKey)) {
      return prefs.getBool(_themeKey) ?? _isSystemDarkMode();
    }
    return _isSystemDarkMode();
  }

  Future<void> _syncThemeWithSystem() async {
    final systemThemeIsDark = _isSystemDarkMode();
    _applyTheme(systemThemeIsDark);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, systemThemeIsDark);
  }

  void _applyTheme(bool isDark) {
    isDarkMode.value = isDark;
    Get.changeThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> toggleTheme() async {
    final currentThemeIsDark = await _resolveCurrentThemeIsDark();
    final toggledThemeIsDark = !currentThemeIsDark;
    _applyTheme(toggledThemeIsDark);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, toggledThemeIsDark);
  }

  @override
  void didChangePlatformBrightness() {
    _syncThemeWithSystem();
  }
}
