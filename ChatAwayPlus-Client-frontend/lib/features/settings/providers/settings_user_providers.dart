import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/features/profile/data/datasources/profile_local_datasource.dart';
import 'package:chataway_plus/core/constants/api_url/api_urls.dart';

import 'settings_user_state.dart';
import 'settings_user_notifier.dart';

final settingsProfileLocalDataSourceProvider = Provider<ProfileLocalDataSource>(
  (ref) {
    return ProfileLocalDataSourceImpl();
  },
);

final settingsUserNotifierProvider =
    StateNotifierProvider<SettingsUserNotifier, SettingsUserState>((ref) {
      final localDs = ref.watch(settingsProfileLocalDataSourceProvider);
      return SettingsUserNotifier(localDs);
    });

final settingsUserAvatarUrlProvider = Provider<String?>((ref) {
  final profilePic = ref.watch(
    settingsUserNotifierProvider.select((s) => s.profile?.profilePic),
  );
  if (profilePic == null || profilePic.isEmpty) return null;
  if (profilePic.startsWith('http')) return profilePic;
  return '${ApiUrls.mediaBaseUrl}$profilePic';
});
