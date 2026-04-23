import 'package:flutter/foundation.dart';

import '../../../../../core/database/tables/chat/follow_ups_table.dart';
import '../../../../../core/database/tables/chat/messages_table.dart';

/// Local database service for managing follow-up entries and related message flags
/// Handles deletion of follow-up entries and resetting corresponding message flags
class FollowUpsLocalDatabaseService {
  const FollowUpsLocalDatabaseService._();

  static const FollowUpsLocalDatabaseService instance =
      FollowUpsLocalDatabaseService._();

  /// Delete a follow-up entry and reset the corresponding message's isFollowUp flag
  ///
  /// This performs two operations:
  /// 1. Delete the follow-up entry from FollowUpsTable
  /// 2. Reset is_follow_up flag to 0 for matching messages in MessagesTable
  ///
  /// Returns true if the follow-up entry was successfully deleted.
  /// The message flag reset is optional - it may not find a matching message
  /// if the message was already synced from server or deleted.
  Future<bool> deleteFollowUpEntry({
    required String currentUserId,
    required String contactId,
    required String followUpText,
    required DateTime createdAt,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('🗑️ Deleting follow-up entry: "$followUpText"');
      }

      // 1. Delete follow-up entry from FollowUpsTable
      final deleted = await FollowUpsTable.instance.deleteFollowUp(
        currentUserId: currentUserId,
        contactId: contactId,
        text: followUpText,
        createdAt: createdAt,
      );

      if (!deleted) {
        if (kDebugMode) {
          debugPrint('❌ Failed to delete follow-up entry from database');
        }
        return false;
      }

      // 2. Reset is_follow_up flag for corresponding message(s)
      final flagReset = await MessagesTable.instance.resetFollowUpFlag(
        currentUserId: currentUserId,
        contactId: contactId,
        followUpText: followUpText,
        createdAt: createdAt,
      );

      if (kDebugMode) {
        if (flagReset) {
          debugPrint('✅ Follow-up deleted and message flag reset successfully');
        } else {
          debugPrint(
            '⚠️ Follow-up deleted but no matching message found to reset flag',
          );
        }
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error deleting follow-up: $e');
      }
      return false;
    }
  }
}
