// lib/features/voice_hub/presentation/providers/emoji_updates/emoji_updates_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasources/emoji_updates_remote_datasource.dart';
import '../../../data/datasources/emoji_updates_local_datasource.dart';
import '../../../data/repositories/emoji_updates_repository.dart';
import '../../../data/models/emoji_update_model.dart';
import 'emoji_updates_state.dart';
import 'emoji_updates_notifier.dart';

/// Provider for emoji updates remote datasource
final emojiUpdatesRemoteDataSourceProvider =
    Provider<EmojiUpdatesRemoteDataSource>((ref) {
  return EmojiUpdatesRemoteDataSourceImpl();
});

/// Provider for emoji updates local datasource
final emojiUpdatesLocalDataSourceProvider =
    Provider<EmojiUpdatesLocalDataSource>((ref) {
  return EmojiUpdatesLocalDataSourceImpl();
});

/// Provider for emoji updates repository
final emojiUpdatesRepositoryProvider = Provider<EmojiUpdatesRepository>((ref) {
  return EmojiUpdatesRepository(
    remoteDataSource: ref.watch(emojiUpdatesRemoteDataSourceProvider),
    localDataSource: ref.watch(emojiUpdatesLocalDataSourceProvider),
  );
});

/// Provider for emoji updates notifier
final emojiUpdatesNotifierProvider =
    StateNotifierProvider<EmojiUpdatesNotifier, EmojiUpdatesState>((ref) {
  return EmojiUpdatesNotifier(
    repository: ref.watch(emojiUpdatesRepositoryProvider),
  );
});

/// Convenient provider to get emoji list
final emojiUpdatesListProvider = Provider<List<EmojiUpdateModel>>((ref) {
  return ref.watch(emojiUpdatesNotifierProvider).emojiList;
});

/// Convenient provider to check if loading
final emojiUpdatesLoadingProvider = Provider<bool>((ref) {
  return ref.watch(emojiUpdatesNotifierProvider).isLoading;
});

/// Convenient provider to get error message
final emojiUpdatesErrorProvider = Provider<String?>((ref) {
  return ref.watch(emojiUpdatesNotifierProvider).errorMessage;
});
