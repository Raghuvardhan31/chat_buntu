import 'package:flutter/material.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/routes/navigation_service.dart';
import 'package:chataway_plus/features/mood_emoji/presentation/widgets/mood_emoji_circle.dart';
import 'package:chataway_plus/features/mood_emoji/presentation/providers/mood_emoji_provider.dart';

class ChatListHeaderWidget extends StatelessWidget {
  final ResponsiveSize responsive;
  final bool isSearching;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final VoidCallback onSearchToggle;
  final MoodEmojiProvider moodEmojiProvider;

  const ChatListHeaderWidget({
    super.key,
    required this.responsive,
    required this.isSearching,
    required this.searchController,
    required this.searchFocusNode,
    required this.onSearchToggle,
    required this.moodEmojiProvider,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Main header with ChatAway+ title
        Container(
          color: Theme.of(context).appBarTheme.backgroundColor,
          height: kToolbarHeight,
          padding: EdgeInsets.symmetric(horizontal: responsive.spacing(16)),
          child: Row(
            children: [
              Text(
                'ChatAway+',
                style: AppTextSizes.heading(
                  context,
                ).copyWith(color: AppColors.primary),
              ),
              const Spacer(),
              Padding(
                padding: EdgeInsets.only(right: responsive.spacing(8)),
                child: MoodEmojiCircle(provider: moodEmojiProvider),
              ),
              IconButton(
                icon: Icon(
                  Icons.settings_suggest_sharp,
                  size: responsive.size(24),
                  color: isDark ? Colors.white : AppColors.iconPrimary,
                ),
                onPressed: () => NavigationService.goToSettingsMain(),
              ),
            ],
          ),
        ),
        // Search/Messages header
        Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          height: kToolbarHeight,
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: responsive.spacing(16),
                  ),
                  child: isSearching
                      ? TextField(
                          autofocus: false,
                          focusNode: searchFocusNode,
                          controller: searchController,
                          cursorColor: isDark ? Colors.white : Colors.black,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            hintText: 'Search...',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white54 : Colors.grey[600],
                              fontSize: responsive.size(16),
                            ),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              vertical: responsive.spacing(12),
                            ),
                          ),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: responsive.size(16),
                          ),
                        )
                      : Row(
                          children: [
                            Text(
                              'Messages',
                              style:
                                  AppTextSizes.custom(
                                    context,
                                    20,
                                    fontWeight: FontWeight.w600,
                                    height: 1.2,
                                  ).copyWith(
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.colorGrey,
                                  ),
                            ),
                            const Spacer(),
                            Text(
                              'Search Chats',
                              style: AppTextSizes.regular(context).copyWith(
                                color: isDark
                                    ? Colors.white70
                                    : AppColors.colorGrey,
                              ),
                            ),
                            SizedBox(width: responsive.spacing(2)),
                          ],
                        ),
                ),
              ),
              GestureDetector(
                onTap: onSearchToggle,
                child: Icon(
                  isSearching ? Icons.close : Icons.manage_search_rounded,
                  size: responsive.size(24),
                  color: isDark ? Colors.white : AppColors.colorGrey,
                ),
              ),
              SizedBox(width: responsive.spacing(8)),
            ],
          ),
        ),
      ],
    );
  }
}
