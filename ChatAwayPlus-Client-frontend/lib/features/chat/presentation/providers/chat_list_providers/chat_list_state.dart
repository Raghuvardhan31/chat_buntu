// lib/features/chat/presentation/providers/chat_list_providers/chat_list_state.dart

import 'package:chataway_plus/features/chat/models/chat_message_model.dart';

/// State for chat list page
class ChatListState {
  final List<ChatContactModel> contacts;
  final bool loading;
  final String? error;

  const ChatListState({
    this.contacts = const [],
    this.loading = false,
    this.error,
  });

  ChatListState copyWith({
    List<ChatContactModel>? contacts,
    bool? loading,
    String? error,
  }) {
    return ChatListState(
      contacts: contacts ?? this.contacts,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}
