import 'package:cached_network_image/cached_network_image.dart';
import 'package:chataway_plus/core/constants/api_url/api_urls.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/sync/authenticated_image_cache_manager.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/features/chat/presentation/providers/message_reactions/message_reaction_providers.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';

/// Display widget for message reactions (WhatsApp-style - compact pill)
class MessageReactionDisplay extends ConsumerWidget {
  const MessageReactionDisplay({
    super.key,
    required this.messageId,
    required this.currentUserId,
    this.onReactionTap,
    this.maxReactionsToShow = 3,
  });

  final String messageId;
  final String currentUserId;
  final VoidCallback? onReactionTap;
  final int maxReactionsToShow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupedReactions = ref.watch(groupedReactionsProvider(messageId));

    if (groupedReactions.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final entries = groupedReactions.entries.toList();
    final visibleEntries = entries.take(maxReactionsToShow).toList();
    final totalCount = groupedReactions.values.fold<int>(
      0,
      (sum, group) => sum + group.count,
    );

    return ResponsiveLayoutBuilder(
      builder: (context, constraints, breakpoint) {
        final responsive = ResponsiveSize(
          context: context,
          constraints: constraints,
          breakpoint: breakpoint,
        );

        return GestureDetector(
          onTap: onReactionTap,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: responsive.spacing(4),
              vertical: responsive.spacing(1),
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
              borderRadius: BorderRadius.circular(responsive.size(7)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                  blurRadius: responsive.size(2.5),
                  offset: Offset(0, responsive.spacing(1)),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Display emoji reactions (compact)
                ...visibleEntries.map((entry) {
                  return Text(
                    entry.value.emoji,
                    style: TextStyle(fontSize: responsive.size(14)),
                  );
                }),
                // Show count if more than 1 reaction
                if (totalCount > 1) ...[
                  SizedBox(width: responsive.spacing(2)),
                  Text(
                    '$totalCount',
                    style: TextStyle(
                      fontSize: responsive.size(8),
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? Colors.white70
                          : AppColors.greyTextSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Widget to show all reactions with user details
class MessageReactionDetailsSheet extends ConsumerWidget {
  const MessageReactionDetailsSheet({
    super.key,
    required this.messageId,
    required this.currentUserId,
  });

  final String messageId;
  final String currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupedReactions = ref.watch(groupedReactionsProvider(messageId));

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ResponsiveLayoutBuilder(
      builder: (context, constraints, breakpoint) {
        final responsive = ResponsiveSize(
          context: context,
          constraints: constraints,
          breakpoint: breakpoint,
        );

        return Container(
          padding: EdgeInsets.all(responsive.spacing(16)),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(responsive.size(16)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                'Reactions',
                style: AppTextSizes.custom(
                  context,
                  18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: responsive.spacing(16)),

              // Reactions grouped by emoji
              ...groupedReactions.entries.map((entry) {
                final emoji = entry.key;
                final group = entry.value;

                return Padding(
                  padding: EdgeInsets.only(bottom: responsive.spacing(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Emoji header
                      Row(
                        children: [
                          Text(
                            emoji,
                            style: TextStyle(fontSize: responsive.size(24)),
                          ),
                          SizedBox(width: responsive.spacing(8)),
                          Text(
                            '${group.count}',
                            style: AppTextSizes.custom(
                              context,
                              16,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white70
                                  : AppColors.greyTextSecondary,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: responsive.spacing(8)),

                      // Users who reacted
                      ...group.reactions.map((reaction) {
                        final isCurrentUser = reaction.userId == currentUserId;
                        final userName = isCurrentUser
                            ? 'You'
                            : '${reaction.userFirstName ?? ''} ${reaction.userLastName ?? ''}'
                                  .trim();

                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: responsive.spacing(6),
                            left: responsive.spacing(8),
                          ),
                          child: Row(
                            children: [
                              // User avatar with cached image loading
                              _buildUserAvatar(
                                context,
                                reaction.userChatPicture,
                                userName,
                                responsive.size(16),
                                responsive,
                                isDark,
                              ),
                              SizedBox(width: responsive.spacing(12)),

                              // User name
                              Text(
                                userName.isEmpty ? 'Unknown' : userName,
                                style: AppTextSizes.custom(
                                  context,
                                  14,
                                  fontWeight: isCurrentUser
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isCurrentUser
                                      ? AppColors.primary
                                      : (isDark
                                            ? Colors.white
                                            : AppColors.greyTextPrimary),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  /// Build user avatar with cached network image
  Widget _buildUserAvatar(
    BuildContext context,
    String? chatPictureUrl,
    String userName,
    double radius,
    ResponsiveSize responsive,
    bool isDark,
  ) {
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
      child: Text(
        userName.isNotEmpty ? userName[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: radius * 0.9,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white70 : Colors.grey.shade600,
        ),
      ),
    );

    // No URL - show fallback
    if (chatPictureUrl == null || chatPictureUrl.isEmpty) {
      return fallback;
    }

    // Build full URL (prepend base URL if needed)
    final fullUrl = chatPictureUrl.startsWith('http')
        ? chatPictureUrl
        : '${ApiUrls.mediaBaseUrl}$chatPictureUrl';

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: fullUrl,
        cacheManager: AuthenticatedImageCacheManager.instance,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        placeholder: (context, url) => CircleAvatar(
          radius: radius,
          backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          child: SizedBox(
            width: radius,
            height: radius,
            child: CircularProgressIndicator(
              strokeWidth: responsive.size(2),
              color: AppColors.primary,
            ),
          ),
        ),
        errorWidget: (context, url, error) {
          if (kDebugMode) {
            debugPrint('❌ Avatar load error: $error for $url');
          }
          return fallback;
        },
      ),
    );
  }

  static void show(
    BuildContext context,
    String messageId,
    String currentUserId,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => MessageReactionDetailsSheet(
        messageId: messageId,
        currentUserId: currentUserId,
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }
}
