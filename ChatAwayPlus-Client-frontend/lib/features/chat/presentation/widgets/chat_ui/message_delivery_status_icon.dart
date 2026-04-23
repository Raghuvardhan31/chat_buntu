// lib/features/chat/presentation/pages/individual_chat/widgets/message_delivery_status_icon.dart

import 'package:flutter/material.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';

/// Widget that displays message delivery status icon
/// Shows different icons for: sending, sent, delivered, read, failed
class MessageDeliveryStatusIcon extends StatelessWidget {
  const MessageDeliveryStatusIcon({
    super.key,
    required this.status,
    this.size,
    this.color,
    this.useChatListStyle = false,
  });

  final String status;
  final double? size;
  final Color? color;
  final bool useChatListStyle;

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(
      builder: (context, constraints, breakpoint) {
        final responsive = ResponsiveSize(
          context: context,
          constraints: constraints,
          breakpoint: breakpoint,
        );

        final baseSize = size ?? responsive.size(16);
        final doubleTickSize = size ?? responsive.size(16);

        switch (status) {
          case 'sending':
          case 'pending_sync':
            return Icon(
              Icons.more_time_sharp,
              size: baseSize,
              color: color ?? AppColors.colorGrey,
            );
          case 'sent':
            return Icon(
              Icons.done,
              size: baseSize,
              color: color ?? const Color(0xFF667781),
            );
          case 'delivered':
            return Icon(
              Icons.done_all,
              size: doubleTickSize,
              color: color ?? const Color(0xFF667781),
            );
          case 'read':
            return Icon(
              Icons.done_all,
              size: doubleTickSize,
              color: color ?? AppColors.primary,
            );
          case 'failed':
            return Icon(
              Icons.error,
              size: baseSize,
              color: color ?? Colors.red,
            );
          default:
            return const SizedBox.shrink();
        }
      },
    );
  }
}

/// Helper function for use in existing code without widget conversion
Widget buildMessageDeliveryStatusIcon(
  BuildContext context,
  String status, {
  double? size,
  Color? color,
}) {
  return MessageDeliveryStatusIcon(status: status, size: size, color: color);
}
