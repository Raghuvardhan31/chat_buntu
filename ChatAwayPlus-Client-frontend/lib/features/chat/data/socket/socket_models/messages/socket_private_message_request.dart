import '../../../../models/chat_message_model.dart';

/// Socket private message request model
class SocketPrivateMessageRequest {
  final String? id; // Optional local ID for optimistic updates
  final String senderId;
  final String receiverId;
  final String messageType;
  final String message;
  final String? fileUrl;
  final String? mimeType;
  final String? fileName;
  final int? fileSize;
  final Map<String, dynamic>? fileMetadata;
  final String deliveryChannel;
  final DateTime? createdAt;
  final String messageStatus;

  SocketPrivateMessageRequest({
    this.id,
    required this.senderId,
    required this.receiverId,
    this.messageType = 'text',
    required this.message,
    this.fileUrl,
    this.mimeType,
    this.fileName,
    this.fileSize,
    this.fileMetadata,
    this.deliveryChannel = 'socket',
    this.createdAt,
    this.messageStatus = 'sending',
  });

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'messageType': messageType,
      'message': message,
      'fileUrl': fileUrl,
      'mimeType': mimeType,
      'fileName': fileName,
      'fileSize': fileSize,
      'fileMetadata': fileMetadata,
      'deliveryChannel': deliveryChannel,
      'createdAt': createdAt?.toIso8601String(),
      'messageStatus': messageStatus,
    };
  }

  /// Create from ChatMessageModel for sending
  factory SocketPrivateMessageRequest.fromChatMessage(
    ChatMessageModel message,
  ) {
    return SocketPrivateMessageRequest(
      id: message.id,
      senderId: message.senderId,
      receiverId: message.receiverId,
      messageType: message.messageType.name,
      message: message.message,
      fileUrl: message.imageUrl,
      mimeType: message.mimeType,
      fileName: message.fileName,
      fileSize: message.fileSize,
      deliveryChannel: message.deliveryChannel,
      createdAt: message.createdAt,
      messageStatus: message.messageStatus,
    );
  }
}
