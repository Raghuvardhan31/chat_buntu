// 1. Keep the enum as is - it's clean and useful
enum ContactLoadState {
  starting,
  permissionRequired,
  permissionDenied,
  loadingDeviceContacts,
  processingContacts,
  checkingAppUsers,
  refreshing,
  partiallyCompleted,
  completed,
  error,
}

// 2. Replace Freezed class with a simple immutable class
class ContactLoadingProgress {
  final ContactLoadState state;
  final String message;
  final double progress;
  final String? error;
  final int? totalContacts;
  final int? processedContacts;

  const ContactLoadingProgress({
    required this.state,
    required this.message,
    required this.progress,
    this.error,
    this.totalContacts,
    this.processedContacts,
  });

  // 3. Add copyWith for immutability
  ContactLoadingProgress copyWith({
    ContactLoadState? state,
    String? message,
    double? progress,
    String? error,
    int? totalContacts,
    int? processedContacts,
  }) {
    return ContactLoadingProgress(
      state: state ?? this.state,
      message: message ?? this.message,
      progress: progress ?? this.progress,
      error: error ?? this.error,
      totalContacts: totalContacts ?? this.totalContacts,
      processedContacts: processedContacts ?? this.processedContacts,
    );
  }

  // 4. Override equality for value comparison
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ContactLoadingProgress &&
        other.state == state &&
        other.message == message &&
        other.progress == progress &&
        other.error == error &&
        other.totalContacts == totalContacts &&
        other.processedContacts == processedContacts;
  }

  @override
  int get hashCode =>
      state.hashCode ^
      message.hashCode ^
      progress.hashCode ^
      error.hashCode ^
      totalContacts.hashCode ^
      processedContacts.hashCode;

  @override
  String toString() =>
      'ContactLoadingProgress(state: $state, message: $message, '
      'progress: $progress, error: $error, '
      'totalContacts: $totalContacts, processedContacts: $processedContacts)';
}

// 4. Keep the extension for utility methods
extension ContactLoadStateExtension on ContactLoadState {
  bool get isInProgress =>
      this == ContactLoadState.starting ||
      this == ContactLoadState.loadingDeviceContacts ||
      this == ContactLoadState.processingContacts ||
      this == ContactLoadState.checkingAppUsers ||
      this == ContactLoadState.refreshing;

  bool get isError =>
      this == ContactLoadState.error ||
      this == ContactLoadState.permissionDenied;

  bool get isCompleted =>
      this == ContactLoadState.completed ||
      this == ContactLoadState.partiallyCompleted;
}
