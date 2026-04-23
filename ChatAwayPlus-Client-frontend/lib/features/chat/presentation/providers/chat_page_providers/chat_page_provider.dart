// lib/features/chat/presentation/providers/chat_page_providers/chat_page_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasources/chat_local_datasource.dart';
import 'chat_page_notifier.dart';
import 'chat_page_state.dart';

/// Provider for chat local datasource
final chatLocalDataSourceProvider = Provider<ChatLocalDataSource>((ref) {
  return ChatLocalDataSourceImpl();
});

/// Chat page notifier provider (family for different users)
/// Usage: ref.watch(chatPageNotifierProvider(otherUserId))
final chatPageNotifierProvider =
    StateNotifierProvider.family<
      ChatPageNotifier,
      ChatPageState,
      Map<String, String>
    >((ref, params) {
      final otherUserId = params['otherUserId']!;
      final currentUserId = params['currentUserId']!;

      return ChatPageNotifier(otherUserId, currentUserId);
    });
