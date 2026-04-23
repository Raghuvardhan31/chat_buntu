// lib/features/chat/presentation/pages/individual_chat/widgets/message_selection_overlay.dart

import 'package:flutter/material.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/snackbar/app_snackbar.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/features/chat/models/chat_message_model.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/message_interactions/message_action_bar.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/message_interactions/message_reaction_bar.dart';

/// Overlay widget that appears when a message is long-pressed
/// Shows action bar (edit, forward, copy, delete, etc.) and reaction bar
class MessageSelectionOverlay extends StatelessWidget {
  const MessageSelectionOverlay({
    super.key,
    required this.selectedMessageId,
    required this.selectedEmoji,
    required this.messages,
    required this.currentUserId,
    required this.onClose,
    required this.onEdit,
    required this.onForward,
    required this.onInfo,
    required this.onCopy,
    required this.onStar,
    required this.onDelete,
    required this.onReactionSelected,
  });

  final String selectedMessageId;
  final String? selectedEmoji;
  final List<ChatMessageModel> messages;
  final String? currentUserId;
  final VoidCallback onClose;
  final VoidCallback onEdit;
  final VoidCallback onForward;
  final VoidCallback onInfo;
  final VoidCallback onCopy;
  final VoidCallback onStar;
  final VoidCallback onDelete;
  final ValueChanged<String> onReactionSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ChatMessageModel? selected;
    for (final m in messages) {
      if (m.id == selectedMessageId) {
        selected = m;
        break;
      }
    }

    final canShowInfo =
        selected != null &&
        currentUserId != null &&
        selected.senderId == currentUserId;

    final canEditMessage =
        selected != null &&
        currentUserId != null &&
        selected.senderId == currentUserId &&
        selected.messageType == MessageType.text &&
        selected.message.trim().isNotEmpty &&
        !selected.id.startsWith('local_') &&
        selected.messageStatus != 'sending' &&
        selected.messageStatus != 'pending_sync' &&
        DateTime.now().difference(selected.createdAt) <=
            const Duration(minutes: 15);

    Future<void> handleEditTap() async {
      if (canEditMessage) {
        onEdit();
        return;
      }

      final s = selected;
      if (s == null) return;

      if (currentUserId == null || s.senderId != currentUserId) {
        await AppSnackbar.showWarning(
          context,
          'You can edit only your messages',
        );
        return;
      }

      if (DateTime.now().difference(s.createdAt) >
          const Duration(minutes: 15)) {
        await AppSnackbar.showWarning(
          context,
          'You can edit messages only within 15 minutes.',
        );
        return;
      }

      await AppSnackbar.showWarning(context, 'This message cannot be edited');
    }

    return ResponsiveLayoutBuilder(
      builder: (context, constraints, breakpoint) {
        final responsive = ResponsiveSize(
          context: context,
          constraints: constraints,
          breakpoint: breakpoint,
        );

        return Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(responsive.size(14)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                  blurRadius: responsive.size(10),
                  offset: Offset(0, responsive.spacing(4)),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MessageActionBar(
                  onClose: onClose,
                  onDelete: onDelete,
                  onForward: onForward,
                  onEdit: handleEditTap,
                  onInfo: onInfo,
                  onCopy: onCopy,
                  onStar: onStar,
                  showStar: false,
                  showReact: false,
                  showCopy: false,
                  showInfo: canShowInfo,
                  showEdit: true,
                ),
                Container(
                  height: responsive.size(1),
                  color: isDark ? Colors.white12 : AppColors.greyLight,
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: responsive.spacing(10),
                    vertical: responsive.spacing(8),
                  ),
                  child: MessageReactionBar(
                    onReactionSelected: onReactionSelected,
                    selectedEmoji: selectedEmoji,
                    showContainer: false,
                    padding: EdgeInsets.zero,
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
