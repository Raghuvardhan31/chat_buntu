import '../../datasources/blocked_contacts_local_datasource.dart';
import 'helper_repos/block_contact_repository.dart';
import 'helper_repos/get_blocked_contacts_repository.dart';
import 'helper_repos/unblock_contact_repository.dart';
import 'blocked_contacts_repository.dart' as iface;
import '../../models/blocked_contacts_models.dart';

class BlockedContactsRepositoryImpl implements iface.BlockedContactsRepository {
  final GetBlockedContactsRepository getRepo;
  final BlockContactRepository blockRepo;
  final UnblockContactRepository unblockRepo;
  final BlockedContactsLocalDataSource localDataSource;

  BlockedContactsRepositoryImpl({
    required this.getRepo,
    required this.blockRepo,
    required this.unblockRepo,
    required this.localDataSource,
  });

  @override
  Future<BlockedUsersResponseModel> fetchBlockedUsersAndSync() {
    return getRepo.fetchAndSync();
  }

  @override
  Future<BlockActionResult> blockUser(String blockedUserId) {
    return blockRepo.execute(blockedUserId);
  }

  @override
  Future<BlockActionResult> unblockUser(String blockedUserId) {
    return unblockRepo.execute(blockedUserId);
  }

  @override
  Future<Set<String>> getBlockedUserIdsLocal(String userId) {
    return localDataSource.getBlockedUserIds(userId);
  }

  @override
  Future<List<Map<String, dynamic>>> getBlockedRowsLocal(String userId) {
    return localDataSource.getBlockedRows(userId);
  }
}
