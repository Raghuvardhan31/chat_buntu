import 'package:chataway_plus/core/storage/token_storage.dart';
import '../../../datasources/blocked_contacts_local_datasource.dart';
import '../../../datasources/blocked_contacts_remote_datasource.dart';
import '../../../models/blocked_contacts_models.dart';

class UnblockContactRepository {
  final BlockedContactsRemoteDataSource remoteDataSource;
  final BlockedContactsLocalDataSource localDataSource;
  UnblockContactRepository({
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

    await localDataSource.upsertUnblocked(userId, targetId);

    final resp = await remoteDataSource.unblockUser(targetId);
    if (resp.success) {
      return BlockActionResult(
        isSuccess: true,
        isPendingSync: false,
        message: resp.message,
        statusCode: resp.statusCode,
      );
    }

    if (resp.statusCode == 404 &&
        resp.message.toLowerCase().contains('not found')) {
      return BlockActionResult(
        isSuccess: true,
        isPendingSync: false,
        message: resp.message,
        statusCode: resp.statusCode,
      );
    }

    return BlockActionResult(
      isSuccess: true,
      isPendingSync: true,
      message: 'Unblocked locally, will sync later',
      statusCode: resp.statusCode,
    );
  }
}
