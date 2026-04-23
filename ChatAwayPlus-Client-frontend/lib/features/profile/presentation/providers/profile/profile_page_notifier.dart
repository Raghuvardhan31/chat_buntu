// lib/features/profile/presentation/providers/profile_page_notifier.dart

import 'package:chataway_plus/features/profile/data/repositories/profile/profile_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:characters/characters.dart';
import 'package:chataway_plus/features/profile/data/models/current_user_profile_model.dart';

import 'profile_page_state.dart';

/// Notifier for managing profile UI state and operations
class ProfileUINotifier extends StateNotifier<ProfileUIState> {
  final ProfileRepository _profileRepository;

  String? _currentUploadingPath;
  String? _currentUpdatingName;
  String? _currentUpdatingStatus;

  void _safeSetState(ProfileUIState s) {
    if (mounted) state = s;
  }

  ProfileUINotifier(this._profileRepository) : super(const ProfileUIState());

  void _log(String message) {
    if (kDebugMode) debugPrint(message);
  }

  // =============================
  // Offline-First Profile Loading
  // =============================

  /// Load profile with offline-first approach
  /// 1. Load from local DB immediately (instant UI)
  /// 2. Fetch from server in background (sync)
  /// 3. Update UI when server data arrives
  Future<void> loadProfile() async {
    if (state.isLoading) return;
    _log('[ProfileUI] loadProfile(): start');

    // Step 1: Try loading from local database first (instant)
    final localProfile = await _profileRepository.getLocalProfile();
    if (localProfile != null) {
      _log('[ProfileUI] loadProfile(): local cache HIT -> update UI');
      _log(
        '[ProfileUI] loadProfile(): UI <- local name=${localProfile.firstName ?? ''}',
      );
      _log(
        '[ProfileUI] read name from local DB: ${localProfile.firstName ?? ''}',
      );
      _log(
        '[ProfileUI] read status from local DB: ${localProfile.content ?? ''}',
      );
      _log(
        '[ProfileUI] read chatPicture from local DB: ${localProfile.profilePic ?? ''}',
      );
      _safeSetState(
        state.copyWith(
          loadingState: ProfileLoadingState.loaded,
          profile: localProfile,
          hasEverLoaded: true,
          showShimmer: false,
        ),
      );
    } else {
      _log(
        '[ProfileUI] loadProfile(): local cache MISS -> show shimmer & fetch remote',
      );
      // Show shimmer if no local data
      _safeSetState(
        state.copyWith(
          loadingState: ProfileLoadingState.loading,
          showShimmer: true,
        ),
      );
    }

    // Step 2: Fetch from server in background
    _log('[ProfileUI] loadProfile(): fetching from server (background sync)');
    final result = await _profileRepository.getCurrentUserProfile();

    if (result.isSuccess && result.data?.data != null) {
      _log(
        '[ProfileUI] loadProfile(): server SUCCESS -> UI updated; repo saved to local',
      );
      _log(
        '[ProfileUI] loadProfile(): UI <- server name=${result.data!.data!.firstName ?? ''}',
      );
      _safeSetState(
        state.copyWith(
          loadingState: ProfileLoadingState.loaded,
          profile: result.data!.data,
          hasEverLoaded: true,
          showShimmer: false,
          errorMessage: null,
        ),
      );
    } else if (localProfile == null) {
      _log(
        '[ProfileUI] loadProfile(): server FAIL and no local -> show error: \\${result.errorMessage}',
      );
      // Only show error if we have no local data
      _safeSetState(
        state.copyWith(
          loadingState: ProfileLoadingState.error,
          errorMessage: result.errorMessage ?? 'Failed to load profile',
          showShimmer: false,
        ),
      );
    }
    // If we have local data and server fails, keep showing local data silently
  }

