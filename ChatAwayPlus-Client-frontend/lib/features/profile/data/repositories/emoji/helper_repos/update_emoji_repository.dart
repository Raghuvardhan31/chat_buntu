// lib/features/profile/data/repositories/emoji/helper_repos/update_emoji_repository.dart

import 'package:flutter/foundation.dart';
import '../../../datasources/emoji_remote_datasource.dart';
import '../../../datasources/emoji_local_datasource.dart';
import '../../../models/requests/emoji_request_models.dart';
import '../../../models/responses/emoji_response_models.dart';
import '../../../models/responses/emoji_result.dart';

/// Repository for updating existing emoji
class UpdateEmojiRepository {
  final EmojiRemoteDataSource remoteDataSource;
  final EmojiLocalDataSource localDataSource;

  UpdateEmojiRepository({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  void _log(String message) {
    if (kDebugMode) debugPrint(message);
  }

  Future<EmojiResult<EmojiUpdateResponseModel>> updateEmoji(
    String id,
    String emoji,
    String caption,
  ) async {
    try {
      final request = EmojiUpdateRequestModel(emoji: emoji, caption: caption);

      _log(
        '[EmojiRepo:Update] request(id=$id) -> emoji="${request.emoji}" caption="${request.caption}"',
      );
      final response = await remoteDataSource.updateEmoji(id, request);

      if (response.isSuccess && response.data != null) {
        // Post-write GET to ensure freshest snapshot
        _log('[EmojiRepo:Update] response OK -> post-write GET current emoji');
        _log('[EmojiRepo:Update] post-write GET current emoji');
        final latest = await remoteDataSource.getCurrentEmoji();
        if (latest.isSuccess && latest.data != null) {
          _log(
            '[EmojiRepo:Update] saving latest snapshot from GET -> emoji="${latest.data!.emoji}" caption="${latest.data!.caption}"',
          );
          await localDataSource.saveEmoji(latest.data!);
          _log('[EmojiRepo:Update] saved latest snapshot to local DB');
        } else {
          _log('[EmojiRepo:Update] GET failed -> kept local update only');
        }
        return EmojiResult.success(response);
      } else {
        _log(
          '[EmojiRepo:Update] response ERROR -> message="${response.message}" code=${response.statusCode}',
        );
        return EmojiResult.failure(
          message: response.message,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      _log('[EmojiRepo:Update] exception: $e');
      return EmojiResult.failure(message: e.toString());
    }
  }
}
