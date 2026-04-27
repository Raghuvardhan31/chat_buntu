/// =============================================================================
/// ROUTE NAMES - CHATAWAY+ FLUTTER APPLICATION
/// =============================================================================
///
/// This class contains all route name constants used throughout the app.
/// Using constants prevents typos and makes navigation more maintainable.
///
/// Benefits:
/// - Type safety for route names
/// - Auto-completion in IDE
/// - Easy refactoring of route names
/// - Centralized route management
/// =============================================================================
library;

class RouteNames {
  // Prevent instantiation
  RouteNames._();

  // ================================================
  // Authentication Routes
  // ================================================

  /// Home/Landing page route (shows splash and checks auth status)
  static const String home = '/';

  /// Phone number entry page for OTP verification
  static const String phoneNumberEntry = '/phone-number-entry';

  /// OTP verification page
  static const String otpVerification = '/otp-verification';

  // ================================================
  // Profile Routes
  // ================================================

  /// Current user profile page
  static const String currentUserProfile = '/current-user-profile';

  // ================================================
  // Settings Routes
  // ================================================

  /// Settings main page
  static const String settingsMain = '/settings-main';

  /// Bug report page
  static const String bugReport = '/bug-report';

  /// Block contacts page
  static const String blockContacts = '/block-contacts';

  /// Theme settings page
  static const String themeSettings = '/theme-settings';

  /// About us page
  static const String aboutUs = '/about-us';

  // Chat bubble icons page removed

  // ================================================
  // Main App Routes
  // ================================================

  /// Network connection page - shown when no internet connectivity
  static const String networkConnection = '/network-connection';

  /// Main navigation page - Bottom nav container with Chat List and Stories
  static const String mainNavigation = '/main-navigation';

  /// Chat list page - main messages/conversations view
  static const String chatList = '/chat-list';

  // Contacts Hub route
  static const String contactsHub = '/contacts-hub';

  // Voice Hub - Voice contacts page
  static const String voiceHub = '/voice-hub';

  // Likes Hub - Chat Picture & Voice likes (24h ephemeral)
  static const String likesHub = '/likes-hub';

  // Calling Hub - Contacts list for initiating calls
  static const String callingHub = '/calling-hub';

  // Spots Hub - Location/spots discovery page
  static const String spotsHub = '/spots-hub';

  // My Spots Photos Upload - Upload photos for user's spots
  static const String mySpotsPhotosUpload = '/my-spots-photos-upload';

  // One-to-One Chat - Individual chat page
  static const String oneToOneChat = '/one-to-one-chat';

  // Enhanced One-to-One Chat - Hybrid offline-first chat page
  static const String enhancedOneToOneChat = '/enhanced-one-to-one-chat';

  /// Notification Test Page - For testing enterprise notification system
  static const String notificationTest = '/notification-test';

  // Draggable Test Page - For testing draggable emoji/ball feature
  static const String draggableTest = '/draggable-test';

  /// Meeting page - Group video call
  static const String meeting = '/meeting';

  /// Poll creation page
  static const String createPoll = '/create-poll';

  /// Contact picker page for sharing contacts
  static const String contactPicker = '/contact-picker';

  /// Main chat/contacts page (to be added later)
  static const String contacts = '/contacts';

  /// Chat conversation page (to be added later)
  static const String chat = '/chat';

  /// Settings page (to be added later)
  static const String settings = '/settings';

  /// Profile page (to be added later)
  static const String profile = '/profile';

  /// Join call transition page
  static const String joinCall = '/join-call';

  // ================================================
  // Helper Methods
  // ================================================

  /// Get all available route names (useful for debugging)
  static List<String> get allRoutes => [
    home,
    phoneNumberEntry,
    otpVerification,
    currentUserProfile,
    settingsMain,
    bugReport,
    blockContacts,
    themeSettings,
    networkConnection,
    mainNavigation,
    chatList,
    contactsHub,
    voiceHub,
    likesHub,
    callingHub,
    spotsHub,
    mySpotsPhotosUpload,
    oneToOneChat,
    enhancedOneToOneChat,
    notificationTest,
    draggableTest,
    meeting,
    joinCall,
    createPoll,
    contactPicker,
    contacts,
    chat,
    settings,
    profile,
  ];

  /// Check if a route name is valid
  static bool isValidRoute(String? routeName) {
    return allRoutes.contains(routeName);
  }
}
