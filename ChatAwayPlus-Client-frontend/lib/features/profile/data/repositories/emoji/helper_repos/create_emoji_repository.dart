// lib/features/profile/data/repositories/emoji/helper_repos/create_emoji_repository.dart

import 'package:flutter/foundation.dart';
import '../../../datasources/emoji_remote_datasource.dart';
import '../../../datasources/emoji_local_datasource.dart';
import '../../../models/requests/emoji_request_models.dart';
import '../../../models/responses/emoji_response_models.dart';
import '../../../models/responses/emoji_result.dart';

/// Repository for creating emoji (first time)
class CreateEmojiRepository {
  final EmojiRemoteDataSource remoteDataSource;
  final EmojiLocalDataSource localDataSource;

  CreateEmojiRepository({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  void _log(String message) {
    if (kDebugMode) debugPrint(message);
  }

  Future<EmojiResult<EmojiUpdateResponseModel>> createEmoji(
    String emoji,
    String caption,
  ) async {
    try {
      final request = EmojiUpdateRequestModel(emoji: emoji, caption: caption);

      _log(
        '[EmojiRepo:Create] request -> emoji="${request.emoji}" caption="${request.caption}"',
      );
      final response = await remoteDataSource.createEmoji(request);

      if (response.isSuccess && response.data != null) {
        _log(
          '[EmojiRepo:Create] response OK -> saving immediate snapshot to local DB',
        );
        await localDataSource.saveEmoji(response.data!);
        // Post-write GET to ensure freshest snapshot
        _log('[EmojiRepo:Create] post-write GET current emoji');
        final latest = await remoteDataSource.getCurrentEmoji();
        if (latest.isSuccess && latest.data != null) {
          _log(
            '[EmojiRepo:Create] saving latest snapshot from GET -> emoji="${latest.data!.emoji}" caption="${latest.data!.caption}"',
          );
          await localDataSource.saveEmoji(latest.data!);
          _log('[EmojiRepo:Create] saved latest snapshot to local DB');
        } else {
          _log('[EmojiRepo:Create] GET failed -> kept immediate snapshot');
        }
        return EmojiResult.success(response);
      } else {
        _log(
          '[EmojiRepo:Create] response ERROR -> message="${response.message}" code=${response.statusCode}',
        );
        return EmojiResult.failure(
          message: response.message,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      _log('[EmojiRepo:Create] exception: $e');
      return EmojiResult.failure(message: e.toString());
    }
  }
}
