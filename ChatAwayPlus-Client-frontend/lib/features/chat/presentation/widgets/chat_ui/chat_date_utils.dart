// lib/features/chat/presentation/pages/individual_chat/widgets/chat_date_utils.dart

/// Utility class for date/time formatting in chat
class ChatDateUtils {
  ChatDateUtils._();

  /// Format last seen timestamp for display in app bar subtitle
  /// Returns strings like "last seen today at 2:30 PM" or "last seen 25/12/2024 at 10:00 AM"
  static String formatLastSeen(DateTime? lastSeen) {
    if (lastSeen == null) return '';

    final now = DateTime.now();
    final local = lastSeen.toLocal();

    bool isSameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    String formatTime(DateTime dt) {
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final suffix = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $suffix';
    }

    final isToday = isSameDay(local, now);
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = isSameDay(local, yesterday);
    final timeText = formatTime(local);

    if (isToday) {
      return 'last seen today at $timeText';
    } else if (isYesterday) {
      return 'last seen yesterday at $timeText';
    } else {
      final day = local.day.toString().padLeft(2, '0');
      final month = local.month.toString().padLeft(2, '0');
      final year = local.year.toString();
      return 'last seen $day/$month/$year at $timeText';
    }
  }

  /// Format message timestamp for display in bubbles
  /// Returns time in 12-hour format like "2:30 PM"
  static String formatMessageTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  /// Get date label for date dividers
  /// Returns "Today", "Yesterday", or formatted date like "Dec 25, 2024"
  static String getDateLabel(DateTime messageDate) {
    final localMessageDate = messageDate.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDay = DateTime(
      localMessageDate.year,
      localMessageDate.month,
      localMessageDate.day,
    );

    if (messageDay == today) return 'Today';
    if (messageDay == yesterday) return 'Yesterday';

    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[localMessageDate.month - 1]} ${localMessageDate.day}, ${localMessageDate.year}';
  }

  /// Check if two dates are on the same day
  static bool isSameDay(DateTime a, DateTime b) {
    final localA = a.toLocal();
    final localB = b.toLocal();
    return localA.year == localB.year &&
        localA.month == localB.month &&
        localA.day == localB.day;
  }

  /// Check if date divider should be shown between two messages
  static bool shouldShowDateDivider(
    DateTime currentMessageDate,
    DateTime? previousMessageDate,
  ) {
    if (previousMessageDate == null) return true;
    return !isSameDay(currentMessageDate, previousMessageDate);
  }
}
