import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/features/chat/presentation/providers/message_reactions/message_reaction_notifier.dart';
import 'package:chataway_plus/features/chat/presentation/providers/message_reactions/message_reaction_state.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';

/// Provider to get current user ID
final currentUserIdFutureProvider = FutureProvider<String>((ref) async {
  final tokenStorage = TokenSecureStorage();
  final userId = await tokenStorage.getCurrentUserIdUUID();
  return userId ?? '';
});

/// Provider for message reactions - single instance that loads userId internally
final messageReactionProvider = ChangeNotifierProvider<MessageReactionNotifier>(
  (ref) {
    // Don't watch FutureProvider here - it causes the notifier to be disposed
    // when userId loads. Instead, the notifier will load userId internally.
    return MessageReactionNotifier(currentUserId: '');
  },
);

/// Provider for reactions state
final messageReactionStateProvider = Provider<MessageReactionState>((ref) {
  return ref.watch(messageReactionProvider).state;
});

/// Provider for reactions of a specific message
final messageReactionsForMessageProvider = Provider.family
    .autoDispose<List<dynamic>, String>((ref, messageId) {
      final notifier = ref.watch(messageReactionProvider);
      final reactions = notifier.getReactions(messageId);

      return reactions;
    });

/// Provider for user's reaction to a specific message
final userReactionForMessageProvider = Provider.family
    .autoDispose<dynamic, String>((ref, messageId) {
      final notifier = ref.watch(messageReactionProvider);
      return notifier.getUserReaction(messageId);
    });

/// Provider for grouped reactions of a specific message
final groupedReactionsProvider = Provider.family
    .autoDispose<Map<String, ReactionGroup>, String>((ref, messageId) {
      final notifier = ref.watch(messageReactionProvider);
      final grouped = notifier.getGroupedReactions(messageId);

      return grouped;
    });

/// Provider to check if user has reacted to a message
final hasUserReactedProvider = Provider.family.autoDispose<bool, String>((
  ref,
  messageId,
) {
  final notifier = ref.watch(messageReactionProvider);
  return notifier.hasUserReacted(messageId);
});
