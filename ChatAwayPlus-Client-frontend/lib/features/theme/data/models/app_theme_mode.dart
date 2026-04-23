/// Theme mode options for ChatAway+
enum AppThemeMode {
  /// Light theme (white background, dark text)
  light,

  /// Dark theme (black background, light text)
  dark,

  /// Follow system theme setting
  system,
}

/// Extension methods for AppThemeMode
extension AppThemeModeExtension on AppThemeMode {
  /// Get display name for UI
  String get displayName {
    switch (this) {
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
      case AppThemeMode.system:
        return 'System Default';
    }
  }

  /// Get description for UI
  String get description {
    switch (this) {
      case AppThemeMode.light:
        return 'Always use light theme';
      case AppThemeMode.dark:
        return 'Always use dark theme';
      case AppThemeMode.system:
        return 'Follow device settings';
    }
  }

  /// Convert to string for storage
  String toStorageString() => name;

  /// Create from storage string
  static AppThemeMode fromStorageString(String? value) {
    if (value == null) return AppThemeMode.light;
    return AppThemeMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => AppThemeMode.light,
    );
  }
}
