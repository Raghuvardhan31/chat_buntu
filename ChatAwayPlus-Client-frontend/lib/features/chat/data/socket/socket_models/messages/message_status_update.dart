import 'message_status.dart';

/// Message status update event
class MessageStatusUpdate {
  final String messageId;
  final MessageStatus status;
  final DateTime? timestamp;

  MessageStatusUpdate({
    required this.messageId,
    required this.status,
    this.timestamp,
  });

  @override
  String toString() => 'MessageStatusUpdate(id: $messageId, status: $status)';
}
