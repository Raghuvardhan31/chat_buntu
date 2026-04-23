import 'package:chataway_plus/core/storage/token_storage.dart';
import '../../../datasources/blocked_contacts_local_datasource.dart';
import '../../../datasources/blocked_contacts_remote_datasource.dart';
import '../../../models/blocked_contacts_models.dart';

class GetBlockedContactsRepository {
  final BlockedContactsRemoteDataSource remoteDataSource;
  final BlockedContactsLocalDataSource localDataSource;
  GetBlockedContactsRepository({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  Future<BlockedUsersResponseModel> fetchAndSync() async {
    final blocked = await remoteDataSource.getBlockedUsers();
    final userId = await TokenSecureStorage.instance.getCurrentUserIdUUID();
    if (blocked.isSuccess && userId != null && userId.isNotEmpty) {
      final serverIds = <String>{};
      for (final u in blocked.data) {
        final id = u.userId.trim();
        if (id.isEmpty) continue;
        serverIds.add(id);
        await localDataSource.upsertBlocked(
          userId,
          id,
          firstName: u.firstName,
          lastName: u.lastName,
          chatPicture: u.chatPicture,
        );
      }
      await localDataSource.markUnblockedForMissing(userId, serverIds);
    }
    return blocked;
  }
}
