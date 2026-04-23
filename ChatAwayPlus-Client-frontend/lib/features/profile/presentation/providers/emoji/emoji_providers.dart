// lib/features/profile/presentation/providers/emoji/emoji_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:chataway_plus/core/storage/token_storage.dart';

import '../../../data/datasources/emoji_local_datasource.dart';
import '../../../data/datasources/emoji_remote_datasource.dart';
import '../../../data/repositories/emoji/emoji_repository.dart';
import '../../../data/repositories/emoji/emoji_repository_impl.dart';
import '../../../data/repositories/emoji/helper_repos/get_emoji_repository.dart';
import '../../../data/repositories/emoji/helper_repos/create_emoji_repository.dart';
import '../../../data/repositories/emoji/helper_repos/update_emoji_repository.dart';
import '../../../data/repositories/emoji/helper_repos/delete_emoji_repository.dart';
import 'emoji_notifier.dart';
import 'emoji_state.dart';

// =============================
// HTTP Client Provider
// =============================

final httpClientProvider = Provider<http.Client>((ref) {
  return http.Client();
});

// =============================
// Token Storage Provider
// =============================

final tokenStorageProvider = Provider<TokenSecureStorage>((ref) {
  return TokenSecureStorage.instance;
});

// =============================
// Data Source Providers
// =============================

/// Emoji Local DataSource Provider
final emojiLocalDataSourceProvider = Provider<EmojiLocalDataSource>((ref) {
  return EmojiLocalDataSourceImpl();
});

/// Emoji Remote DataSource Provider
final emojiRemoteDataSourceProvider = Provider<EmojiRemoteDataSource>((ref) {
  return EmojiRemoteDataSourceImpl(
    httpClient: ref.watch(httpClientProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});

// =============================
// Repository Providers
// =============================

/// Get Emoji Repository Provider
final getEmojiRepositoryProvider = Provider<GetEmojiRepository>((ref) {
  return GetEmojiRepository(
    remoteDataSource: ref.watch(emojiRemoteDataSourceProvider),
    localDataSource: ref.watch(emojiLocalDataSourceProvider),
  );
});

/// Create Emoji Repository Provider
final createEmojiRepositoryProvider = Provider<CreateEmojiRepository>((ref) {
  return CreateEmojiRepository(
    remoteDataSource: ref.watch(emojiRemoteDataSourceProvider),
    localDataSource: ref.watch(emojiLocalDataSourceProvider),
  );
});

/// Update Emoji Repository Provider
final updateEmojiRepositoryProvider = Provider<UpdateEmojiRepository>((ref) {
  return UpdateEmojiRepository(
    remoteDataSource: ref.watch(emojiRemoteDataSourceProvider),
    localDataSource: ref.watch(emojiLocalDataSourceProvider),
  );
});

/// Delete Emoji Repository Provider
final deleteEmojiRepositoryProvider = Provider<DeleteEmojiRepository>((ref) {
  return DeleteEmojiRepository(
    remoteDataSource: ref.watch(emojiRemoteDataSourceProvider),
    localDataSource: ref.watch(emojiLocalDataSourceProvider),
  );
});

/// Main Emoji Repository Provider
final emojiRepositoryProvider = Provider<EmojiRepository>((ref) {
  return EmojiRepositoryImpl(
    getEmojiRepo: ref.watch(getEmojiRepositoryProvider),
    createEmojiRepo: ref.watch(createEmojiRepositoryProvider),
    updateEmojiRepo: ref.watch(updateEmojiRepositoryProvider),
    deleteEmojiRepo: ref.watch(deleteEmojiRepositoryProvider),
    localDataSource: ref.watch(emojiLocalDataSourceProvider),
  );
});

// =============================
// Emoji State Provider
// =============================

/// Emoji UI State Notifier Provider
final emojiNotifierProvider =
    StateNotifierProvider<EmojiNotifier, EmojiUIState>((ref) {
      return EmojiNotifier(ref.watch(emojiRepositoryProvider));
    });

// =============================
// Convenience Providers
// =============================

/// Current Emoji Provider
final currentEmojiProvider = Provider((ref) {
  return ref.watch(emojiNotifierProvider).emoji;
});

/// Emoji Loading State Provider
final emojiLoadingStateProvider = Provider((ref) {
  return ref.watch(emojiNotifierProvider).loadingState;
});

/// Has Emoji Provider
final hasEmojiProvider = Provider((ref) {
  return ref.watch(emojiNotifierProvider).hasEmoji;
});

/// Is Editing Emoji Provider
final isEditingEmojiProvider = Provider((ref) {
  return ref.watch(emojiNotifierProvider).isEditing;
});

/// Is Processing Emoji Provider
final isProcessingEmojiProvider = Provider((ref) {
  return ref.watch(emojiNotifierProvider).isProcessing;
});

/// Emoji Error Message Provider
final emojiErrorMessageProvider = Provider((ref) {
  return ref.watch(emojiNotifierProvider).errorMessage;
});

/// Can Save Emoji Provider
final canSaveEmojiProvider = Provider((ref) {
  return ref.watch(emojiNotifierProvider).canSave;
});

/// Has Emoji Changes Provider
final hasEmojiChangesProvider = Provider((ref) {
  return ref.watch(emojiNotifierProvider).hasChanges;
});
