// lib/features/profile/presentation/providers/profile_page_providers.dart

import 'package:chataway_plus/features/profile/data/models/current_user_profile_model.dart';
import 'package:chataway_plus/features/profile/data/datasources/profile_local_datasource.dart';
import 'package:chataway_plus/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:chataway_plus/features/profile/data/repositories/profile/profile_repository.dart';
import 'package:chataway_plus/features/profile/data/repositories/profile/profile_repository_impl.dart';
import 'package:chataway_plus/features/profile/data/repositories/profile/helper_repos/get_profile_repository.dart';
import 'package:chataway_plus/features/profile/data/repositories/profile/helper_repos/update_name_repository.dart';
import 'package:chataway_plus/features/profile/data/repositories/profile/helper_repos/update_status_repository.dart';
import 'package:chataway_plus/features/profile/data/repositories/profile/helper_repos/update_profile_picture_repository.dart';
import 'package:chataway_plus/features/profile/data/repositories/profile/helper_repos/delete_profile_picture_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:chataway_plus/core/storage/token_storage.dart';
import 'package:chataway_plus/core/constants/api_url/api_urls.dart';
import 'profile_page_state.dart';
import 'profile_page_notifier.dart';

// =============================
// Data Source Providers
// =============================

final profileLocalDataSourceProvider = Provider<ProfileLocalDataSource>((ref) {
  return ProfileLocalDataSourceImpl();
});

final profileRemoteDataSourceProvider = Provider<ProfileRemoteDataSource>((
  ref,
) {
  return ProfileRemoteDataSourceImpl(
    httpClient: http.Client(),
    tokenStorage: TokenSecureStorage.instance,
  );
});

// =============================
// Repository Providers
// =============================

final getProfileRepositoryProvider = Provider<GetProfileRepository>((ref) {
  return GetProfileRepository(
    remoteDataSource: ref.watch(profileRemoteDataSourceProvider),
    localDataSource: ref.watch(profileLocalDataSourceProvider),
  );
});

final updateNameRepositoryProvider = Provider<UpdateNameRepository>((ref) {
  return UpdateNameRepository(
    remoteDataSource: ref.watch(profileRemoteDataSourceProvider),
    localDataSource: ref.watch(profileLocalDataSourceProvider),
  );
});

final updateStatusRepositoryProvider = Provider<UpdateStatusRepository>((ref) {
  return UpdateStatusRepository(
    remoteDataSource: ref.watch(profileRemoteDataSourceProvider),
    localDataSource: ref.watch(profileLocalDataSourceProvider),
  );
});

final updateProfilePictureRepositoryProvider =
    Provider<UpdateProfilePictureRepository>((ref) {
      return UpdateProfilePictureRepository(
        remoteDataSource: ref.watch(profileRemoteDataSourceProvider),
        localDataSource: ref.watch(profileLocalDataSourceProvider),
      );
    });

final deleteProfilePictureRepositoryProvider =
    Provider<DeleteProfilePictureRepository>((ref) {
      return DeleteProfilePictureRepository(
        remoteDataSource: ref.watch(profileRemoteDataSourceProvider),
        localDataSource: ref.watch(profileLocalDataSourceProvider),
      );
    });

// Main Profile Repository Provider
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepositoryImpl(
    getProfileRepo: ref.watch(getProfileRepositoryProvider),
    updateNameRepo: ref.watch(updateNameRepositoryProvider),
    updateStatusRepo: ref.watch(updateStatusRepositoryProvider),
    updateProfilePictureRepo: ref.watch(updateProfilePictureRepositoryProvider),
    deleteProfilePictureRepo: ref.watch(deleteProfilePictureRepositoryProvider),
    localDataSource: ref.watch(profileLocalDataSourceProvider),
  );
});

// =============================
// Main Profile UI Provider
// =============================

final profileUIProvider =
    StateNotifierProvider<ProfileUINotifier, ProfileUIState>((ref) {
      return ProfileUINotifier(ref.watch(profileRepositoryProvider));
    });

// =============================
// State Selectors
// =============================

