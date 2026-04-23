// lib/features/chat/presentation/widgets/message_bubbles/contact_message_bubble.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/features/chat/models/chat_message_model.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/chat_ui/message_delivery_status_icon.dart';
import 'package:chataway_plus/features/chat/utils/chat_helper.dart';

/// Contact sharing message bubble
class ContactMessageBubble extends StatelessWidget {
  const ContactMessageBubble({
    super.key,
    required this.message,
    required this.isSender,
    this.bubbleColor,
    this.showTail = true,
  });

  final ChatMessageModel message;
  final bool isSender;
  final Color? bubbleColor;
  final bool showTail;

  BorderRadius _getBubbleRadius(ResponsiveSize responsive) {
    final radius = responsive.size(16);
    final smallRadius = responsive.size(4);

    if (isSender) {
      return BorderRadius.only(
        topLeft: Radius.circular(radius),
        topRight: Radius.circular(radius),
        bottomLeft: Radius.circular(radius),
        bottomRight: Radius.circular(showTail ? smallRadius : radius),
      );
    } else {
      return BorderRadius.only(
        topLeft: Radius.circular(radius),
        topRight: Radius.circular(radius),
        bottomLeft: Radius.circular(showTail ? smallRadius : radius),
        bottomRight: Radius.circular(radius),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(
      builder: (context, constraints, breakpoint) {
        final responsive = ResponsiveSize(
          context: context,
          constraints: constraints,
          breakpoint: breakpoint,
        );
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final payload = _ContactPayload.fromMessage(message.message);

        // Bubble colors - follow global dark/light theme like text messages
        final defaultBubbleColor = isSender
            ? (isDark ? const Color(0xFF1E3A5F) : AppColors.senderBubble)
            : (isDark ? const Color(0xFF2D2D2D) : AppColors.receiverBubble);

        // Text colors - follow dark/light theme like text messages
        final textColor = isDark ? Colors.white : Colors.black87;
        final secondaryTextColor = isDark
            ? Colors.white70
            : AppColors.colorGrey;

        return Container(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.75),
          decoration: BoxDecoration(
            color: bubbleColor ?? defaultBubbleColor,
            borderRadius: _getBubbleRadius(responsive),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: responsive.spacing(10),
              vertical: responsive.spacing(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person,
                      size: responsive.size(18),
                      color: secondaryTextColor,
                    ),
                    SizedBox(width: responsive.spacing(6)),
                    Flexible(
                      child: Text(
                        payload.name,
                        style: AppTextSizes.regular(context).copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                if (payload.phone != null) ...[
                  SizedBox(height: responsive.spacing(2)),
                  Padding(
                    padding: EdgeInsets.only(left: responsive.spacing(24)),
                    child: Text(
                      payload.phone!,
                      style: AppTextSizes.small(
                        context,
                      ).copyWith(color: secondaryTextColor),
                    ),
                  ),
                ],
                SizedBox(height: responsive.spacing(4)),
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        ChatHelper.formatMessageTime(message.createdAt),
                        style: AppTextSizes.small(context).copyWith(
                          color: secondaryTextColor,
                          fontSize: responsive.size(11),
                        ),
                      ),
                      if (isSender) ...[
                        SizedBox(width: responsive.spacing(4)),
                        MessageDeliveryStatusIcon(
                          status: message.messageStatus,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ContactPayload {
  const _ContactPayload({required this.name, this.phone});

  final String name;
  final String? phone;

  static _ContactPayload fromMessage(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const _ContactPayload(name: 'Shared Contact');
    }

    Map<String, dynamic>? data;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        data = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}

    String? name = data?['name']?.toString();
    name ??= data?['contactName']?.toString();
    name ??= data?['displayName']?.toString();
    name ??= data?['fullName']?.toString();
    name ??= data?['title']?.toString();
    name ??= data?['contact_name']?.toString();

    String? phone = data?['phone']?.toString();
    phone ??= data?['mobile']?.toString();
    phone ??= data?['mobileNo']?.toString();
    phone ??= data?['number']?.toString();
    phone ??= data?['contact_mobile_number']?.toString();

    if (name == null || name.trim().isEmpty) {
      final lines = trimmed
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (lines.isNotEmpty) {
        name = lines.first;
        if (lines.length > 1 && (phone == null || phone.trim().isEmpty)) {
          phone = lines[1];
        }
      }
    }

    final resolvedName = (name == null || name.trim().isEmpty)
        ? 'Shared Contact'
        : name.trim();
    final resolvedPhone = (phone == null || phone.trim().isEmpty)
        ? null
        : phone.trim();

    return _ContactPayload(name: resolvedName, phone: resolvedPhone);
  }
}
