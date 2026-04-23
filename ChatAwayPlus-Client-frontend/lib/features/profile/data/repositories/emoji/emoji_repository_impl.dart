// lib/features/profile/data/repositories/emoji/emoji_repository_impl.dart

import '../../models/emoji_model.dart';
import '../../models/responses/emoji_response_models.dart';
import '../../models/responses/emoji_result.dart';
import '../../datasources/emoji_local_datasource.dart';
import 'emoji_repository.dart';
import 'helper_repos/get_emoji_repository.dart';
import 'helper_repos/create_emoji_repository.dart';
import 'helper_repos/update_emoji_repository.dart';
import 'helper_repos/delete_emoji_repository.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';

/// Implementation of [EmojiRepository]
/// Delegates to specific repository implementations
class EmojiRepositoryImpl implements EmojiRepository {
  final GetEmojiRepository getEmojiRepo;
  final CreateEmojiRepository createEmojiRepo;
  final UpdateEmojiRepository updateEmojiRepo;
  final DeleteEmojiRepository deleteEmojiRepo;
  final EmojiLocalDataSource localDataSource;

  EmojiRepositoryImpl({
    required this.getEmojiRepo,
    required this.createEmojiRepo,
    required this.updateEmojiRepo,
    required this.deleteEmojiRepo,
    required this.localDataSource,
  });

  @override
  Future<EmojiResult<GetEmojiResponseModel>> getCurrentEmoji() =>
      getEmojiRepo.getCurrentEmoji();

  @override
  Future<EmojiResult<EmojiUpdateResponseModel>> createEmoji(
    String emoji,
    String caption,
  ) => createEmojiRepo.createEmoji(emoji, caption);

  @override
  Future<EmojiResult<EmojiUpdateResponseModel>> updateEmoji(
    String id,
    String emoji,
    String caption,
  ) => updateEmojiRepo.updateEmoji(id, emoji, caption);

  @override
  Future<EmojiResult<DeleteEmojiResponseModel>> deleteEmoji(
    String id,
    String emoji,
    String caption,
  ) => deleteEmojiRepo.deleteEmoji(id, emoji, caption);

  @override
  Future<void> clearEmoji() async {
    await localDataSource.clearEmoji();
  }

  @override
  Future<EmojiModel?> getLocalEmoji() async {
    try {
      // Prefer the current user's emoji from the shared emoji_updates table
      final currentUserId = await TokenSecureStorage.instance
          .getCurrentUserIdUUID();

      // Load all cached emojis (most recent first via local datasource ordering)
      final all = await localDataSource.getAllEmojis();

      if (all.isEmpty) {
        // Fallback to legacy single-row read (may return null)
        return await localDataSource.getEmoji();
      }

      if (currentUserId != null && currentUserId.isNotEmpty) {
        EmojiModel? currentUserEmoji;

        for (final e in all) {
          final uid = (e.userId ?? '').trim();
          if (uid == currentUserId.trim()) {
            currentUserEmoji = e;
            break;
          }
        }

        if (currentUserEmoji != null) {
          // Keep only the current user's row in emoji_table
          await localDataSource.deleteOtherUsersEmojis(currentUserId);
          return currentUserEmoji;
        }

        // Migration fallback: older rows might not have userId set. In that
        // case, treat the most recent row as the current user's emoji and
        // rebind it so future reads work correctly.
        final fallback = all.first;
        final patched = fallback.copyWith(userId: currentUserId.trim());
        await localDataSource.saveEmoji(patched);
        await localDataSource.deleteOtherUsersEmojis(currentUserId);
        return patched;
      }

      // No currentUserId yet (very early app state) – just return latest row
      return all.first;
    } catch (_) {
      // Last resort fallback
      return await localDataSource.getEmoji();
    }
  }
}
