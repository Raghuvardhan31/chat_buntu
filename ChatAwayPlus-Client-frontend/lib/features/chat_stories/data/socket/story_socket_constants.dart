/// Socket Event Names for Chat Stories Feature
///
/// All event names used in Socket.IO communication for stories
/// between client and server.
class StorySocketEventNames {
  // ═══════════════════════════════════════════════════════════════════════════
  // EMIT EVENTS (Client → Server)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Create a new story (after uploading media to S3)
  static const String storiesCreate = 'stories:create';

  /// Get stories from all contacts
  static const String storiesGetContacts = 'stories:get-contacts';

  /// Get my own stories with viewer details
  static const String storiesGetMy = 'stories:get-my';

  /// Get a specific user's stories
  static const String storiesGetUser = 'stories:get-user';

  /// Mark a story as viewed
  static const String storiesMarkViewed = 'stories:mark-viewed';

  /// Get list of viewers for a story (owner only)
  static const String storiesGetViewers = 'stories:get-viewers';

  /// Delete a story (owner only)
  static const String storiesDelete = 'stories:delete';

  // ═══════════════════════════════════════════════════════════════════════════
  // LISTEN EVENTS (Server → Client)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Acknowledgment response for all story actions
  static const String storiesAck = 'stories:ack';

  /// New story notification from a contact
  static const String storyCreated = 'story-created';

  /// Story view notification (sent to story owner)
  static const String storyViewed = 'story-viewed';

  /// Story deleted notification
  static const String storyDeleted = 'story-deleted';
}
