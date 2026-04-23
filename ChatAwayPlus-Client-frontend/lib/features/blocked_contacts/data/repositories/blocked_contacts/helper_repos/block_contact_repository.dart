import 'package:chataway_plus/core/storage/token_storage.dart';
import '../../../datasources/blocked_contacts_local_datasource.dart';
import '../../../datasources/blocked_contacts_remote_datasource.dart';
import '../../../models/blocked_contacts_models.dart';

class BlockContactRepository {
  final BlockedContactsRemoteDataSource remoteDataSource;
  final BlockedContactsLocalDataSource localDataSource;
  BlockContactRepository({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  Future<BlockActionResult> execute(String blockedUserId) async {
    final userId = await TokenSecureStorage.instance.getCurrentUserIdUUID();
    if (userId == null || userId.trim().isEmpty) {
      return const BlockActionResult(
        isSuccess: false,
        isPendingSync: false,
        message: 'Authentication required',
        statusCode: 401,
      );
    }

    final targetId = blockedUserId.trim();
    if (targetId.isEmpty) {
      return const BlockActionResult(
        isSuccess: false,
        isPendingSync: false,
        message: 'Invalid user',
        statusCode: 400,
      );
    }
    if (targetId == userId.trim()) {
      return const BlockActionResult(
        isSuccess: false,
        isPendingSync: false,
        message: 'You cannot block yourself',
        statusCode: 400,
      );
    }

    await localDataSource.upsertBlocked(userId, targetId);

    final resp = await remoteDataSource.blockUser(targetId);
    if (resp.success) {
      return BlockActionResult(
        isSuccess: true,
        isPendingSync: false,
        message: resp.message,
        statusCode: resp.statusCode,
      );
    }

    if (resp.statusCode == 400 &&
        resp.message.toLowerCase().contains('already blocked')) {
      return BlockActionResult(
        isSuccess: true,
        isPendingSync: false,
        message: resp.message,
        statusCode: resp.statusCode,
      );
    }

    if (resp.statusCode == 404) {
      await localDataSource.upsertUnblocked(userId, targetId);
      return BlockActionResult(
        isSuccess: false,
        isPendingSync: false,
        message: resp.message,
        statusCode: resp.statusCode,
      );
    }

    return BlockActionResult(
      isSuccess: true,
      isPendingSync: true,
      message: 'Blocked locally, will sync later',
      statusCode: resp.statusCode,
    );
  }
}