  /// Load profile only from local database (no network)
  Future<void> loadProfileLocalOnly() async {
    _log('[ProfileUI] loadProfileLocalOnly(): read from local DB only');
    final localProfile = await _profileRepository.getLocalProfile();
    if (localProfile != null) {
      _log('[ProfileUI] loadProfileLocalOnly(): local cache HIT -> update UI');
      _log(
        '[ProfileUI] loadProfileLocalOnly(): UI <- local name=${localProfile.firstName ?? ''}',
      );
      _log(
        '[ProfileUI] read name from local DB: ${localProfile.firstName ?? ''}',
      );
      _log(
        '[ProfileUI] read status from local DB: ${localProfile.content ?? ''}',
      );
      _log(
        '[ProfileUI] read chatPicture from local DB: ${localProfile.profilePic ?? ''}',
      );
      _safeSetState(
        state.copyWith(
          loadingState: ProfileLoadingState.loaded,
          profile: localProfile,
          hasEverLoaded: true,
          showShimmer: false,
        ),
      );
    } else {
      _log(
        '[ProfileUI] loadProfileLocalOnly(): local cache MISS -> resetting UI state',
      );
      // IMPORTANT: Clear any stale in-memory profile from a previous user.
      // This situation happens after logout + re-login with a different number:
      // - SQLite DB was deleted and recreated (no local profile rows yet)
      // - But ProfileUINotifier still holds the old user's profile in memory
      // Resetting the state ensures Profile Info starts blank for the new user
      // instead of showing the previous user's data until app restart.
      _safeSetState(const ProfileUIState());
    }
  }

  /// Refresh profile from server (pull-to-refresh)
  Future<void> refreshProfile() async {
    if (state.isRefreshing) return;
    _log('[ProfileUI] refreshProfile(): start');

    _safeSetState(state.copyWith(loadingState: ProfileLoadingState.refreshing));

    final result = await _profileRepository.getCurrentUserProfile();

    if (result.isSuccess && result.data?.data != null) {
      _log(
        '[ProfileUI] refreshProfile(): server SUCCESS -> UI updated; repo saved to local',
      );
      _log(
        '[ProfileUI] refreshProfile(): UI <- server name=${result.data!.data!.firstName ?? ''}',
      );
      _safeSetState(
        state.copyWith(
          loadingState: ProfileLoadingState.loaded,
          profile: result.data!.data,
          errorMessage: null,
        ),
      );
    } else {
      _log(
        '[ProfileUI] refreshProfile(): server FAIL -> keep existing UI; error: \\${result.errorMessage}',
      );
      // Keep existing data, just show error
      _safeSetState(
        state.copyWith(
          loadingState: ProfileLoadingState.loaded,
          errorMessage: result.errorMessage ?? 'Failed to refresh profile',
        ),
      );
    }
  }

  // =============================
  // Server Sync Helpers
  // =============================
  // Note: Backend sync removed - handled by repositories

  // =============================
  // Status Selection UI Helpers
  // =============================

  void selectPredefinedStatusUI(String status) {
    _safeSetState(
      state.copyWith(
        selectedStatus: status,
        isCustomStatus: false,
        customStatusText: '',
        characterCount: status.characters.length,
      ),
    );
  }

  void enableCustomStatusUI() {
    _safeSetState(
      state.copyWith(
        selectedStatus: null,
        isCustomStatus: true,
        customStatusText: '',
        characterCount: 0,
      ),
    );
  }

  void updateCustomStatusTextUI(String text) {
    if (state.isCustomStatus) {
      _safeSetState(
        state.copyWith(
          customStatusText: text,
          characterCount: text.characters.length,
        ),
      );
    }
  }

  void clearStatusSelectionUI() {
    _safeSetState(
      state.copyWith(
        selectedStatus: null,
        isCustomStatus: false,
        customStatusText: '',
        characterCount: 0,
      ),
    );
  }

  // =============================
  // Profile Update Actions
  // =============================

