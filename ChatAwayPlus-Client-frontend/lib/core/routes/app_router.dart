import 'package:chataway_plus/features/settings/presentation/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:chataway_plus/features/profile/presentation/pages/current_user_profile_page.dart';
import 'package:chataway_plus/features/connection_insight_hub/presentation/pages/connection_insight_hub_page.dart';
import 'package:chataway_plus/core/routes/route_names.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/features/poll_hub/presentation/pages/poll_hub_page.dart';
import 'package:chataway_plus/features/chat/presentation/pages/contact_picker/contact_picker_page.dart';

import '../../features/settings/widgets/bug_report_page.dart';
import '../../features/settings/widgets/about_us_page.dart';
import '../../features/blocked_contacts/presentation/pages/blocked_contacts_page.dart';
import '../../features/Express_hub/presentation/pages/express_hub_page.dart';
import '../../features/likes_hub/presentation/pages/likes_hub_page.dart';
import '../../features/theme/presentation/pages/theme_settings_page.dart';
import '../../features/chat/presentation/pages/chat_list/chat_list_page.dart';
import '../../features/auth/presentation/pages/otp_verification_page.dart';
import '../../features/auth/presentation/pages/phone_number_entry_page.dart';
import '../../features/contacts/presentation/pages/contacts_hub_page.dart';
import '../../features/chat/presentation/pages/onetoone_chat/one_to_one_chat_page.dart';
import '../../features/navigation/presentation/pages/main_navigation_page.dart';
import '../../features/voice_call/presentation/pages/calling_hub_page.dart';
import '../../features/voice_call/presentation/pages/meeting_page.dart';
import 'package:chataway_plus/features/app_gate/presentation/app_gate_page.dart';

/// =============================================================================
/// APP ROUTER - CHATAWAY+ FLUTTER APPLICATION
/// =============================================================================
///
/// This class handles all route generation and navigation logic for the app.
/// It provides centralized routing with proper error handling and type safety.
///
/// Features:
/// - Centralized route management
/// - Type-safe navigation with arguments
/// - Custom error page for unknown routes
/// - Clean separation of routing logic
/// =============================================================================

class AppRouter {
  /// Generates routes based on RouteSettings
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case RouteNames.home: // This is '/' - App startup gate
        return _buildRoute(const AppGatePage(), settings);

      case RouteNames.phoneNumberEntry:
        return _buildRoute(const PhoneNumberEntryPage(), settings);

      case RouteNames.otpVerification:
        // Extract mobile number from arguments
        final String? mobileNumber = settings.arguments as String?;

        if (mobileNumber == null) {
          debugPrint('❌ AppRouter: Missing mobile number for OTP verification');
          return _errorRoute('Missing mobile number parameter');
        }

        return _buildRoute(
          OtpverificationPage(mobileNo: mobileNumber),
          settings,
        );

      case RouteNames.currentUserProfile:
        return _buildRoute(const CurrentUserProfilePage(), settings);
      case RouteNames.profile:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        final contactName = args['contactName'] as String? ?? 'Profile';
        final contactId = args['contactId'] as String? ?? '';
        final chatPictureUrl =
            (args['chatPictureUrl'] as String?) ??
            (args['profile'
                    'PicUrl']
                as String?);
        final mobileNumber = args['mobileNumber'] as String? ?? '';
        return _buildRoute(
          ConnectionInsightHubPage(
            contactName: contactName,
            contactId: contactId,
            mobileNumber: mobileNumber,
            chatPictureUrl: chatPictureUrl,
          ),
          settings,
        );
      case RouteNames.settingsMain:
        return _buildRoute(const SettingsPage(), settings);
      case RouteNames.bugReport:
        return _buildRoute(const BugReportPage(), settings);
      case RouteNames.blockContacts:
        return _buildRoute(const BlockedContactsPage(), settings);
      case RouteNames.themeSettings:
        return _buildRoute(const ThemeSettingsPage(), settings);
      case RouteNames.aboutUs:
        return _buildRoute(const AboutUsPage(), settings);
      case RouteNames.voiceHub:
        return _buildRoute(const VoiceHubPage(), settings);
      case RouteNames.callingHub:
        return _buildRoute(const CallingHubPage(), settings);

