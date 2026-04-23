// lib/features/profile/data/repositories/emoji/helper_repos/get_emoji_repository.dart

import '../../../datasources/emoji_remote_datasource.dart';
import '../../../datasources/emoji_local_datasource.dart';
import '../../../models/responses/emoji_response_models.dart';
import '../../../models/responses/emoji_result.dart';

/// Repository for getting emoji
class GetEmojiRepository {
  final EmojiRemoteDataSource remoteDataSource;
  final EmojiLocalDataSource localDataSource;

  GetEmojiRepository({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  Future<EmojiResult<GetEmojiResponseModel>> getCurrentEmoji() async {
    try {
      final response = await remoteDataSource.getCurrentEmoji();

      if (response.isSuccess && response.data != null) {
        await localDataSource.saveEmoji(response.data!);
        return EmojiResult.success(response);
      } else {
        return EmojiResult.failure(
          message: response.message,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return EmojiResult.failure(message: e.toString());
    }
  }
}
