// ============================================================================
// APP CONFIGURATION - App-wide Constants
// ============================================================================
// Central place for all app-wide configuration values.
//
// WHY NEEDED:
// - Single source of truth for app constants
// - Easy to change values in one place
// - No magic numbers scattered everywhere
//
// USAGE:
//   // Anywhere in app:
//   final appName = AppConfig.appName;
//   final version = AppConfig.appVersion;
//
// ============================================================================

class AppConfig {
  // Prevent instantiation
  AppConfig._();
  
  // =========================================================================
  // APP IDENTITY
  // =========================================================================
  
  /// App name
  static const String appName = 'ChatAway+';
  
  /// App version (update when releasing new version)
  static const String appVersion = '1.0.0';
  
  /// App build number
  static const int buildNumber = 1;
  
  /// Package name
  static const String packageName = 'com.chatawayplus.app';
  
  /// App tagline
  static const String appTagline = 'Connect, Chat, Stay Close';
  
  // =========================================================================
  // API CONFIGURATION
  // =========================================================================
  
  /// API request timeout (use Environment.apiTimeout instead for env-specific)
  static const Duration defaultApiTimeout = Duration(seconds: 30);
  
  /// Max retry attempts for failed API calls
  static const int maxApiRetries = 3;
  
  /// Retry delay (exponential backoff)
  static const Duration retryDelay = Duration(seconds: 2);
  
  // =========================================================================
  // PAGINATION
  // =========================================================================
  
  /// Messages per page when loading chat history
  static const int messagesPerPage = 50;
  
  /// Contacts per page when loading contacts
  static const int contactsPerPage = 100;
  
  // =========================================================================
  // MEDIA CONFIGURATION
  // =========================================================================
  
  /// Max profile picture size (in MB)
  static const double maxProfilePictureSizeMB = 5.0;
  
  /// Profile picture quality (0-100)
  static const int profilePictureQuality = 85;
  
  /// Max image width/height for profile pictures
  static const int maxProfilePictureSize = 1024;
  
  // =========================================================================
  // CHAT CONFIGURATION
  // =========================================================================
  
  /// Auto-save message drafts after this delay
  static const Duration draftSaveDelay = Duration(seconds: 2);
  
  /// Mark message as read after this delay
  static const Duration markAsReadDelay = Duration(milliseconds: 500);
  
  /// Typing indicator timeout
  static const Duration typingIndicatorTimeout = Duration(seconds: 5);
  
  /// Max message length
  static const int maxMessageLength = 5000;
  
  // =========================================================================
  // NOTIFICATION CONFIGURATION
  // =========================================================================
  
  /// Notification channel ID (Android)
  static const String notificationChannelId = 'chat_messages';
  
  /// Notification channel name
  static const String notificationChannelName = 'Chat Messages';
  
  /// Notification sound (Android)
  static const String notificationSound = 'default';
  
  // =========================================================================
  // BACKGROUND SYNC
  // =========================================================================
  
  /// Background sync interval (contacts, profile, etc.)
  static const Duration backgroundSyncInterval = Duration(hours: 6);
  
  /// Sync only on WiFi
  static const bool syncOnlyOnWiFi = true;
  
  // =========================================================================
  // CACHE CONFIGURATION
  // =========================================================================
  
  /// How long to cache contacts before re-syncing
  static const Duration contactsCacheValidity = Duration(hours: 24);
  
  /// How long to cache profile data
  static const Duration profileCacheValidity = Duration(hours: 12);
  
  // =========================================================================
  // UI CONFIGURATION
  // =========================================================================
  
  /// Base screen width for responsive design
  static const double baseScreenWidth = 375.0;
  
  /// Base screen height for responsive design
  static const double baseScreenHeight = 812.0;
  
  /// Default animation duration
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);
  
  /// Snackbar display duration
  static const Duration snackBarDuration = Duration(seconds: 2);
  
  // =========================================================================
  // SECURITY
  // =========================================================================
  
  /// Session timeout (auto-logout after this period of inactivity)
  static const Duration sessionTimeout = Duration(days: 30);
  
  /// Max OTP attempts before blocking
  static const int maxOtpAttempts = 3;
  
  /// OTP resend cooldown
  static const Duration otpResendCooldown = Duration(seconds: 60);
  
  // =========================================================================
  // SUPPORT & LINKS
  // =========================================================================
  
  /// Support email
  static const String supportEmail = 'support@chatawayplus.com';
  
  /// Privacy policy URL
  static const String privacyPolicyUrl = 'https://chatawayplus.com/privacy';
  
  /// Terms of service URL
  static const String termsOfServiceUrl = 'https://chatawayplus.com/terms';
  
  /// Help center URL
  static const String helpCenterUrl = 'https://chatawayplus.com/help';
  
  // =========================================================================
  // DEVELOPER OPTIONS
  // =========================================================================
  
  /// Show performance overlay (dev only)
  static bool get showPerformanceOverlay => false;
  
  /// Enable debug banner
  static bool get showDebugBanner => false;
}
