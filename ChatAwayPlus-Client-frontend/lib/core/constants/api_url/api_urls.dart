class ApiUrls {
  // ========================================
  // BASE URLs (DEVELOPMENT - Mobile Testing)
  // ========================================

  static const String apiBaseUrl = 'http://192.168.1.17:3200/api';
  static const String mediaBaseUrl = 'http://192.168.1.17:3200';
  static const String chatWebSocketUrl = 'ws://192.168.1.17:3200';

  // // ========================================
  // // BASE URLs (PRODUCTION)
  // // ========================================
  //
  // // REST API endpoints base URL
  // static const String apiBaseUrl = 'https://chatawayplus.com/api';
  //
  // /// Static assets (profile pictures, images, etc.)
  // static const String mediaBaseUrl = 'https://chatawayplus.com';
  //
  // /// WebSocket server for real-time chat
  // static const String chatWebSocketUrl = 'wss://chatawayplus.com';

  // ========================================
  // AUTHENTICATION APIs
  // ========================================

  /// User signup
  static const String signup = '$apiBaseUrl/auth/signup';

  /// OTP verification
  static const String verifyOtp = '$apiBaseUrl/auth/verify-otp';

  // ========================================
  // PROFILE APIs
  // ========================================

  /// Get current user profile information
  static const String getCurrentUserProfile = '$apiBaseUrl/users/my-profile';

  /// Update current user profile information
  static const String currentUserProfileUpdate = '$apiBaseUrl/users/profile';

  /// Delete current user profile picture
  static const String deleteCurrentUserProfilePic =
      '$apiBaseUrl/users/profile-pic';

  /// Delete user account
  static const String deleteUser = '$apiBaseUrl/users/delete-user';

  // ========================================
  // CHAT PICTURE LIKES APIs
  // ========================================

  static const String chatPictureLikesToggle =
      '$apiBaseUrl/chat-picture-likes/toggle';
  static const String chatPictureLikesCount =
      '$apiBaseUrl/chat-picture-likes/count';
  static const String chatPictureLikesCheck =
      '$apiBaseUrl/chat-picture-likes/check';
  static const String chatPictureLikesUsers =
      '$apiBaseUrl/chat-picture-likes/users';

  // ========================================
  // CONTACTS APIs
  // ========================================

  /// Check contacts on server
  static const String checkContacts = '$apiBaseUrl/users/check-contacts';

  /// Get contacts updated since timestamp (profile delta sync)
  /// GET /api/users/contacts/updated-since?timestamp={ISO_8601_timestamp}
  static const String getUpdatedContactsSince =
      '$apiBaseUrl/users/contacts/updated-since';

  /// Block user - POST with userId in URL path: /block/{userId}
  static const String blockUsers = '$apiBaseUrl/block';

  /// Unblock user - DELETE with userId in URL path: /block/users/{userId}
  static const String unblockUsers = '$apiBaseUrl/block';

  /// Get all blocked users list - GET
  static const String getBlockedUsers = '$apiBaseUrl/block/list';

  // ========================================
  // CHAT APIs
  // ========================================

  // ------------------------------------------------------------------
  // Mobile chat REST APIs (USED IN APP)
  // ------------------------------------------------------------------

  // Base: /api/mobile/chat
  // Mobile REST chat endpoints used as fallback when WebSocket isn't available.
  static const String mobileChatBase = '$apiBaseUrl/mobile/chat';

  // POST /api/mobile/chat/messages
  // Sends a new message via REST fallback; server persists and may notify receiver.
  static const String mobileSendMessageUrl = '$mobileChatBase/messages';

  // GET /api/mobile/chat/messages/:otherUserId // 1
  // Returns paginated chat history between logged-in user and otherUserId.
  static String mobileGetMessagesWithUserUrl(String otherUserId) =>
      '$mobileChatBase/messages/$otherUserId';

  // POST /api/mobile/chat/messages/sync
  // Pulls new/updated messages since last client sync watermark/state.
  static const String mobileSyncMessagesUrl = '$mobileChatBase/messages/sync';

  // GET /api/mobile/chat/contacts //1
  // Returns list of chat contacts (users you've messaged with) for chat list/inbox.
  static const String mobileChatContactsUrl = '$mobileChatBase/contacts';

  // PUT /api/mobile/chat/messages/read
  // Marks messages as read when user views the conversation (ticks/unread count updates).
  static const String mobileMarkMessagesReadUrl =
      '$mobileChatBase/messages/read';

  // PUT /api/mobile/chat/messages/delivered
  // Marks messages as delivered (receiver acknowledgement) to update delivery status/ticks.
  static const String mobileMarkMessagesDeliveredUrl =
      '$mobileChatBase/messages/delivered';

  // GET /api/mobile/chat/messages/unread/count
  // Returns total unread messages count for the logged-in user (badges/counters).
  static const String mobileUnreadCountUrl =
      '$mobileChatBase/messages/unread/count';

  // GET /api/mobile/chat/messages/search
  // Searches messages (keyword/filter-based search handled by backend controller).
  static const String mobileSearchMessagesUrl =
      '$mobileChatBase/messages/search';

  // DELETE /api/mobile/chat/message/:chatId/delete-type/:deleteType
  // Deletes a message by chatId; deleteType controls delete-for-me vs delete-for-everyone.
  static String mobileDeleteMessageUrl(
    String chatId, {

    String deleteType = 'me',
  }) => '$mobileChatBase/message/$chatId/delete-type/$deleteType';

  // ------------------------------------------------------------------
  // Backend registered but NOT USED / NOT IMPLEMENTED IN APP YET
  // ------------------------------------------------------------------

  // Base: /api/chats
  // Web/standard chat route base (mobile app currently doesn't call this route).
  static const String chatsBase = '$apiBaseUrl/chats';

  // GET /api/chats/history/:userId/:otherUserId
  // Fetches complete conversation history for web/standard chat route.
  // static String webChatHistoryUrl(String userId, String otherUserId) =>
  //     '$chatsBase/history/$userId/$otherUserId';

  // PUT /api/mobile/chat/messages/status-update
  // Bulk/combined status update (delivered+read together); not wired from UI currently.
  static const String mobileBulkStatusUpdateUrl =
      '$mobileChatBase/messages/status-update';

  // POST /api/mobile/chat/messages/status
  // Fetches message status info (sent/delivered/read); not wired from app currently.
  static const String mobileGetMessageStatusUrl =
      '$mobileChatBase/messages/status';

  // ------------------------------------------------------------------
  // Backward-compatible aliases (keep old reference names used across codebase)
  // ------------------------------------------------------------------

  // Base messages path (GET/POST /api/mobile/chat/messages)
  // Alias kept for existing references.
  static const String mobileChatMessages = mobileSendMessageUrl;

  // Get chat history between two users.
  // Alias to mobile messages base.
  static const String getChatHistory = mobileChatMessages;

  // Send message via REST.
  // Alias to mobile send-message URL.
  static const String sendMessage = mobileSendMessageUrl;

  // Get messages with a specific user.
  // Alias to the /messages/:otherUserId builder.
  static String getChatHistoryByUserId(String otherUserId) =>
      mobileGetMessagesWithUserUrl(otherUserId);

  // Sync messages from server.
  // Alias to mobile sync messages URL.
  static const String syncMessages = mobileSyncMessagesUrl;

  // Mark messages as read.
  // Alias to mobile mark-read URL.
  static const String markMessagesAsRead = mobileMarkMessagesReadUrl;

  // Mark messages as delivered.
  // Alias to mobile mark-delivered URL.
  static const String markMessagesAsDelivered = mobileMarkMessagesDeliveredUrl;

  // Delete a message.
  // Alias to mobile delete-message URL builder.
  static String deleteMessage(String chatId, {String deleteType = 'me'}) =>
      mobileDeleteMessageUrl(chatId, deleteType: deleteType);

  // Get chat contacts.
  // Alias to mobile contacts URL.
  static const String getChatContacts = mobileChatContactsUrl;

  // Total unread message count.
  // Alias to mobile unread-count URL.
  static const String getUnreadCount = mobileUnreadCountUrl;

  // Search messages.
  // Alias to mobile search URL.
  static const String searchMessages = mobileSearchMessagesUrl;

  // Bulk status update.
  // Alias to mobile status-update URL.
  static const String messageStatusUpdate = mobileBulkStatusUpdateUrl;

  // Fetch message status info.
  // Alias to mobile get-message-status URL.
  static const String getMessageStatus = mobileGetMessageStatusUrl;

  // Web: full chat history between 2 users.
  // Alias kept for older naming.
  // static String chatsHistory(String userId, String otherUserId) =>
  //     webChatHistoryUrl(userId, otherUserId);

  /// WebSocket chat server URL (alias for backward compatibility)
  static const String chatServerUrl = chatWebSocketUrl;

  // ========================================
  // EMOJI APIs
  // ========================================

  /// Base path for emoji updates
  static const String emojiUpdatesBase = '$apiBaseUrl/emoji-updates';

  /// GET current user's emoji snapshot
  static const String emojiMyCurrent = '$emojiUpdatesBase/my/current';

  /// GET all users' emoji updates
  static const String emojiAllUpdates = '$emojiUpdatesBase/all';

  /// PUT/PATCH - Update emoji (both first time and subsequent updates)
  static String updateEmojiById(String id) => '$emojiUpdatesBase/$id';

  /// DELETE a specific emoji update by server id
  static String deleteEmojiById(String id) => '$emojiUpdatesBase/$id';

  // ========================================
  // NOTIFICATIONS APIs
  // ========================================

  /// Store FCM token for push notifications
  static const String sendingFcmToken = '$apiBaseUrl/users/store-fcm-token';

  // ========================================
  // IN-APP NOTIFICATIONS APIs
  // ========================================

  /// Base path for in-app notifications
  static const String notificationsBase = '$apiBaseUrl/notifications';

  /// GET all notifications for the current user
  static const String getNotifications = notificationsBase;

  /// Mark all notifications as read
  static const String markAllNotificationsRead = '$notificationsBase/read-all';

  /// Mark a specific notification as read (PATCH /api/notifications/:id/read)
  static String markNotificationRead(String id) =>
      '$notificationsBase/$id/read';

  /// Delete a specific notification (DELETE /api/notifications/:id)
  static String deleteNotificationById(String id) => '$notificationsBase/$id';

  // ========================================
  // TODO: FUTURE IMPLEMENTATIONS
  // ========================================
}