final profileLoadingStateProvider = Provider<ProfileLoadingState>((ref) {
  return ref.watch(profileUIProvider.select((s) => s.loadingState));
});

final profileDataProvider = Provider<CurrentUserProfileModel?>((ref) {
  return ref.watch(profileUIProvider.select((s) => s.profile));
});

final profileDisplayNameProvider = Provider<String>((ref) {
  return ref.watch(profileUIProvider.select((s) => s.displayName));
});

final profileDisplayStatusProvider = Provider<String>((ref) {
  return ref.watch(profileUIProvider.select((s) => s.displayStatus));
});

final tokenStorageMobileNumberProvider = FutureProvider<String>((ref) async {
  try {
    final tokenStorage = TokenSecureStorage.instance;
    final phoneNumber = await tokenStorage.getPhoneNumber();
    return phoneNumber ?? '';
  } catch (_) {
    return '';
  }
});

final profileDisplayMobileNumberProvider = Provider<String>((ref) {
  final profileMobile = ref.watch(
    profileUIProvider.select((s) => s.displayMobileNumber),
  );
  if (profileMobile.isNotEmpty) return profileMobile;
  final tokenMobileAsync = ref.watch(tokenStorageMobileNumberProvider);
  return tokenMobileAsync.when(
    data: (v) => v,
    loading: () => '',
    error: (_, __) => '',
  );
});

final profilePictureUrlProvider = Provider<String?>((ref) {
  final raw = ref.watch(profileUIProvider.select((s) => s.profilePictureUrl));
  final version = ref.watch(
    profileUIProvider.select((s) => s.profile?.chatPictureVersion),
  );
  if (raw == null || raw.isEmpty) return null;

  final baseUrl = raw.startsWith('http') ? raw : '${ApiUrls.mediaBaseUrl}$raw';
  final v = version?.trim() ?? '';
  if (v.isEmpty) return baseUrl;

  try {
    final uri = Uri.parse(baseUrl);
    final params = Map<String, String>.from(uri.queryParameters);
    params['v'] = v;
    return uri.replace(queryParameters: params).toString();
  } catch (_) {
    final sep = baseUrl.contains('?') ? '&' : '?';
    return '$baseUrl${sep}v=$v';
  }
});

final isProfileCompleteProvider = Provider<bool>((ref) {
  return ref.watch(profileUIProvider.select((s) => s.isProfileComplete));
});

final showShimmerProvider = Provider<bool>((ref) {
  return ref.watch(profileUIProvider.select((s) => s.showShimmer));
});

final profileErrorProvider = Provider<String?>((ref) {
  return ref.watch(profileUIProvider.select((s) => s.errorMessage));
});

final isEditingProvider = Provider<bool>((ref) {
  return ref.watch(profileUIProvider.select((s) => s.isEditing));
});

final isUploadingProvider = Provider<bool>((ref) {
  return ref.watch(profileUIProvider.select((s) => s.isUploading));
});

// =============================
// Emoji Providers
// =============================

final emojisProvider = Provider<List<String>>((ref) {
  return ref.watch(profileUIProvider.select((s) => s.emojis));
});

final canAddMoreEmojisProvider = Provider<bool>((ref) {
  return ref.watch(profileUIProvider.select((s) => s.canAddMoreEmojis));
});

// =============================
// Status Selection Providers
// =============================

final predefinedStatusesProvider = Provider<List<String>>((ref) {
  return [
    "Sharing moments on ChatAway+",
    "ChatAway+ is my voice",
    "Only available on ChatAway+",
    "Currently busy",
    "Phone on silent",
    "Delay leads to regret",
    "Any dream that has your tears - you must achieve it",
    "Sometimes your courage brings tears - but that doesn't mean you are weak",
    "Karma comes like an elder walks, but strikes you like a warrior",
    "Success seekers see two suns in a day",
    "Consistency gives you wings to your destination",
    "Fear has no children - just defeat it",
    "Nature is the biggest refresh button in human lives",
    "Don't forget to add people to your favourite list",
    "Sometimes time stops at joy and pain, but remember it moves eventually",
    "You never graduate from world school",
  ];
});

