import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/constants/assets/image_assets.dart';
import 'package:chataway_plus/core/constants/feature_tips_info/profile_tips/profile_feature_tips.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/features/chat/presentation/providers/chat_list_providers/chat_list_provider.dart';
import 'package:chataway_plus/core/routes/navigation_service.dart';

class ChatListEmptyState extends StatelessWidget {
  final ResponsiveSize responsive;
  final bool showMoodEmojiTip;
  final bool moodEmojiTipDismissalLoaded;
  final Widget? moodTipLeading;
  final VoidCallback? onDismissTip;

  const ChatListEmptyState({
    super.key,
    required this.responsive,
    this.showMoodEmojiTip = false,
    this.moodEmojiTipDismissalLoaded = false,
    this.moodTipLeading,
    this.onDismissTip,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    ImageAssets.appGateLogo,
                    width: responsive.size(110),
                    height: responsive.size(110),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.chat_bubble_outline,
                        size: responsive.size(110),
                        color: AppColors.primary,
                      );
                    },
                  ),
                  SizedBox(height: responsive.spacing(16)),
                  Text(
                    'Thank you for choosing ChatAway+',
                    style: AppTextSizes.regular(context).copyWith(
                      color: isDark ? Colors.white : AppColors.colorBlack,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: responsive.spacing(8)),
                  Text(
                    'Start connecting with people from your contacts hub',
                    style: AppTextSizes.small(context).copyWith(
                      color: isDark ? Colors.white54 : AppColors.colorGrey,
                    ),
                  ),
                  SizedBox(height: responsive.spacing(24)),
                  GestureDetector(
                    onTap: () => NavigationService.goToContactsHub(),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: responsive.spacing(24),
                        vertical: responsive.spacing(12),
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(
                          responsive.size(24),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.contacts_outlined,
                            color: Colors.white,
                            size: responsive.size(18),
                          ),
                          SizedBox(width: responsive.spacing(8)),
                          Text(
                            'Open Contacts Hub',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: responsive.size(14),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (moodEmojiTipDismissalLoaded && showMoodEmojiTip)
              Positioned(
                left: constraints.maxWidth * 0.05,
                right: constraints.maxWidth * 0.05,
                bottom: responsive.spacing(120),
                child: TipCard(
                  data: FeatureTips.moodEmojiCard,
                  style: FeatureTips.tipCardStyle,
                  responsive: responsive,
                  leading: moodTipLeading,
                  onClose: onDismissTip,
                ),
              ),
          ],
        );
      },
    );
  }
}

class ChatListNoSearchResults extends StatelessWidget {
  final ResponsiveSize responsive;

  const ChatListNoSearchResults({super.key, required this.responsive});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: responsive.size(80),
            color: isDark ? Colors.white54 : Colors.grey[400],
          ),
          SizedBox(height: responsive.spacing(16)),
          Text(
            'No chats found',
            style: AppTextSizes.regular(context).copyWith(
              color: isDark ? Colors.white : AppColors.colorBlack,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: responsive.spacing(8)),
          Text(
            'Try searching with a different name',
            style: AppTextSizes.small(
              context,
            ).copyWith(color: isDark ? Colors.white54 : AppColors.colorGrey),
          ),
        ],
      ),
    );
  }
}

class ChatListErrorState extends ConsumerWidget {
  final ResponsiveSize responsive;
  final String errorMessage;

  const ChatListErrorState({
    super.key,
    required this.responsive,
    required this.errorMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: responsive.spacing(32)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: responsive.size(80),
              color: Colors.red[300],
            ),
            SizedBox(height: responsive.spacing(16)),
            Text(
              'Oops! Something went wrong',
              style: AppTextSizes.regular(context).copyWith(
                color: isDark ? Colors.white : AppColors.colorBlack,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: responsive.spacing(12)),
            Text(
              errorMessage,
              style: AppTextSizes.small(
                context,
              ).copyWith(color: isDark ? Colors.white54 : AppColors.colorGrey),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: responsive.spacing(24)),
            ElevatedButton.icon(
              onPressed: () {
                ref
                    .read(chatListNotifierProvider.notifier)
                    .forceRefreshContacts(forceServer: true);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: responsive.spacing(24),
                  vertical: responsive.spacing(12),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(responsive.size(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