      case RouteNames.contactsHub:
        return _buildRoute(const ContactsHubPage(), settings);
      case RouteNames.likesHub:
        return _buildRoute(const LikesHubPage(), settings);
      case RouteNames.mainNavigation:
        return _buildRoute(const MainNavigationPage(), settings);
      case RouteNames.chatList:
        return _buildRoute(const ChatListPage(), settings);
      case RouteNames.draggableTest:
        return _buildRoute(const CurrentUserProfilePage(), settings);
      case RouteNames.createPoll:
        return _buildRoute(const PollHubPage(), settings);
      case RouteNames.contactPicker:
        return _buildRoute(const ContactPickerPage(), settings);
      case RouteNames.meeting:
        final args = settings.arguments as Map<String, dynamic>?;
        if (args == null ||
            !args.containsKey('meetingId') ||
            !args.containsKey('currentUserId')) {
          return _errorRoute('Missing meeting information');
        }
        return _buildRoute(
          MeetingPage(
            meetingId: args['meetingId'] as String,
            currentUserId: args['currentUserId'] as String,
            initialMeetingTitle: args['initialMeetingTitle'] as String?,
          ),
          settings,
        );
      case RouteNames.oneToOneChat:
        // Extract contact info from arguments
        final args = settings.arguments as Map<String, dynamic>?;

        if (args == null ||
            !args.containsKey('contactName') ||
            !args.containsKey('receiverId') ||
            !args.containsKey('currentUserId')) {
          debugPrint(
            '❌ AppRouter: Missing required arguments for individual chat',
          );
          return _errorRoute('Missing contact information');
        }

        final page = OneToOneChatPage(
          contactName: args['contactName'] as String,
          receiverId: args['receiverId'] as String,
          currentUserId: args['currentUserId'] as String,
          storyReply: args['storyReply'] as bool?,
          storyReplyText: args['storyReplyText'] as String?,
          autoFocusInput: args['autoFocusInput'] as bool?,
          expressHubReplyText: args['expressHubReplyText'] as String?,
          expressHubReplyType: args['expressHubReplyType'] as String?,
        );

        return _slideFromLeftRoute(page, settings);

      case RouteNames.enhancedOneToOneChat:
        // Extract contact info from arguments (same as oneToOneChat)
        final enhancedArgs = settings.arguments as Map<String, dynamic>?;

        if (enhancedArgs == null ||
            !enhancedArgs.containsKey('contactName') ||
            !enhancedArgs.containsKey('receiverId') ||
            !enhancedArgs.containsKey('currentUserId')) {
          debugPrint(
            '❌ AppRouter: Missing required arguments for enhanced chat',
          );
          return _errorRoute('Missing contact information');
        }

        final enhancedPage = OneToOneChatPage(
          contactName: enhancedArgs['contactName'] as String,
          receiverId: enhancedArgs['receiverId'] as String,
          currentUserId: enhancedArgs['currentUserId'] as String,
        );

        return _slideFromLeftRoute(enhancedPage, settings);

      default:
        debugPrint('❌ AppRouter: Unknown route: ${settings.name}');
        return _errorRoute('Page not found');
    }
  }

  // TODO: Uncomment tomorrow when routes are ready
  /// Helper method to build routes with consistent configuration
  static Route<T> _buildRoute<T>(Widget page, RouteSettings settings) {
    return MaterialPageRoute<T>(builder: (context) => page, settings: settings);
  }

  static Route<T> _slideFromLeftRoute<T>(Widget page, RouteSettings settings) {
    return PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween<Offset>(
          begin: const Offset(-1.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));

        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
  }

  /// Creates a standardized error route for unknown pages
  static Route<dynamic> _errorRoute([String? errorMessage]) {
    return MaterialPageRoute(
      builder: (context) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Error',
              style: TextStyle(
                fontSize: 20.0,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            backgroundColor: AppColors.error,
            elevation: 0,
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(
                    errorMessage ?? 'Page not found!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        RouteNames.home,
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'Go Home',
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