  Future<bool> updateName(String newName) async {
    if (_currentUpdatingName == newName) return true;
    if ((state.profile?.firstName ?? '') == newName) return true;

    final optimistic = (state.profile ?? CurrentUserProfileModel()).copyWith(
      firstName: newName,
    );
    _log('[ProfileUI] updateName(): optimistic UI update -> $newName');
    _safeSetState(
      state.copyWith(
        profile: optimistic,
        loadingState: ProfileLoadingState.loaded,
        errorMessage: null,
      ),
    );

    _currentUpdatingName = newName;
    try {
      _log('[ProfileUI] updateName(): sending to server');
      final result = await _profileRepository.updateName(newName, null);
      if (result.isSuccess && result.data?.data != null) {
        _log('[ProfileUI] updateName(): server SUCCESS -> UI reconcile');
        final serverName = result.data!.data!.firstName ?? '';
        _log('[ProfileUI] updateName(): server returned name=$serverName');
        final merged = (result.data!.data!).copyWith(firstName: newName);
        if (serverName.trim() != newName.trim()) {
          _log(
            '[ProfileUI] updateName(): server name mismatch -> keeping requested name',
          );
        }
        _safeSetState(state.copyWith(profile: merged, errorMessage: null));
      } else {
        _log(
          '[ProfileUI] updateName(): server FAIL -> keep optimistic/local; error: \\${result.errorMessage}',
        );
        _safeSetState(
          state.copyWith(
            errorMessage: result.errorMessage ?? 'Failed to update name',
          ),
        );
      }
    } catch (_) {
      _log(
        '[ProfileUI] updateName(): offline or error -> saved locally, will sync later',
      );
      _safeSetState(
        state.copyWith(errorMessage: 'Name saved locally, will sync later'),
      );
    } finally {
      if (_currentUpdatingName == newName) _currentUpdatingName = null;
    }
    return true;
  }

  Future<bool> updateStatus(String newStatus) async {
    if (_currentUpdatingStatus == newStatus) return true;
    if ((state.profile?.content ?? '') == newStatus) return true;

    final optimistic = (state.profile ?? CurrentUserProfileModel()).copyWith(
      content: newStatus,
    );
    _log('[ProfileUI] updateStatus(): optimistic UI update -> $newStatus');
    _safeSetState(
      state.copyWith(
        profile: optimistic,
        loadingState: ProfileLoadingState.loaded,
        errorMessage: null,
      ),
    );

    _currentUpdatingStatus = newStatus;
    try {
      _log('[ProfileUI] updateStatus(): sending to server');
      final result = await _profileRepository.updateStatus(newStatus);
      if (result.isSuccess && result.data?.data != null) {
        _log('[ProfileUI] updateStatus(): server SUCCESS -> UI reconcile');
        final serverStatus = result.data!.data!.content ?? '';
        _log(
          '[ProfileUI] updateStatus(): server returned status=$serverStatus',
        );
        if (serverStatus.trim() != newStatus.trim()) {
          _log(
            '[ProfileUI] updateStatus(): server status mismatch -> keeping requested status',
          );
          final merged = (result.data!.data!).copyWith(content: newStatus);
          _safeSetState(state.copyWith(profile: merged, errorMessage: null));
        } else {
          _safeSetState(
            state.copyWith(profile: result.data!.data, errorMessage: null),
          );
        }
      } else {
        _log(
          '[ProfileUI] updateStatus(): server FAIL -> keep optimistic/local; error: \\${result.errorMessage}',
        );
        _safeSetState(
          state.copyWith(
            errorMessage: result.errorMessage ?? 'Failed to update status',
          ),
        );
      }
    } catch (_) {
      _log(
        '[ProfileUI] updateStatus(): offline or error -> saved locally, will sync later',
      );
      _safeSetState(
        state.copyWith(errorMessage: 'Status saved locally, will sync later'),
      );
    } finally {
      if (_currentUpdatingStatus == newStatus) _currentUpdatingStatus = null;
    }
    return true;
  }

