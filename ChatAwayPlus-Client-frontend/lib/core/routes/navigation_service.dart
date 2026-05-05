import 'package:flutter/material.dart';
import 'package:chataway_plus/core/routes/route_names.dart';

/// =============================================================================
/// NAVIGATION SERVICE - CHATAWAY+ FLUTTER APPLICATION
/// =============================================================================
///
/// This service provides convenient methods for navigation throughout the app.
/// It encapsulates common navigation patterns and provides type-safe methods.
///
/// Features:
/// - Global navigation key access
/// - Convenient navigation methods
/// - Type-safe parameter passing
/// - Centralized navigation logic
/// =============================================================================

class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static NavigatorState? get _nav => navigatorKey.currentState;
  static BuildContext? get currentContext => navigatorKey.currentContext;

  static Future<void> goToPhoneNumberEntry() async {
    await _nav?.pushReplacementNamed(RouteNames.phoneNumberEntry);
  }

  static Future<void> goToOtpVerification(String mobileNumber) async {
    debugPrint(
      '🚀 NavigationService.goToOtpVerification called with: $mobileNumber',
    );
    debugPrint(
      '🔑 NavigatorKey is ${navigatorKey.currentState == null ? "NULL" : "VALID"}',
    );
    debugPrint('🔑 Navigator instance: $_nav');

    if (_nav == null) {
      debugPrint('❌ ERROR: Navigator is NULL! Cannot navigate!');
      debugPrint(
        '💡 TIP: Make sure MaterialApp has navigatorKey: NavigationService.navigatorKey',
      );
      return;
    }

    debugPrint(
      '✅ Calling pushReplacementNamed to: ${RouteNames.otpVerification}',
    );
    await _nav?.pushReplacementNamed(
      RouteNames.otpVerification,
      arguments: mobileNumber,
    );
    debugPrint(
      '✅ Navigation completed - PhoneNumberEntryPage should be disposed',
    );
  }

  static Future<void> goToCurrentUserProfile({bool fromOtp = false}) async {
    await _nav?.pushReplacementNamed(
      RouteNames.currentUserProfile,
      arguments: {'fromOtp': fromOtp},
    );
  }

  static Future<void> goToNetworkAwareWrapper() async {
    await _nav?.pushReplacementNamed(RouteNames.networkConnection);
  }

  static Future<void> goToSettingsMain() async {
    await _nav?.pushReplacementNamed(RouteNames.settingsMain);
  }

  static Future<void> goToBugReport() async {
    await _nav?.pushNamed(RouteNames.bugReport);
  }

  static Future<void> goToBlockContacts() async {
    await _nav?.pushNamed(RouteNames.blockContacts);
  }

  static Future<void> goToCallingHub() async {
    await _nav?.pushNamed(RouteNames.callingHub);
  }

  static Future<void> goToThemeSettings() async {
    await _nav?.pushNamed(RouteNames.themeSettings);
  }

  static Future<void> goToAboutUs() async {
    await _nav?.pushNamed(RouteNames.aboutUs);
  }

  static Future<void> goToChatList() async {
    await _nav?.pushNamedAndRemoveUntil(
      RouteNames.mainNavigation,
      (route) => false,
    );
  }

  static Future<void> goToContactsHub() async {
    await _nav?.pushReplacementNamed(RouteNames.contactsHub);
  }

  static Future<void> goToVoiceHub() async {
    await _nav?.pushReplacementNamed(RouteNames.voiceHub);
  }

  static Future<void> goToLikesHub() async {
    await _nav?.pushReplacementNamed(RouteNames.likesHub);
  }

  static Future<void> goToSpotsHub() async {
    await _nav?.pushReplacementNamed(RouteNames.spotsHub);
  }

  static Future<void> goToIndividualChat({
    required String contactName,
    required String receiverId,
    required String currentUserId,
    String? expressHubReplyText,
    String? expressHubReplyType,
  }) async {
    await _nav?.pushNamed(
      RouteNames.oneToOneChat,
      arguments: {
        'contactName': contactName,
        'receiverId': receiverId,
        'currentUserId': currentUserId,
        if (expressHubReplyText != null)
          'expressHubReplyText': expressHubReplyText,
        if (expressHubReplyType != null)
          'expressHubReplyType': expressHubReplyType,
      },
    );
  }

  /// Navigate to enhanced one-to-one chat (used for notifications)
  /// Ensures we're on chat list first, then navigates to individual chat
  static Future<void> goToEnhancedOneToOneChat({
    required String contactName,
    required String receiverId,
    required String currentUserId,
  }) async {
    debugPrint('');
    debugPrint('🚀 ═══════════════════════════════════════════════════════');
    debugPrint('🚀 NavigationService.goToEnhancedOneToOneChat CALLED');
    debugPrint('🚀 ═══════════════════════════════════════════════════════');
    debugPrint('   📱 Contact: $contactName');
    debugPrint('   👤 Receiver: $receiverId');
    debugPrint('   👤 Current User: $currentUserId');
    debugPrint('   🔑 Navigator key exists: ${_nav != null}');

    if (_nav == null) {
      debugPrint('❌ ERROR: Navigator is NULL! Cannot navigate!');
      return;
    }

    debugPrint('Step 1: Navigating to main navigation (clearing stack)...');
    await _nav?.pushNamedAndRemoveUntil(
      RouteNames.mainNavigation,
      (route) => false,
    );
    debugPrint('✅ Step 1 complete: On chat list');

    debugPrint('Step 2: Waiting 300ms for chat list to initialize...');
    await Future.delayed(const Duration(milliseconds: 300));
    debugPrint('✅ Step 2 complete: Wait finished');

    debugPrint('Step 3: Pushing individual chat screen...');
    await _nav?.pushNamed(
      RouteNames.oneToOneChat,
      arguments: {
        'contactName': contactName,
        'receiverId': receiverId,
        'currentUserId': currentUserId,
      },
    );
    debugPrint('✅ Step 3 complete: Individual chat pushed');

    debugPrint('✅ ═══════════════════════════════════════════════════════');
    debugPrint('✅ NAVIGATION COMPLETED SUCCESSFULLY');
    debugPrint('✅ ═══════════════════════════════════════════════════════');
    debugPrint('');
  }

  static Future<void> goToMySpotsPhotosUpload({
    required String spotName,
    String? spotDescription,
  }) async {
    await _nav?.pushNamed(
      RouteNames.mySpotsPhotosUpload,
      arguments: {'spotName': spotName, 'spotDescription': spotDescription},
    );
  }

  static Future<void> goToDraggableTest() async {
    await _nav?.pushNamed(RouteNames.draggableTest);
  }

  static Future<void> goToGroupCreateSelectMembers() async {
    await _nav?.pushNamed(RouteNames.groupCreateSelectMembers);
  }

  /// Navigate to enhanced group chat (used for notifications)
  /// Ensures we're on chat list first, then navigates to group chat
  static Future<void> goToEnhancedGroupChat({
    required String groupId,
    String? groupName,
    String? groupIcon,
  }) async {
    debugPrint('🚀 [Navigation] goToEnhancedGroupChat CALLED for $groupId');
    if (_nav == null) return;

    debugPrint('Step 1: Navigating to main navigation (clearing stack)...');
    await _nav?.pushNamedAndRemoveUntil(
      RouteNames.mainNavigation,
      (route) => false,
    );

    debugPrint('Step 2: Waiting 300ms for chat list to initialize...');
    await Future.delayed(const Duration(milliseconds: 300));

    debugPrint('Step 3: Pushing group chat screen...');
    await _nav?.pushNamed(
      RouteNames.groupChat,
      arguments: {
        'groupId': groupId,
        'groupName': groupName,
        'groupIcon': groupIcon,
      },
    );
    debugPrint('✅ [Navigation] Group chat pushed');
  }

  static Future<void> goToHome() async {
    await _nav?.pushNamedAndRemoveUntil(RouteNames.home, (route) => false);
  }

  static void goBack() {
    _nav?.maybePop();
  }

  static void goBackWithResult<T>(T result) {
    if (_nav?.canPop() == true) {
      _nav?.pop(result);
    }
  }

  static Future<T?> pushNamed<T extends Object?>(
    String routeName, {
    Object? arguments,
  }) {
    return _nav?.pushNamed<T>(routeName, arguments: arguments) ??
        Future.value(null);
  }

  static Future<T?> pushReplacementNamed<T extends Object?>(
    String routeName, {
    Object? arguments,
  }) {
    return _nav?.pushReplacementNamed<T, void>(
          routeName,
          arguments: arguments,
        ) ??
        Future.value(null);
  }

  static Future<T?> pushNamedAndRemoveUntil<T extends Object?>(
    String routeName,
    bool Function(Route<dynamic>) predicate, {
    Object? arguments,
  }) {
    return _nav?.pushNamedAndRemoveUntil<T>(
          routeName,
          predicate,
          arguments: arguments,
        ) ??
        Future.value(null);
  }

  static bool canPop() => _nav?.canPop() ?? false;

  static String? getCurrentRouteName() {
    String? currentRouteName;
    _nav?.popUntil((route) {
      currentRouteName = route.settings.name;
      return true;
    });
    return currentRouteName;
  }
}
