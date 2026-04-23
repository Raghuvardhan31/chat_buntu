import 'package:shared_preferences/shared_preferences.dart';
import 'package:chataway_plus/features/theme/data/models/app_theme_mode.dart';

/// Local datasource for theme persistence using SharedPreferences
/// Non-sensitive data, so SharedPreferences is appropriate
class ThemeLocalDataSource {
  static const String _themeKey = 'app_theme_mode';

  /// Singleton instance
  static final ThemeLocalDataSource _instance =
      ThemeLocalDataSource._internal();
  static ThemeLocalDataSource get instance => _instance;
  ThemeLocalDataSource._internal();

  SharedPreferences? _prefs;

  /// Initialize SharedPreferences
  Future<void> _ensureInitialized() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Get saved theme mode
  /// Returns [AppThemeMode.light] as default if not set
  Future<AppThemeMode> getThemeMode() async {
    await _ensureInitialized();
    final value = _prefs?.getString(_themeKey);
    return AppThemeModeExtension.fromStorageString(value);
  }

  /// Save theme mode
  Future<bool> saveThemeMode(AppThemeMode mode) async {
    await _ensureInitialized();
    return await _prefs?.setString(_themeKey, mode.toStorageString()) ?? false;
  }

  /// Clear theme preference (for logout)
  Future<bool> clearThemeMode() async {
    await _ensureInitialized();
    return await _prefs?.remove(_themeKey) ?? false;
  }

  /// Check if theme preference exists
  Future<bool> hasThemePreference() async {
    await _ensureInitialized();
    return _prefs?.containsKey(_themeKey) ?? false;
  }
}
