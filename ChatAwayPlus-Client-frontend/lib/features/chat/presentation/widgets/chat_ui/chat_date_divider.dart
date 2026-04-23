// lib/features/chat/presentation/pages/individual_chat/widgets/chat_date_divider.dart

import 'package:flutter/material.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';

/// Widget that displays date divider between messages on different days
class ChatDateDivider extends StatelessWidget {
  const ChatDateDivider({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ResponsiveLayoutBuilder(
      builder: (context, constraints, breakpoint) {
        final responsive = ResponsiveSize(
          context: context,
          constraints: constraints,
          breakpoint: breakpoint,
        );

        return Padding(
          padding: EdgeInsets.symmetric(vertical: responsive.spacing(16)),
          child: Row(
            children: [
              Expanded(
                child: Divider(
                  color: isDark ? Colors.white24 : Colors.grey[300],
                  thickness: responsive.size(1),
                  endIndent: responsive.spacing(12),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: responsive.spacing(12),
                  vertical: responsive.spacing(6),
                ),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white12 : Colors.grey[200],
                  borderRadius: BorderRadius.circular(responsive.size(12)),
                ),
                child: Text(
                  _getDateLabel(date),
                  style: TextStyle(
                    fontSize: responsive.size(12),
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : Colors.grey[700],
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: isDark ? Colors.white24 : Colors.grey[300],
                  thickness: responsive.size(1),
                  indent: responsive.spacing(12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getDateLabel(DateTime messageDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final localMessageDate = messageDate.toLocal();
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
}
