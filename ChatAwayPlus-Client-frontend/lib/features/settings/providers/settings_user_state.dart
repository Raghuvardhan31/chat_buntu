import 'package:chataway_plus/features/profile/data/models/current_user_profile_model.dart';

class SettingsUserState {
  final bool isLoading;
  final bool hasLoaded;
  final String? errorMessage;
  final CurrentUserProfileModel? profile;

  const SettingsUserState({
    this.isLoading = false,
    this.hasLoaded = false,
    this.errorMessage,
    this.profile,
  });

  SettingsUserState copyWith({
    bool? isLoading,
    bool? hasLoaded,
    String? errorMessage,
    CurrentUserProfileModel? profile,
  }) {
    return SettingsUserState(
      isLoading: isLoading ?? this.isLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      errorMessage: errorMessage ?? this.errorMessage,
      profile: profile ?? this.profile,
    );
  }

  SettingsUserState clearError() {
    return SettingsUserState(
      isLoading: isLoading,
      hasLoaded: hasLoaded,
      profile: profile,
    );
  }
}
