import 'package:chataway_plus/features/chat/data/socket/socket_models/index.dart';

/// State for message reactions
class MessageReactionState {
  final Map<String, List<MessageReaction>> messageReactions;
  final Set<String> loadedMessageIds;
  final bool isLoading;
  final String? error;

  const MessageReactionState({
    this.messageReactions = const {},
    this.loadedMessageIds = const <String>{},
    this.isLoading = false,
    this.error,
  });

  MessageReactionState copyWith({
    Map<String, List<MessageReaction>>? messageReactions,
    Set<String>? loadedMessageIds,
    bool? isLoading,
    String? error,
  }) {
    return MessageReactionState(
      messageReactions: messageReactions ?? this.messageReactions,
      loadedMessageIds: loadedMessageIds ?? this.loadedMessageIds,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Get reactions for a specific message
  List<MessageReaction> getReactionsForMessage(String messageId) {
    return messageReactions[messageId] ?? [];
  }

  bool isLoaded(String messageId) {
    return loadedMessageIds.contains(messageId);
  }

  /// Get user's reaction for a specific message
  MessageReaction? getUserReaction(String messageId, String userId) {
    final reactions = messageReactions[messageId] ?? [];
    try {
      return reactions.firstWhere((r) => r.userId == userId);
    } catch (e) {
      return null;
    }
  }

  /// Check if user has reacted to a message
  bool hasUserReacted(String messageId, String userId) {
    return getUserReaction(messageId, userId) != null;
  }

  /// Get reaction count for a message
  int getReactionCount(String messageId) {
    return (messageReactions[messageId] ?? []).length;
  }

  /// Group reactions by emoji for display
  Map<String, ReactionGroup> getGroupedReactions(String messageId) {
    final reactions = messageReactions[messageId] ?? [];
    final Map<String, ReactionGroup> grouped = {};

    for (final reaction in reactions) {
      if (!grouped.containsKey(reaction.emoji)) {
        grouped[reaction.emoji] = ReactionGroup(
          emoji: reaction.emoji,
          reactions: [],
        );
      }
      grouped[reaction.emoji]!.reactions.add(reaction);
    }

    return grouped;
  }
}

/// Grouped reactions by emoji
class ReactionGroup {
  final String emoji;
  final List<MessageReaction> reactions;

  ReactionGroup({required this.emoji, required this.reactions});

  int get count => reactions.length;

  List<String> get userIds => reactions.map((r) => r.userId).toList();

  bool containsUser(String userId) => userIds.contains(userId);
}
