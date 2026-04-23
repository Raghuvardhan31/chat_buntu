// lib/features/profile/presentation/providers/profile_page_state.dart

import 'package:chataway_plus/features/profile/data/models/current_user_profile_model.dart';

// =============================
// Loading State Enum
// =============================

enum ProfileLoadingState { initial, loading, loaded, error, refreshing }

// =============================
// Profile UI State
// =============================

/// Sentinel used by [ProfileUIState.copyWith] to distinguish between
/// "parameter not provided" (keep old value) and "explicitly set to null".
const Object _sentinel = Object();

class ProfileUIState {
  final ProfileLoadingState loadingState;
  final CurrentUserProfileModel? profile;
  final String? errorMessage;
  final bool hasEverLoaded;
  final bool isEditing;
  final bool isUploading;
  final bool showShimmer;
  final List<String> emojis;

  // Status selection fields
  final String? selectedStatus;
  final bool isCustomStatus;
  final String customStatusText;
  final int characterCount;

  const ProfileUIState({
    this.loadingState = ProfileLoadingState.initial,
    this.profile,
    this.errorMessage,
    this.hasEverLoaded = false,
    this.isEditing = false,
    this.isUploading = false,
    this.showShimmer = false,
    this.emojis = const [],
    this.selectedStatus,
    this.isCustomStatus = false,
    this.customStatusText = '',
    this.characterCount = 0,
  });

  ProfileUIState copyWith({
    ProfileLoadingState? loadingState,
    CurrentUserProfileModel? profile,
    Object? errorMessage = _sentinel,
    bool? hasEverLoaded,
    bool? isEditing,
    bool? isUploading,
    bool? showShimmer,
    Object? selectedStatus = _sentinel,
    bool? isCustomStatus,
    String? customStatusText,
    int? characterCount,
    List<String>? emojis,
  }) {
    return ProfileUIState(
      loadingState: loadingState ?? this.loadingState,
      profile: profile ?? this.profile,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
      hasEverLoaded: hasEverLoaded ?? this.hasEverLoaded,
      isEditing: isEditing ?? this.isEditing,
      isUploading: isUploading ?? this.isUploading,
      showShimmer: showShimmer ?? this.showShimmer,
      selectedStatus: identical(selectedStatus, _sentinel)
          ? this.selectedStatus
          : selectedStatus as String?,
      isCustomStatus: isCustomStatus ?? this.isCustomStatus,
      customStatusText: customStatusText ?? this.customStatusText,
      characterCount: characterCount ?? this.characterCount,
      emojis: emojis ?? this.emojis,
    );
  }

  bool get isLoading => loadingState == ProfileLoadingState.loading;
  bool get isLoaded => loadingState == ProfileLoadingState.loaded;
  bool get hasError => loadingState == ProfileLoadingState.error;
  bool get isRefreshing => loadingState == ProfileLoadingState.refreshing;
  bool get isInitial => loadingState == ProfileLoadingState.initial;

  static const String _statusPlaceholder =
      'Write custom or tap to choose preset';

  bool get isProfileComplete {
    if (profile == null) return false;
    final name = profile!.firstName?.trim() ?? '';
    final status = profile!.content?.trim() ?? '';
    return name.isNotEmpty && status.isNotEmpty && status != _statusPlaceholder;
  }

  String get displayName => profile?.firstName ?? '';
  String get displayStatus => profile?.content ?? '';
  String get displayMobileNumber =>
      profile?.mobileNo?.isNotEmpty == true ? profile!.mobileNo! : '';
  String? get profilePictureUrl => profile?.profilePic;

  String get finalStatusText =>
      isCustomStatus ? customStatusText : (selectedStatus ?? '');
  bool get hasValidStatus =>
      finalStatusText.isNotEmpty && finalStatusText.length <= 85;
  bool get canAddMoreEmojis => emojis.length < 10;
}

// =============================
// Profile Editing State
// =============================

class ProfileEditingState {
  final bool isEditingName;
  final bool isEditingStatus;
  final bool isUploadingPicture;
  final bool isDeletingPicture;
  final String? editingError;
  final String? uploadProgress;

  const ProfileEditingState({
    this.isEditingName = false,
    this.isEditingStatus = false,
    this.isUploadingPicture = false,
    this.isDeletingPicture = false,
    this.editingError,
    this.uploadProgress,
  });

  ProfileEditingState copyWith({
    bool? isEditingName,
    bool? isEditingStatus,
    bool? isUploadingPicture,
    bool? isDeletingPicture,
    String? editingError,
    String? uploadProgress,
  }) {
    return ProfileEditingState(
      isEditingName: isEditingName ?? this.isEditingName,
      isEditingStatus: isEditingStatus ?? this.isEditingStatus,
      isUploadingPicture: isUploadingPicture ?? this.isUploadingPicture,
      isDeletingPicture: isDeletingPicture ?? this.isDeletingPicture,
      editingError: editingError ?? this.editingError,
      uploadProgress: uploadProgress ?? this.uploadProgress,
    );
  }

  bool get isPerformingAnyAction =>
      isEditingName ||
      isEditingStatus ||
      isUploadingPicture ||
      isDeletingPicture;
  bool get hasError => editingError != null;
}
