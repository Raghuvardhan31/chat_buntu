// lib/features/profile/presentation/providers/emoji/emoji_state.dart

import '../../../data/models/emoji_model.dart';

// =============================
// Loading State Enum
// =============================

enum EmojiLoadingState { initial, loading, loaded, error, refreshing }

// =============================
// Emoji UI State
// =============================

class EmojiUIState {
  final EmojiLoadingState loadingState;
  final EmojiModel? emoji;
  final String? errorMessage;
  final bool hasEverLoaded;
  final bool isEditing;
  final bool isProcessing;
  final bool showShimmer;
  final bool forceNextCreate;

  // Edit fields
  final String editingEmoji;
  final String editingCaption;
  final int emojiCharacterCount;
  final int captionCharacterCount;

  static const Object _unset = Object();

  const EmojiUIState({
    this.loadingState = EmojiLoadingState.initial,
    this.emoji,
    this.errorMessage,
    this.hasEverLoaded = false,
    this.isEditing = false,
    this.isProcessing = false,
    this.showShimmer = false,
    this.forceNextCreate = false,
    this.editingEmoji = '',
    this.editingCaption = '',
    this.emojiCharacterCount = 0,
    this.captionCharacterCount = 0,
  });

  EmojiUIState copyWith({
    EmojiLoadingState? loadingState,
    Object? emoji = _unset,
    Object? errorMessage = _unset,
    bool? hasEverLoaded,
    bool? isEditing,
    bool? isProcessing,
    bool? showShimmer,
    bool? forceNextCreate,
    String? editingEmoji,
    String? editingCaption,
    int? emojiCharacterCount,
    int? captionCharacterCount,
  }) {
    return EmojiUIState(
      loadingState: loadingState ?? this.loadingState,
      emoji: identical(emoji, _unset) ? this.emoji : emoji as EmojiModel?,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      hasEverLoaded: hasEverLoaded ?? this.hasEverLoaded,
      isEditing: isEditing ?? this.isEditing,
      isProcessing: isProcessing ?? this.isProcessing,
      showShimmer: showShimmer ?? this.showShimmer,
      forceNextCreate: forceNextCreate ?? this.forceNextCreate,
      editingEmoji: editingEmoji ?? this.editingEmoji,
      editingCaption: editingCaption ?? this.editingCaption,
      emojiCharacterCount: emojiCharacterCount ?? this.emojiCharacterCount,
      captionCharacterCount:
          captionCharacterCount ?? this.captionCharacterCount,
    );
  }

  // Convenience getters
  bool get isLoading => loadingState == EmojiLoadingState.loading;
  bool get isLoaded => loadingState == EmojiLoadingState.loaded;
  bool get hasError => loadingState == EmojiLoadingState.error;
  bool get isRefreshing => loadingState == EmojiLoadingState.refreshing;
  bool get isInitial => loadingState == EmojiLoadingState.initial;

  // Emoji state checks
  bool get hasEmoji => emoji != null && emoji!.hasEmoji;
  bool get hasCaption => emoji != null && emoji!.hasCaption;
  bool get isEmojiValid => emoji != null && emoji!.isValid;

  // Display values
  String get displayEmoji => emoji?.emoji ?? '';
  String get displayCaption => emoji?.caption ?? '';
  String get displayUserName =>
      '${emoji?.userFirstName ?? ''} ${emoji?.userLastName ?? ''}'.trim();

  // Validation
  bool get canSave =>
      editingEmoji.trim().isNotEmpty &&
      editingCaption.trim().isNotEmpty &&
      emojiCharacterCount <= 50 &&
      captionCharacterCount <= 200;

  bool get hasChanges =>
      editingEmoji.trim() != displayEmoji ||
      editingCaption.trim() != displayCaption;
}

// =============================
// Emoji Action State
// =============================

class EmojiActionState {
  final bool isCreating;
  final bool isUpdating;
  final bool isDeleting;
  final String? actionError;
  final String? successMessage;

  const EmojiActionState({
    this.isCreating = false,
    this.isUpdating = false,
    this.isDeleting = false,
    this.actionError,
    this.successMessage,
  });

  EmojiActionState copyWith({
    bool? isCreating,
    bool? isUpdating,
    bool? isDeleting,
    String? actionError,
    String? successMessage,
  }) {
    return EmojiActionState(
      isCreating: isCreating ?? this.isCreating,
      isUpdating: isUpdating ?? this.isUpdating,
      isDeleting: isDeleting ?? this.isDeleting,
      actionError: actionError ?? this.actionError,
      successMessage: successMessage ?? this.successMessage,
    );
  }

  bool get isPerformingAction => isCreating || isUpdating || isDeleting;
  bool get hasError => actionError != null;
  bool get hasSuccess => successMessage != null;
}
