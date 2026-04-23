// lib/features/chat/presentation/providers/chat_page_providers/chat_page_state.dart

import '../../../models/chat_message_model.dart';

/// State model for individual chat page
class ChatPageState {
  final bool loading; // Loading messages
  final bool sending; // Sending a message
  final List<ChatMessageModel> messages;
  final String? error;
  final bool hasMore; // More messages available for pagination
  final int currentPage;
  final Set<String> selectedMessageIds;
  final Map<String, double>
  uploadProgress; // messageId -> progress (0.0 to 1.0)

  const ChatPageState({
    this.loading = false,
    this.sending = false,
    this.messages = const [],
    this.error,
    this.hasMore = true,
    this.currentPage = 1,
    this.selectedMessageIds = const {},
    this.uploadProgress = const {},
  });

  /// Get upload progress for a specific message (null if not uploading)
  double? getUploadProgress(String messageId) => uploadProgress[messageId];

  ChatPageState copyWith({
    bool? loading,
    bool? sending,
    List<ChatMessageModel>? messages,
    String? error,
    bool clearError = false,
    bool? hasMore,
    int? currentPage,
    Set<String>? selectedMessageIds,
    Map<String, double>? uploadProgress,
  }) {
    return ChatPageState(
      loading: loading ?? this.loading,
      sending: sending ?? this.sending,
      messages: messages ?? this.messages,
      error: clearError ? null : (error ?? this.error),
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      selectedMessageIds: selectedMessageIds ?? this.selectedMessageIds,
      uploadProgress: uploadProgress ?? this.uploadProgress,
    );
  }

  @override
  String toString() {
    return 'ChatPageState(loading: $loading, sending: $sending, messagesCount: ${messages.length}, selected=${selectedMessageIds.length}, error: $error, hasMore: $hasMore, currentPage: $currentPage)';
  }
}
