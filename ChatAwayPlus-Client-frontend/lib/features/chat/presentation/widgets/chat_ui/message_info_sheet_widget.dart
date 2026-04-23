import 'package:flutter/material.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/features/chat/models/chat_message_model.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/chat_ui/message_delivery_status_icon.dart';

class MessageInfoSheetWidget extends StatelessWidget {
  final ChatMessageModel message;

  const MessageInfoSheetWidget({super.key, required this.message});

  static void show(BuildContext context, ChatMessageModel message) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MessageInfoSheetWidget(message: message),
    );
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final yyyy = local.year.toString();
    return '$dd/$mm/$yyyy ${_formatTime(dt)}';
  }

  String _formatTime(DateTime dt) {
    final localTime = dt.toLocal();
    final hour = localTime.hour % 12 == 0 ? 12 : localTime.hour % 12;
    final minute = localTime.minute.toString().padLeft(2, '0');
    final ampm = localTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final responsive = ResponsiveSize(
      context: context,
      constraints: BoxConstraints(maxWidth: width),
      breakpoint: DeviceBreakpoint.fromWidth(width),
    );

    Widget buildRow({
      required Widget leading,
      required String title,
      required DateTime? time,
      required String emptyLabel,
    }) {
      final subtitle = time == null ? emptyLabel : _formatDateTime(time);

      return ListTile(
        leading: SizedBox(
          width: responsive.size(32),
          height: responsive.size(32),
          child: Center(child: leading),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: responsive.size(15),
            fontWeight: FontWeight.w600,
            color: AppColors.iconPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: responsive.size(13),
            fontWeight: FontWeight.w500,
            color: Colors.black54,
          ),
        ),
        dense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: responsive.spacing(16),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(responsive.size(18)),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: responsive.size(12),
              offset: Offset(0, -responsive.spacing(2)),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: responsive.spacing(10)),
            Container(
              width: responsive.size(42),
              height: responsive.size(4),
              decoration: BoxDecoration(
                color: AppColors.greyLight,
                borderRadius: BorderRadius.circular(responsive.size(8)),
              ),
            ),
            SizedBox(height: responsive.spacing(10)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: responsive.spacing(16)),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Message info',
                  style: TextStyle(
                    fontSize: responsive.size(16),
                    fontWeight: FontWeight.w600,
                    color: AppColors.iconPrimary,
                  ),
                ),
              ),
            ),
            SizedBox(height: responsive.spacing(6)),
            buildRow(
              leading: MessageDeliveryStatusIcon(
                status: 'sent',
                size: responsive.size(16),
              ),
              title: 'Sent',
              time: message.createdAt,
              emptyLabel: 'Not available',
            ),
            buildRow(
              leading: MessageDeliveryStatusIcon(
                status: 'delivered',
                size: responsive.size(16),
              ),
              title: 'Delivered',
              time: message.deliveredAt,
              emptyLabel: 'Not delivered yet',
            ),
            buildRow(
              leading: MessageDeliveryStatusIcon(
                status: 'read',
                size: responsive.size(16),
              ),
              title: 'Read',
              time: message.readAt,
              emptyLabel: 'Not read yet',
            ),
            SizedBox(height: responsive.spacing(12)),
          ],
        ),
      ),
    );
  }
}