final selectedStatusProvider = Provider<String?>((ref) {
  return ref.watch(profileUIProvider.select((s) => s.selectedStatus));
});

final isCustomStatusProvider = Provider<bool>((ref) {
  return ref.watch(profileUIProvider.select((s) => s.isCustomStatus));
});

final customStatusTextProvider = Provider<String>((ref) {
  return ref.watch(profileUIProvider.select((s) => s.customStatusText));
});

final statusCharacterCountProvider = Provider<int>((ref) {
  return ref.watch(profileUIProvider.select((s) => s.characterCount));
});

final finalStatusTextProvider = Provider<String>((ref) {
  return ref.watch(profileUIProvider.select((s) => s.finalStatusText));
});

final hasValidStatusProvider = Provider<bool>((ref) {
  return ref.watch(profileUIProvider.select((s) => s.hasValidStatus));
});

// =============================
// Action Providers
// =============================

/// Load profile with offline-first approach
final loadProfileActionProvider = Provider<Future<void> Function()>((ref) {
  return () => ref.read(profileUIProvider.notifier).loadProfile();
});

/// Load profile only from local DB (no network) — for initial page visit
final loadProfileLocalOnlyActionProvider = Provider<Future<void> Function()>((
  ref,
) {
  return () => ref.read(profileUIProvider.notifier).loadProfileLocalOnly();
});

/// Refresh profile from server (pull-to-refresh)
final refreshProfileActionProvider = Provider<Future<void> Function()>((ref) {
  return () => ref.read(profileUIProvider.notifier).refreshProfile();
});

final updateNameActionProvider = Provider<Future<bool> Function(String)>((ref) {
  return (String newName) =>
      ref.read(profileUIProvider.notifier).updateName(newName);
});

final updateStatusActionProvider = Provider<Future<bool> Function(String)>((
  ref,
) {
  return (String newStatus) =>
      ref.read(profileUIProvider.notifier).updateStatus(newStatus);
});

final updateProfilePictureActionProvider =
    Provider<Future<bool> Function(String)>((ref) {
      return (String imagePath) =>
          ref.read(profileUIProvider.notifier).updateProfilePicture(imagePath);
    });

final deleteProfilePictureActionProvider = Provider<Future<bool> Function()>((
  ref,
) {
  return () => ref.read(profileUIProvider.notifier).deleteProfilePicture();
});

// =============================
// Emoji Action Providers
// =============================

final addEmojiActionProvider = Provider<Future<bool> Function(String)>((ref) {
  return (String imagePath) =>
      ref.read(profileUIProvider.notifier).addEmoji(imagePath);
});

final removeEmojiActionProvider = Provider<Future<bool> Function(String)>((
  ref,
) {
  return (String imagePath) =>
      ref.read(profileUIProvider.notifier).removeEmoji(imagePath);
});

final reorderEmojisActionProvider = Provider<Future<bool> Function(int, int)>((
  ref,
) {
  return (int oldIndex, int newIndex) =>
      ref.read(profileUIProvider.notifier).reorderEmojis(oldIndex, newIndex);
});

// =============================
// Utility Action Providers
// =============================

final clearErrorActionProvider = Provider<void Function()>((ref) {
  return () => ref.read(profileUIProvider.notifier).clearError();
});

final selectPredefinedStatusUIActionProvider = Provider<void Function(String)>((
  ref,
) {
  return (String status) =>
      ref.read(profileUIProvider.notifier).selectPredefinedStatusUI(status);
});

final enableCustomStatusUIActionProvider = Provider<void Function()>((ref) {
  return () => ref.read(profileUIProvider.notifier).enableCustomStatusUI();
});

final updateCustomStatusTextUIActionProvider = Provider<void Function(String)>((
  ref,
) {
  return (String text) =>
      ref.read(profileUIProvider.notifier).updateCustomStatusTextUI(text);
});

final clearStatusSelectionUIActionProvider = Provider<void Function()>((ref) {
  return () => ref.read(profileUIProvider.notifier).clearStatusSelectionUI();
});
