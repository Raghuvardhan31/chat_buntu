import 'package:flutter/material.dart';

import '../../../../core/constants/assets/image_assets.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/database/tables/chat/follow_ups_table.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';

class FollowUpsSection extends StatelessWidget {
  const FollowUpsSection({
    super.key,
    required this.followUpEntries,
    required this.isLoading,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.responsive,
    required this.isDark,
    required this.onFollowUpTap,
    this.onFollowUpDelete,
  });

  final List<FollowUpEntry> followUpEntries;
  final bool isLoading;
  final bool isExpanded;
  final void Function(FollowUpEntry entry) onFollowUpTap;
  final void Function(FollowUpEntry entry)? onFollowUpDelete;
  final VoidCallback? onToggleExpanded;
  final ResponsiveSize responsive;
  final bool isDark;

  String _formatDateTime(DateTime dateTime) {
    // Use 12-hour format with AM/PM like one-to-one chat page
    final localTime = dateTime.toLocal();
    final hour = localTime.hour % 12 == 0 ? 12 : localTime.hour % 12;
    final minute = localTime.minute.toString().padLeft(2, '0');
    final ampm = localTime.hour >= 12 ? 'PM' : 'AM';
    final timePart = '$hour:$minute $ampm';

    // Always show actual date for follow-ups to avoid confusion with chat messages
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} $timePart';
  }

  @override
  Widget build(BuildContext context) {
    const followUpPrefix = 'Follow up Text:';
    final subtitleText = isLoading
        ? 'Loading follow-ups...'
        : (followUpEntries.isNotEmpty
              ? '$followUpPrefix ${followUpEntries.first.text}'
              : 'Your follow-up messages with this contact');
    final showExpandedList = isExpanded && followUpEntries.length > 1;
    final iconSize = responsive.size(24);
    final leftInset = iconSize + responsive.spacing(12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(
              ImageAssets.followUpAttachmentIcon,
              width: iconSize,
              height: iconSize,
              fit: BoxFit.contain,
              color: isDark ? Colors.white70 : AppColors.colorGrey,
            ),
            SizedBox(width: responsive.spacing(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Follow-ups',
                    style: AppTextSizes.regular(context).copyWith(
                      color: isDark ? Colors.white : AppColors.colorBlack,
                    ),
                  ),
                  SizedBox(height: responsive.spacing(4)),
                  GestureDetector(
                    onTap: followUpEntries.isNotEmpty && !isExpanded
                        ? () => onFollowUpTap(followUpEntries.first)
                        : null,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                subtitleText,
                                style: AppTextSizes.small(context).copyWith(
                                  color: isDark
                                      ? Colors.white70
                                      : AppColors.colorGrey,
                                ),
                              ),
                              if (followUpEntries.isNotEmpty &&
                                  !isExpanded) ...[
                                SizedBox(height: responsive.spacing(2)),
                                Text(
                                  _formatDateTime(
                                    followUpEntries.first.createdAt,
                                  ),
                                  style: AppTextSizes.small(context).copyWith(
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.grey.shade600,
                                    fontSize: responsive.size(11),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (followUpEntries.isNotEmpty && !isExpanded) ...[
                          GestureDetector(
                            onTap: () => onFollowUpTap(followUpEntries.first),
                            child: Image.asset(
                              ImageAssets.followUpAttachmentIcon,
                              width: responsive.size(16),
                              height: responsive.size(16),
                              color: isDark
                                  ? Colors.blue.shade300
                                  : Colors.blue.shade600,
                            ),
                          ),
                          SizedBox(width: responsive.spacing(8)),
                          GestureDetector(
                            onTap: () {
                              if (onFollowUpDelete != null) {
                                onFollowUpDelete!(followUpEntries.first);
                              }
                            },
                            child: Icon(
                              Icons.delete_rounded,
                              size: responsive.size(16),
                              color: isDark
                                  ? Colors.red.shade300
                                  : Colors.red.shade600,
                            ),
                          ),
                          SizedBox(width: responsive.spacing(4)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (onToggleExpanded != null)
              IconButton(
                onPressed: onToggleExpanded,
                icon: Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: isDark ? Colors.white70 : AppColors.colorGrey,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        if (showExpandedList)
          Padding(
            padding: EdgeInsets.only(
              left:
                  leftInset -
                  responsive.spacing(
                    4,
                  ), // Move boxes slightly left for better centering
              top: responsive.spacing(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: followUpEntries
                  .skip(1)
                  .map(
                    (entry) => Padding(
                      padding: EdgeInsets.only(bottom: responsive.spacing(8)),
                      child: GestureDetector(
                        onTap: () => onFollowUpTap(entry),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: responsive.spacing(8),
                            vertical: responsive.spacing(6),
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              responsive.size(8),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.only(
                                      top: responsive.spacing(1),
                                      right: responsive.spacing(
                                        6,
                                      ), // Move dot slightly right
                                    ),
                                    child: Text(
                                      '•',
                                      style: AppTextSizes.small(context)
                                          .copyWith(
                                            color: isDark
                                                ? Colors.white70
                                                : AppColors.colorGrey,
                                          ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '$followUpPrefix ${entry.text}',
                                      style: AppTextSizes.small(context)
                                          .copyWith(
                                            color: isDark
                                                ? Colors.white70
                                                : AppColors.colorGrey,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: responsive.spacing(2)),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.only(
                                      left: responsive.spacing(
                                        8,
                                      ), // Move timestamp right to align with text above
                                    ),
                                    child: Text(
                                      _formatDateTime(entry.createdAt),
                                      style: AppTextSizes.small(context)
                                          .copyWith(
                                            color: isDark
                                                ? Colors.white54
                                                : Colors.grey.shade600,
                                            fontSize: responsive.size(11),
                                          ),
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      GestureDetector(
                                        onTap: () => onFollowUpTap(entry),
                                        child: Image.asset(
                                          ImageAssets.followUpAttachmentIcon,
                                          width: responsive.size(16),
                                          height: responsive.size(16),
                                          color: isDark
                                              ? Colors.blue.shade300
                                              : Colors.blue.shade600,
                                        ),
                                      ),
                                      SizedBox(width: responsive.spacing(8)),
                                      GestureDetector(
                                        onTap: () {
                                          if (onFollowUpDelete != null) {
                                            onFollowUpDelete!(entry);
                                          }
                                        },
                                        child: Icon(
                                          Icons.delete_rounded,
                                          size: responsive.size(16),
                                          color: isDark
                                              ? Colors.red.shade300
                                              : Colors.red.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}
