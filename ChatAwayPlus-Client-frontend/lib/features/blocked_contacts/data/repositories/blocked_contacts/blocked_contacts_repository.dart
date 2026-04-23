import '../../models/blocked_contacts_models.dart';

abstract class BlockedContactsRepository {
  Future<BlockedUsersResponseModel> fetchBlockedUsersAndSync();
  Future<BlockActionResult> blockUser(String blockedUserId);
  Future<BlockActionResult> unblockUser(String blockedUserId);
  Future<Set<String>> getBlockedUserIdsLocal(String userId);
  Future<List<Map<String, dynamic>>> getBlockedRowsLocal(String userId);
}
