// Core sync configuration
// Centralized TTLs for data freshness across features.

class SyncConfig {
  SyncConfig._();

  // Chat history (per conversation)
  static const Duration chatHistoryTTL = Duration(seconds: 20);

  // Chat list (threads + unread)
  static const Duration chatListTTL = Duration(seconds: 90);

  // Images (disk cache)
  // Controls how long images are considered fresh on disk before revalidation
  static const Duration imageStalePeriod = Duration(days: 30);
  static const int imageCacheMaxObjects = 800;
}
