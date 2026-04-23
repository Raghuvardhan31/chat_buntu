// lib/features/profile/data/repositories/emoji/helper_repos/delete_emoji_repository.dart

import 'package:flutter/foundation.dart';
import '../../../datasources/emoji_remote_datasource.dart';
import '../../../datasources/emoji_local_datasource.dart';
import '../../../models/requests/emoji_request_models.dart';
import '../../../models/responses/emoji_response_models.dart';
import '../../../models/responses/emoji_result.dart';

/// Repository for deleting emoji
class DeleteEmojiRepository {
  final EmojiRemoteDataSource remoteDataSource;
  final EmojiLocalDataSource localDataSource;

  DeleteEmojiRepository({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  void _log(String message) {
    if (kDebugMode) debugPrint(message);
  }

  Future<EmojiResult<DeleteEmojiResponseModel>> deleteEmoji(
    String id,
    String emoji,
    String caption,
  ) async {
    try {
      final request = DeleteEmojiRequestModel(emoji: emoji, caption: caption);

      _log(
        '[EmojiRepo:Delete] request(id=$id) -> emoji="${request.emoji}" caption="${request.caption}"',
      );
      final response = await remoteDataSource.deleteEmoji(id, request);

      if (response.isSuccess) {
        // Post-delete GET to sync any server-side state
        _log('[EmojiRepo:Delete] response OK -> post-write GET current emoji');
        final latest = await remoteDataSource.getCurrentEmoji();
        if (latest.isSuccess && latest.data != null) {
          _log(
            '[EmojiRepo:Delete] server still has emoji -> save latest -> emoji="${latest.data!.emoji}" caption="${latest.data!.caption}"',
          );
          await localDataSource.saveEmoji(latest.data!);
          _log('[EmojiRepo:Delete] saved latest snapshot to local DB');
        } else {
          await localDataSource.clearEmoji();
          _log('[EmojiRepo:Delete] cleared local emoji');
          _log('[EmojiRepo:Delete] no emoji found on server -> keep cleared');
        }
        return EmojiResult.success(response);
      } else {
        // If server says 404 (not found), treat as already deleted -> clear local and succeed
        if (response.statusCode == 404) {
          await localDataSource.clearEmoji();
          _log('[EmojiRepo:Delete] 404 -> treat as deleted, cleared local');
          return EmojiResult.success(response);
        }
        _log(
          '[EmojiRepo:Delete] response ERROR -> message="${response.message}" code=${response.statusCode}',
        );
        return EmojiResult.failure(
          message: response.message,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      _log('[EmojiRepo:Delete] exception: $e');
      return EmojiResult.failure(message: e.toString());
    }
  }
}
