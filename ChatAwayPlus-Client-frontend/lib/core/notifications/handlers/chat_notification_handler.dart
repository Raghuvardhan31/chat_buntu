// ============================================================================
// CHAT NOTIFICATION HANDLER - Handle Chat Message Notifications
// ============================================================================
// This file handles CHAT-SPECIFIC notification logic.
//
// WHAT GOES HERE:
// 1. Parse chat message from FCM payload
// 2. Save message to local database
// 3. Display notification with chat-specific style
// 4. Handle notification tap → Navigate to chat screen
// 5. Update unread message count
//
// RESPONSIBILITIES:
// - Extract sender name, message text from notification
// - Save message to local DB via chat repository
// - Show notification with sender's profile picture
// - Navigate to specific chat when notification tapped
// - Update badge count for unread messages
//
// TEAM EXAMPLE:
//   await ChatNotificationHandler.handle(fcmMessage);
//   // Parses message, saves to DB, shows notification
//
// FCM PAYLOAD STRUCTURE (from backend):
// {
//   "notification": {
//     "title": "John Doe",
//     "body": "Hey, how are you?"
//   },
//   "data": {
//     "type": "chat_message",
//     "sender_id": "user_123",
//     "message_id": "msg_456",
//     "conversation_id": "conv_789"
//   }
// }
//
// FLOW:
// FCM Message → ChatNotificationHandler → Save to DB → Show Notification
//
// ============================================================================

// TODO: Import fcm_service.dart
// TODO: Import local_notification_service.dart
// TODO: Import chat repository (to save message)
// TODO: Add handle() method to process chat notification
// TODO: Add parseMessageFromFCM() method
// TODO: Add saveChatMessageToDB() method
// TODO: Add showChatNotification() method
// TODO: Add onNotificationTapped() → navigate to chat screen
// TODO: Add updateUnreadCount() method
