// lib/features/chat/utils/chat_helper.dart

import 'package:chataway_plus/core/storage/token_storage.dart';

/// Helper class for chat-related utilities
class ChatHelper {
  static final TokenSecureStorage _tokenStorage = TokenSecureStorage.instance;

  /// Get current user ID from secure storage
  /// Returns null if not found
  static Future<String?> getCurrentUserId() async {
    try {
      // Get user ID UUID from token storage (saved during OTP verification)
      final userId = await _tokenStorage.getCurrentUserIdUUID();
      return userId;
    } catch (e) {
      print('ChatHelper: Error getting user ID: $e');
      return null;
    }
  }

  /// Get auth token from secure storage
  static Future<String?> getAuthToken() async {
    try {
      final token = await _tokenStorage.getToken();
      return token;
    } catch (e) {
      print('ChatHelper: Error getting auth token: $e');
      return null;
    }
  }

  /// Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    final token = await getAuthToken();
    return token != null && token.isNotEmpty;
  }

  /// Format time for message display (e.g., "3:45 PM")
  static String formatMessageTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  /// Format date for message display (e.g., "Today", "Yesterday", "Jan 15")
  static String formatMessageDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final difference = today.difference(messageDate).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      final weekday = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekday[dateTime.weekday - 1];
    } else {
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[dateTime.month - 1]} ${dateTime.day}';
    }
  }

  /// Get initials from name (e.g., "John Doe" → "JD")
  static String getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }
}