  Future<bool> updateProfilePicture(String imagePath) async {
    if (_currentUploadingPath == imagePath) return true;
    if (state.profile?.profilePic == imagePath) return true;

    _safeSetState(
      state.copyWith(
        loadingState: ProfileLoadingState.loaded,
        isUploading: true,
        errorMessage: null,
      ),
    );

    _currentUploadingPath = imagePath;
    try {
      _log(
        '[ProfileUI] updateProfilePicture(): sending to server -> $imagePath',
      );
      final result = await _profileRepository.updateProfilePicture(imagePath);
      if (result.isSuccess && result.data?.data != null) {
        _log(
          '[ProfileUI] updateProfilePicture(): server SUCCESS -> UI reconcile',
        );
        _log(
          '[ProfileUI] updateProfilePicture(): server returned chatPicture=${result.data!.data!.profilePic ?? ''}',
        );
        _safeSetState(
          state.copyWith(profile: result.data!.data, errorMessage: null),
        );
      } else {
        _log(
          '[ProfileUI] updateProfilePicture(): server FAIL -> keep current UI; error: \\${result.errorMessage}',
        );
        _safeSetState(
          state.copyWith(
            errorMessage: result.errorMessage ?? 'Failed to update picture',
          ),
        );
      }
    } catch (_) {
      _log(
        '[ProfileUI] updateProfilePicture(): offline or error -> will retry later',
      );
      _safeSetState(
        state.copyWith(errorMessage: 'Photo saved locally, will sync later'),
      );
    } finally {
      if (_currentUploadingPath == imagePath) _currentUploadingPath = null;
      _safeSetState(state.copyWith(isUploading: false));
    }
    return true;
  }

  Future<bool> deleteProfilePicture() async {
    _safeSetState(state.copyWith(isUploading: true));
    final original = state.profile;
    try {
      final updatedLocal = state.profile?.copyWithNullProfilePic();
      _safeSetState(state.copyWith(profile: updatedLocal));
      _log('[ProfileUI] deleteProfilePicture(): sending to server');
      final result = await _profileRepository.deleteProfilePicture();
      if (result.isSuccess) {
        // keep pic null using explicit null setter
        final merged = (state.profile ?? CurrentUserProfileModel())
            .copyWithNullProfilePic();
        _safeSetState(state.copyWith(profile: merged, errorMessage: null));
        _log(
          '[ProfileUI] deleteProfilePicture(): server SUCCESS -> local DB updated',
        );
        final localAfter = await _profileRepository.getLocalProfile();
        _log(
          '[ProfileUI] verify chatPicture from local DB after delete: ${localAfter?.profilePic ?? 'null'}',
        );
        return true;
      } else {
        _safeSetState(
          state.copyWith(
            profile: original,
            errorMessage: 'Failed to delete profile picture',
          ),
        );
        return false;
      }
    } catch (e) {
      _safeSetState(
        state.copyWith(profile: original, errorMessage: e.toString()),
      );
      return false;
    } finally {
      _safeSetState(state.copyWith(isUploading: false));
    }
  }

  // =============================
  // Emoji Management
  // =============================

  Future<bool> addEmoji(String path) async {
    if (path.isEmpty) return false;
    if (!state.canAddMoreEmojis) {
      _safeSetState(state.copyWith(errorMessage: 'Maximum 10 emojis allowed'));
      return false;
    }
    if (state.emojis.contains(path)) return true;
    final list = [...state.emojis, path];
    _safeSetState(state.copyWith(emojis: list, errorMessage: null));
    return true;
  }

  Future<bool> removeEmoji(String path) async {
    if (!state.emojis.contains(path)) return true;
    final list = [...state.emojis]..remove(path);
    _safeSetState(state.copyWith(emojis: list, errorMessage: null));
    return true;
  }

  Future<bool> reorderEmojis(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= state.emojis.length) return false;
    if (newIndex < 0 || newIndex > state.emojis.length) return false;
    final list = [...state.emojis];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, item);
    _safeSetState(state.copyWith(emojis: list, errorMessage: null));
    return true;
  }

  // =============================
  // Utility Methods
  // =============================

  void clearError() => _safeSetState(state.copyWith(errorMessage: null));

  void reset() => _safeSetState(const ProfileUIState());

  /// Populate UI from backend snapshot (no API call) — avoid fake IDs
  void populateFromBackendData({
    String? firstName,
    String? statusContent,
    String? chatPictureUrl,
    String? phoneNumber,
  }) {
    final newProfile = CurrentUserProfileModel(
      firstName: firstName ?? '',
      lastName: '',
      mobileNo: phoneNumber ?? '',
      profilePic: chatPictureUrl,
      isVerified: 1,
      content: statusContent ?? '',
    );
    _safeSetState(
      state.copyWith(
        profile: newProfile,
        loadingState: ProfileLoadingState.loaded,
        errorMessage: null,
      ),
    );
  }
}
