// lib/features/chat/data/domain_models/requests/chat_request_models.dart

/// Base class for all chat request models
/// Provides common validation and serialization functionality
abstract class ChatRequestModel {
  const ChatRequestModel();

  /// Convert model to JSON for API requests
  Map<String, dynamic> toJson();

  /// Validate the model data before sending to API
  bool isValid();

  /// Get validation error message if model is invalid
  String? get validationError;
}

/// Model for sending a message request
class SendMessageRequestModel extends ChatRequestModel {
  final String receiverId;
  final String message;
  final String messageType;

  const SendMessageRequestModel({
    required this.receiverId,
    required this.message,
    this.messageType = 'text',
  });

  factory SendMessageRequestModel.fromJson(Map<String, dynamic> json) {
    return SendMessageRequestModel(
      receiverId: json['receiverId']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      messageType: json['messageType']?.toString() ?? 'text',
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'receiverId': receiverId,
      'message': message,
      'messageType': messageType,
    };
  }

  @override
  bool isValid() {
    if (receiverId.isEmpty) return false;
    if (message.trim().isEmpty) return false;
    return true;
  }

  @override
  String? get validationError {
    if (receiverId.isEmpty) {
      return 'Receiver ID is required';
    }
    if (message.trim().isEmpty) {
      return 'Message cannot be empty';
    }
    return null;
  }

  SendMessageRequestModel copyWith({
    String? receiverId,
    String? message,
    String? messageType,
  }) {
    return SendMessageRequestModel(
      receiverId: receiverId ?? this.receiverId,
      message: message ?? this.message,
      messageType: messageType ?? this.messageType,
    );
  }
}

/// Model for getting message status request
class GetMessageStatusRequestModel extends ChatRequestModel {
  final List<String> messageIds;

  const GetMessageStatusRequestModel({required this.messageIds});

  factory GetMessageStatusRequestModel.fromJson(Map<String, dynamic> json) {
    return GetMessageStatusRequestModel(
      messageIds:
          (json['messageIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {'messageIds': messageIds};
  }

  @override
  bool isValid() {
    return messageIds.isNotEmpty;
  }

  @override
  String? get validationError {
    if (messageIds.isEmpty) {
      return 'At least one message ID is required';
    }
    return null;
  }
}
