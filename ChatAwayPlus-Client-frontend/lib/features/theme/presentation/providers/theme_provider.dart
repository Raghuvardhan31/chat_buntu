import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/features/theme/data/models/app_theme_mode.dart';
import 'package:chataway_plus/features/theme/data/datasources/theme_local_datasource.dart';

/// State class for theme
class ThemeState {
  final AppThemeMode themeMode;
  final bool isLoading;

  const ThemeState({
    this.themeMode = AppThemeMode.light,
    this.isLoading = true,
  });

  ThemeState copyWith({AppThemeMode? themeMode, bool? isLoading}) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  /// Get the actual ThemeMode for Flutter
  ThemeMode get flutterThemeMode {
    switch (themeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  /// Check if currently using dark mode (considering system setting)
  bool get isDarkMode {
    if (themeMode == AppThemeMode.dark) return true;
    if (themeMode == AppThemeMode.light) return false;
    // System mode - check platform brightness
    final brightness =
        SchedulerBinding.instance.platformDispatcher.platformBrightness;
    return brightness == Brightness.dark;
  }
}

/// Theme notifier for managing theme state
class ThemeNotifier extends StateNotifier<ThemeState> {
  final ThemeLocalDataSource _dataSource;

  ThemeNotifier(this._dataSource) : super(const ThemeState()) {
    _loadTheme();
  }

  /// Load saved theme from storage
  Future<void> _loadTheme() async {
    try {
      final savedMode = await _dataSource.getThemeMode();
      state = state.copyWith(themeMode: savedMode, isLoading: false);
    } catch (e) {
      debugPrint('⚠️ [ThemeNotifier] Failed to load theme: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  /// Set theme mode and persist
  Future<void> setThemeMode(AppThemeMode mode) async {
    if (state.themeMode == mode) return;

    state = state.copyWith(themeMode: mode);

    try {
      await _dataSource.saveThemeMode(mode);
    } catch (e) {
      debugPrint('⚠️ [ThemeNotifier] Failed to save theme: $e');
    }
  }

  /// Toggle between light and dark (ignores system)
  Future<void> toggleTheme() async {
    final newMode = state.themeMode == AppThemeMode.dark
        ? AppThemeMode.light
        : AppThemeMode.dark;
    await setThemeMode(newMode);
  }

  /// Reset to default (light theme)
  Future<void> resetToDefault() async {
    await setThemeMode(AppThemeMode.light);
  }
}

/// Provider for theme datasource
final themeLocalDataSourceProvider = Provider<ThemeLocalDataSource>((ref) {
  return ThemeLocalDataSource.instance;
});

/// Provider for theme notifier
final themeNotifierProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((
  ref,
) {
  final dataSource = ref.watch(themeLocalDataSourceProvider);
  return ThemeNotifier(dataSource);
});

/// Convenience provider for current theme mode
final currentThemeModeProvider = Provider<AppThemeMode>((ref) {
  return ref.watch(themeNotifierProvider).themeMode;
});

/// Convenience provider for Flutter ThemeMode
final flutterThemeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(themeNotifierProvider).flutterThemeMode;
});

/// Convenience provider for isDarkMode check
final isDarkModeProvider = Provider<bool>((ref) {
  return ref.watch(themeNotifierProvider).isDarkMode;
});
