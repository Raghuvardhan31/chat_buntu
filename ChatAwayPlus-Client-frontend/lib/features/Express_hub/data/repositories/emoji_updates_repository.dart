// lib/features/voice_hub/data/repositories/emoji_updates_repository.dart

import '../datasources/emoji_updates_remote_datasource.dart';
import '../datasources/emoji_updates_local_datasource.dart';
import '../models/responses/emoji_updates_response.dart';
import '../models/responses/emoji_updates_result.dart';

/// Repository for emoji updates
class EmojiUpdatesRepository {
  final EmojiUpdatesRemoteDataSource remoteDataSource;
  final EmojiUpdatesLocalDataSource localDataSource;

  EmojiUpdatesRepository({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  /// Get all emoji updates from API and save to local database
  Future<EmojiUpdatesResult<GetAllEmojiUpdatesResponse>> getAllEmojiUpdates() async {
    try {
      final response = await remoteDataSource.getAllEmojiUpdates();

      if (response.isSuccess && response.data != null) {
        // Save to local database
        await localDataSource.saveAllEmojiUpdates(response.data!);
        return EmojiUpdatesResult.success(response);
      } else {
        return EmojiUpdatesResult.failure(
          message: response.message,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return EmojiUpdatesResult.failure(
        message: e.toString(),
      );
    }
  }

  /// Get emoji updates from local database only
  Future<EmojiUpdatesResult<GetAllEmojiUpdatesResponse>> getLocalEmojiUpdates() async {
    try {
      final emojiList = await localDataSource.getAllEmojiUpdates();
      final response = GetAllEmojiUpdatesResponse(
        success: true,
        message: 'Loaded from local database',
        data: emojiList,
      );
      return EmojiUpdatesResult.success(response);
    } catch (e) {
      return EmojiUpdatesResult.failure(
        message: e.toString(),
      );
    }
  }
}
