/// Image Assets Constants
///
/// This file contains all image asset paths used in the ChatAway+ app.
/// Using constants helps prevent typos and makes asset management easier.
///
/// Usage Example:
/// ```dart
/// import 'package:chataway_plus/core/constants/assets/image_assets.dart';
///
/// Image.asset(ImageAssets.defaultProfilePicture)
library;

/// ```

class ImageAssets {
  // Base asset paths
  static const String _baseImagePath = 'assets/images';
  static const String _uiPath = '$_baseImagePath/illustrations';
  static const String _backgroundsPath = '$_baseImagePath/backgrounds';
  static const String _placeholdersPath = '$_baseImagePath/placeholders';
  static const String _chatPath = '$_baseImagePath/chat';
  static const String _chatAttachmentsPath = '$_chatPath/attachments';
  static const String _impIconsPath = 'assets/imp_icons';
  static const String _expressHubIconsPath = 'assets/express_hub_icons';

  // ============================================
  // UI IMAGES
  // ============================================
  static const String mobileBankingImage =
      '$_uiPath/otp_visuals/mobile-banking.png';
  static const String otpImage = '$_uiPath/otp_visuals/otp.png';
  // Example: static const String onboardingIllustration = '$_uiPath/onboarding_illustration.png';

  // ============================================
  // BACKGROUND IMAGES
  // ============================================
  static const String chatBackground =
      '$_backgroundsPath/chat/chat_background_image.jpeg';

  // ============================================
  // PLACEHOLDER IMAGES
  // ============================================
  // Example: static const String defaultProfilePicture = '$_placeholdersPath/default_profile.png';

  // ============================================
  // CHAT IMAGES
  // ============================================
  static const String followUpAttachmentIcon =
      '$_chatAttachmentsPath/follow-up.png';
  static const String contactsSharingIcon =
      '$_chatAttachmentsPath/user-hierarchy.png';
  static const String goodNewsTwitterIcon = '$_chatAttachmentsPath/twitter.png';
  static const String syvlIcon = '$_chatAttachmentsPath/love.png';

  // ============================================
  // GENERAL IMAGES
  // ============================================
  static const String appLogo = '$_baseImagePath/app_logo.jpeg';
  static const String appGateLogo = '$_baseImagePath/app_gate-logo.jpeg';
  static const String alignLeft = '$_baseImagePath/align-left.png';
  static const String chatStoriesIcon = '$_impIconsPath/chat-stories.png';

  // ============================================
  // EXPRESS HUB ICONS
  // ============================================
  static const String goingInsideChatIcon =
      '$_expressHubIconsPath/going_inside_chat_icon.png';
  static const String replyMessageIcon =
      '$_expressHubIconsPath/reply_message_icon.png';
  static const String readMoreTextIcon =
      '$_expressHubIconsPath/read_more_text_icon.png';
  static const String addVideoIcon = '$_expressHubIconsPath/add_video_icon.png';

  // ============================================
  // HELPER METHODS
  // ============================================

  /// Get the full path for an image in the ui folder
  static String getUiImage(String imageName) => '$_uiPath/$imageName';

  /// Get the full path for an image in the backgrounds folder
  static String getBackgroundImage(String imageName) =>
      '$_backgroundsPath/$imageName';

  /// Get the full path for an image in the placeholders folder
  static String getPlaceholderImage(String imageName) =>
      '$_placeholdersPath/$imageName';

  /// Get the full path for an image in the root images folder
  static String getGeneralImage(String imageName) =>
      '$_baseImagePath/$imageName';
}
