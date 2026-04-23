// lib/features/profile/data/repositories/emoji/emoji_repository.dart

import '../../models/emoji_model.dart';
import '../../models/responses/emoji_response_models.dart';
import '../../models/responses/emoji_result.dart';

/// Main emoji repository interface
/// Defines all emoji-related operations
abstract class EmojiRepository {
  /// Get current emoji
  Future<EmojiResult<GetEmojiResponseModel>> getCurrentEmoji();

  /// Create emoji (first time; server generates id)
  Future<EmojiResult<EmojiUpdateResponseModel>> createEmoji(
    String emoji,
    String caption,
  );

  /// Update existing emoji
  Future<EmojiResult<EmojiUpdateResponseModel>> updateEmoji(
    String id,
    String emoji,
    String caption,
  );

  /// Delete emoji
  Future<EmojiResult<DeleteEmojiResponseModel>> deleteEmoji(
    String id,
    String emoji,
    String caption,
  );

  /// Clear all emoji data (for logout)
  Future<void> clearEmoji();

  /// Get emoji from local database (for offline access)
  Future<EmojiModel?> getLocalEmoji();
}
