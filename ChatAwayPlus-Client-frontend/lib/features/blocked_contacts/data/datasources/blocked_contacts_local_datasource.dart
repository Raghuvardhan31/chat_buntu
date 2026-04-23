import 'package:chataway_plus/core/database/tables/contacts/blocked_contacts_table.dart';

abstract class BlockedContactsLocalDataSource {
  Future<void> upsertBlocked(
    String userId,
    String blockedUserId, {
    int? blockedAt,
    String? firstName,
    String? lastName,
    String? chatPicture,
  });
  Future<void> upsertUnblocked(
    String userId,
    String blockedUserId, {
    int? blockedAt,
  });
  Future<List<Map<String, dynamic>>> getAllRows(String userId);
  Future<List<Map<String, dynamic>>> getBlockedRows(String userId);
  Future<Set<String>> getBlockedUserIds(String userId);
  Future<void> markUnblockedForMissing(
    String userId,
    Set<String> serverBlocked,
  );
}

class BlockedContactsLocalDataSourceImpl
    implements BlockedContactsLocalDataSource {
  @override
  Future<void> upsertBlocked(
    String userId,
    String blockedUserId, {
    int? blockedAt,
    String? firstName,
    String? lastName,
    String? chatPicture,
  }) {
    return BlockedContactsTable.upsert(
      userId: userId,
      blockedUserId: blockedUserId,
      isBlocked: true,
      blockedAt: blockedAt,
      firstName: firstName,
      lastName: lastName,
      chatPicture: chatPicture,
    );
  }

  @override
  Future<void> upsertUnblocked(
    String userId,
    String blockedUserId, {
    int? blockedAt,
  }) {
    return BlockedContactsTable.upsert(
      userId: userId,
      blockedUserId: blockedUserId,
      isBlocked: false,
      blockedAt: blockedAt,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getAllRows(String userId) {
    return BlockedContactsTable.getAllRows(userId);
  }

  @override
  Future<List<Map<String, dynamic>>> getBlockedRows(String userId) {
    return BlockedContactsTable.getBlockedUsers(userId);
  }

  @override
  Future<Set<String>> getBlockedUserIds(String userId) {
    return BlockedContactsTable.getBlockedUserIds(userId);
  }

  @override
  Future<void> markUnblockedForMissing(
    String userId,
    Set<String> serverBlocked,
  ) {
    return BlockedContactsTable.markUnblockedForMissing(userId, serverBlocked);
  }
}
