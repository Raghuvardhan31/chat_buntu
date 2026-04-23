import 'package:chataway_plus/core/database/tables/chat/message_reactions_table.dart';
import 'package:chataway_plus/features/chat/data/socket/socket_models/index.dart';

/// Service for managing message reactions in local database
class MessageReactionsDatabaseService {
  static final MessageReactionsDatabaseService _instance =
      MessageReactionsDatabaseService._internal();
  factory MessageReactionsDatabaseService() => _instance;
  MessageReactionsDatabaseService._internal();

  static MessageReactionsDatabaseService get instance => _instance;

  /// Get all reactions for a specific message
  Future<List<MessageReaction>> getReactionsForMessage(String messageId) {
    return MessageReactionsTable.getReactionsForMessage(messageId);
  }

  /// Get user's reaction for a specific message
  Future<MessageReaction?> getUserReactionForMessage({
    required String messageId,
    required String userId,
  }) {
    return MessageReactionsTable.getUserReactionForMessage(
      messageId: messageId,
      userId: userId,
    );
  }

  /// Add or update a reaction
  Future<void> upsertReaction(MessageReaction reaction) {
    return MessageReactionsTable.upsertReaction(reaction);
  }

  /// Batch add or update reactions
  Future<void> upsertReactions(List<MessageReaction> reactions) {
    return MessageReactionsTable.upsertReactions(reactions);
  }

  /// Remove a reaction
  Future<void> removeReaction({
    required String messageId,
    required String userId,
  }) {
    return MessageReactionsTable.removeReaction(
      messageId: messageId,
      userId: userId,
    );
  }

  /// Remove all reactions for a message
  Future<void> removeAllReactionsForMessage(String messageId) {
    return MessageReactionsTable.removeAllReactionsForMessage(messageId);
  }

  /// Get count of reactions for a message
  Future<int> getReactionCount(String messageId) {
    return MessageReactionsTable.getReactionCount(messageId);
  }

  /// Clear all reactions (for logout or data reset)
  Future<void> clearAll() {
    return MessageReactionsTable.clearAll();
  }
}
