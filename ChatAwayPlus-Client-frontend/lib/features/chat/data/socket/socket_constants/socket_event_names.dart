/// Socket Event Names - Constants for WebSocket communication
///
/// All event names used in Socket.IO communication between client and server
class SocketEventNames {
  // Authentication events
  static const String authenticate = 'authenticate';
  static const String authenticated = 'authenticated';
  static const String authenticationError = 'authentication_error';
  static const String invalidToken = 'invalid-token';
  static const String authError = 'auth-error';
  static const String forceDisconnect = 'force-disconnect';

  // Message events
  static const String privateMessage = 'private-message';
  static const String newMessage = 'new-message';
  static const String messageSent = 'message-sent';
  static const String messageError = 'message-error';

  // Message editing events
  static const String editMessage = 'edit-message';
  static const String messageEdited = 'message-edited';
  static const String editMessageError = 'edit-message-error';

  // Message deletion events
  static const String deleteMessage = 'delete-message';
  static const String deleteMessageError = 'delete-message-error';
  static const String messageDeleted = 'message-deleted';

  // Message status events
  static const String updateMessageStatus = 'update-message-status';
  static const String messageStatusUpdate = 'message-status-update';
  static const String statusUpdateError = 'status-update-error';
  static const String statusUpdateAcknowledged = 'status-update-acknowledged';

  // Acknowledgment events
  static const String messageReceivedAck = 'message-received-ack';
  static const String ackAcknowledged = 'ack-acknowledged';
  static const String ackError = 'ack-error';

  // Reaction events
  static const String addReaction = 'add-reaction';
  static const String removeReaction = 'remove-reaction';
  static const String getMessageReactions = 'get-message-reactions';
  static const String reactionUpdated = 'reaction-updated';
  static const String reactionError = 'reaction-error';
  static const String messageReactions = 'message-reactions';

  // Starred messages events
  static const String starMessage = 'star-message';
  static const String unstarMessage = 'unstar-message';
  static const String messageStarred = 'message-starred';
  static const String messageUnstarred = 'message-unstarred';
  static const String starMessageError = 'star-message-error';
  static const String unstarMessageError = 'unstar-message-error';

  // User status events
  static const String userStatusChanged = 'user-status-changed';
  static const String userStatusResponse = 'user-status-response';
  static const String getUserStatus = 'get-user-status';
  static const String setUserPresence = 'set-user-presence';
  static const String presenceAcknowledged = 'presence-acknowledged';

  // Typing indicator events
  static const String typing = 'typing';
  static const String userTyping = 'user-typing';

  // Chat activity events
  static const String chatActivityUpdated = 'chat-activity-updated';

  // Chat room events
  static const String enterChat = 'enter-chat';
  static const String leaveChat = 'leave-chat';

  // Profile events
  static const String profileUpdated = 'profile-updated';

  // Notification events
  static const String notification = 'notification';
  static const String nextNotification = 'next-notification';
  static const String newNotification = 'new_notification';
  static const String reactionAdded = 'reaction_added';

  // Chat picture like events
  static const String toggleChatPictureLike = 'toggle-chat-picture-like';
  static const String getChatPictureLikeCount = 'get-chat-picture-like-count';
  static const String getChatPictureLikers = 'get-users-who-liked';
  static const String checkChatPictureLiked = 'check-chat-picture-like-status';
  static const String chatPictureLikeError = 'chat-picture-like-error';
  static const String chatPictureLikeToggled = 'chat-picture-like-toggled';
  static const String chatPictureLikeCount = 'chat-picture-like-count';
  static const String chatPictureLikers = 'users-who-liked';
  static const String chatPictureLikedStatus = 'chat-picture-like-status';

  // Poll vote events
  static const String pollAddVote = 'poll-add-vote';
  static const String pollRemoveVote = 'poll-remove-vote';
  static const String pollVoteData = 'poll-vote-data';
  static const String pollError = 'poll-error';

  // Status like events (Share Your Voice Text likes)
  static const String toggleStatusLike = 'toggle-status-like';
  static const String statusLikeToggled = 'status-like-toggled';
  static const String unlikeStatus = 'unlike-status';
  static const String statusUnliked = 'status-unliked';
  static const String getStatusLikeCount = 'get-status-like-count';
  static const String statusLikeCount = 'status-like-count';
  static const String checkStatusLikeStatus = 'check-status-like-status';
  static const String statusLikeStatus = 'status-like-status';
  static const String statusLikeError = 'status-like-error';

  // Call signaling events
  static const String callInitiate = 'call-initiate';
  static const String callAccept = 'call-accept';
  static const String callReject = 'call-reject';
  static const String callEnd = 'call-end';
  static const String callBusy = 'call-busy';
  static const String callIncoming = 'call-incoming';
  static const String callAccepted = 'call-accepted';
  static const String callRejected = 'call-rejected';
  static const String callEnded = 'call-ended';
  static const String callUnavailable = 'call-unavailable';
  static const String callRinging = 'call-ringing';
  static const String callError = 'call-error';
  static const String callMissed = 'call-missed';
}
