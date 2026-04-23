import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/features/profile/data/datasources/profile_local_datasource.dart';

import 'settings_user_state.dart';

class SettingsUserNotifier extends StateNotifier<SettingsUserState> {
  SettingsUserNotifier(this._localDataSource)
    : super(const SettingsUserState(isLoading: false));

  final ProfileLocalDataSource _localDataSource;

  Future<void> loadCurrentUser() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final profile = await _localDataSource.getProfile();
      state = state.copyWith(
        isLoading: false,
        hasLoaded: true,
        profile: profile,
        errorMessage: null,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [SettingsUserNotifier] Failed to load user: $e');
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load user',
      );
    }
  }

  void clearError() {
    if (state.errorMessage == null) return;
    state = state.clearError();
  }
}
