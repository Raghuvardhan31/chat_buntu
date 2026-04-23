import 'package:chataway_plus/core/constants/feature_tips_info/profile_tips/profile_feature_tips.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/routes/navigation_service.dart';
import 'package:chataway_plus/features/profile/presentation/widgets/emoji_uploader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/features/profile/presentation/widgets/current_user_name_widget.dart';
import 'package:chataway_plus/features/profile/presentation/widgets/emoji_caption_bottom_sheet.dart';
import 'package:chataway_plus/features/profile/presentation/widgets/share_your_voice_widget.dart';
import 'package:chataway_plus/features/profile/presentation/widgets/gallery_widget.dart';
import 'package:chataway_plus/core/dialog_box/app_dialog_box.dart';
import 'package:chataway_plus/features/profile/presentation/providers/emoji/emoji_providers.dart';
import 'package:chataway_plus/features/draggable_emoji/presentation/pages/draggable_floating_ball.dart';
import 'package:chataway_plus/features/draggable_emoji/presentation/providers/draggable_emoji_provider.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';

import 'package:chataway_plus/core/database/tables/user/mobile_number_table.dart';
import 'package:chataway_plus/core/database/tables/user/feature_tip_dismissals_table.dart';
import '../providers/profile/profile_page_providers.dart';
import '../../../../core/connectivity/connectivity_service.dart';
import 'package:chataway_plus/core/snackbar/app_snackbar.dart';

class CurrentUserProfilePage extends ConsumerStatefulWidget {
  const CurrentUserProfilePage({super.key});

  @override
  ConsumerState<CurrentUserProfilePage> createState() =>
      _CurrentUserProfilePageState();
}

enum _ProfileMenuAction { emojiDisplaySettings }

class _CurrentUserProfilePageState
    extends ConsumerState<CurrentUserProfilePage> {
  // Controllers
  late final TextEditingController _nameCtrl;
  late final TextEditingController _statusCtrl;

  bool _seededOnce = false;
  bool _printedEmojiOnce = false;
  bool _showDraggableTip = true;
  bool _showPersonalThoughtsTip = true;
  bool _showEmojiCaptionsTip = true;
  bool _tipsDismissalsLoaded = false;
  String?
  _cachedMobileNumber; // Cache mobile number to avoid FutureBuilder rebuilds

  // Emoji display settings
  bool _showEmojiInProfile = true;
  bool _showEmojiInAppIcon = true;
  String _emojiCaption = '';

  void _log(String message) {
    if (kDebugMode) debugPrint(message);
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _statusCtrl = TextEditingController();
    _loadEmojiPreferences();
    _loadTipDismissals();

    _loadDraggableEmoji();

    ref.listenManual(profileDataProvider, (previous, next) {
      final prevEmojiUpdatedAt = previous?.emojiUpdatedAt;
      final nextEmojiUpdatedAt = next?.emojiUpdatedAt;
      final prevEmoji = previous?.currentEmoji ?? '';
      final nextEmoji = next?.currentEmoji ?? '';
      final prevCaption = previous?.emojiCaption ?? '';
      final nextCaption = next?.emojiCaption ?? '';

      final changed =
          prevEmojiUpdatedAt != nextEmojiUpdatedAt ||
          prevEmoji != nextEmoji ||
          prevCaption != nextCaption;
      if (!changed) return;

      final hasAny =
          nextEmoji.trim().isNotEmpty ||
          nextCaption.trim().isNotEmpty ||
          nextEmojiUpdatedAt != null;
      if (!hasAny) return;

      final emojiState = ref.read(emojiNotifierProvider);
      if (emojiState.isProcessing) return;

      ref.read(emojiNotifierProvider.notifier).reloadLocal();
    });

    ref.listenManual(emojiNotifierProvider, (previous, next) {
      final prevCaption = previous?.emoji?.caption ?? '';
      final nextCaption = next.emoji?.caption ?? '';
      if (prevCaption == nextCaption) return;
      _emojiCaption = nextCaption;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Seed profile UI state from local DB so providers have data when page builds
      ref.read(loadProfileLocalOnlyActionProvider)();
      _log('[EmojiUI] loadEmojiLocalOnly(): read from local DB only');
      ref.read(emojiNotifierProvider.notifier).loadEmoji();
      _loadMobileNumber(); // Load mobile number once
    });
  }

  Future<void> _loadTipDismissals() async {
    try {
      final rawUserId = await TokenSecureStorage.instance
          .getCurrentUserIdUUID();
      final userId = (rawUserId ?? '').trim().isNotEmpty
          ? rawUserId!.trim()
          : 'global';

      final personalThoughtsDismissed = await FeatureTipDismissalsTable.instance
          .isDismissed(
            userId: userId,
            tipKey: FeatureTips.tipKeyPersonalThoughts,
          );
      final emojiCaptionsDismissed = await FeatureTipDismissalsTable.instance
          .isDismissed(userId: userId, tipKey: FeatureTips.tipKeyEmojiCaptions);
      final draggableDismissed = await FeatureTipDismissalsTable.instance
          .isDismissed(
            userId: userId,
            tipKey: FeatureTips.tipKeyDraggableEmoji,
          );

      if (!mounted) return;
      setState(() {
        _showPersonalThoughtsTip = !personalThoughtsDismissed;
        _showEmojiCaptionsTip = !emojiCaptionsDismissed;
        _showDraggableTip = !draggableDismissed;
        _tipsDismissalsLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _showPersonalThoughtsTip = false;
        _showEmojiCaptionsTip = false;
        _showDraggableTip = false;
        _tipsDismissalsLoaded = true;
      });
    }
  }

  Future<void> _dismissTip(String tipKey) async {
    try {
      final rawUserId = await TokenSecureStorage.instance
          .getCurrentUserIdUUID();
      final userId = (rawUserId ?? '').trim().isNotEmpty
          ? rawUserId!.trim()
          : 'global';
      await FeatureTipDismissalsTable.instance.dismiss(
        userId: userId,
        tipKey: tipKey,
      );
    } catch (_) {}
  }

  Future<void> _dismissAllTips() async {
    try {
      final rawUserId = await TokenSecureStorage.instance
          .getCurrentUserIdUUID();
      final userId = (rawUserId ?? '').trim().isNotEmpty
          ? rawUserId!.trim()
          : 'global';
      final tipKeys = [
        FeatureTips.tipKeyPersonalThoughts,
        FeatureTips.tipKeyEmojiCaptions,
        FeatureTips.tipKeyDraggableEmoji,
      ];

      await FeatureTipDismissalsTable.instance.dismissAll(
        userId: userId,
        tipKeys: tipKeys,
      );

      if (!mounted) return;
      setState(() {
        _showPersonalThoughtsTip = false;
        _showEmojiCaptionsTip = false;
        _showDraggableTip = false;
      });
    } catch (_) {}
  }

  void _seedControllersOnce() {
    if (_seededOnce) return;
    _nameCtrl.text = '';
    _statusCtrl.text = '';
    _seededOnce = true;
  }

  /// Load draggable emoji from database
  void _loadDraggableEmoji() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final notifier = ref.read(draggableEmojiProvider);
        if (notifier.currentUserId != null || notifier.isLoading) {
          return;
        }

        notifier.initialize();
      } catch (e) {
        _log('⚠️ [ProfilePage] Error loading draggable emoji: $e');
      }
    });
  }

  /// Save draggable emoji to database
  Future<void> _saveDraggableEmoji(String emoji) async {
    try {
      final notifier = ref.read(draggableEmojiProvider);
      if (notifier.currentUserId == null) {
        await notifier.initialize();
      }
      await notifier.updateEmoji(emoji);
      _log('✅ [ProfilePage] Draggable emoji saved: $emoji');
    } catch (e) {
      _log('❌ [ProfilePage] Error saving draggable emoji: $e');
    }
  }

  /// Load emoji display preferences (profile/app icon)
  Future<void> _loadEmojiPreferences() async {
    try {
      final showProfile = await TokenSecureStorage.instance
          .getShowEmojiInProfile();
      final showAppIcon = await TokenSecureStorage.instance
          .getShowEmojiInAppIcon();
      if (mounted) {
        setState(() {
          _showEmojiInProfile = showProfile;
          _showEmojiInAppIcon = showAppIcon;
        });
      }
    } catch (_) {}
  }

  /// Show emoji display settings dialog
  void _showEmojiSettingsDialog(ResponsiveSize? responsive) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final dialogTheme = Theme.of(context);
            final dialogIsDark = dialogTheme.brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: dialogTheme.colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(responsive?.size(16) ?? 16),
              ),
              title: Text(
                'Emoji Display Settings',
                style: AppTextSizes.large(context).copyWith(
                  fontWeight: FontWeight.w600,
                  color: dialogTheme.colorScheme.onSurface,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Option 1: Show emoji in profile info
                  Container(
                    padding: EdgeInsets.all(responsive?.spacing(12) ?? 12),
                    decoration: BoxDecoration(
                      color: dialogIsDark
                          ? Colors.white.withValues(
                              alpha: _showEmojiInProfile ? 0.10 : 0.06,
                            )
                          : AppColors.lighterGrey.withValues(
                              alpha: _showEmojiInProfile ? 0.30 : 0.16,
                            ),
                      borderRadius: BorderRadius.circular(
                        responsive?.size(12) ?? 12,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Show emoji in profile info',
                            style: AppTextSizes.regular(context).copyWith(
                              fontWeight: FontWeight.w600,
                              color: dialogTheme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Switch(
                          value: _showEmojiInProfile,
                          activeThumbColor: AppColors.primary,
                          activeTrackColor: AppColors.primary.withValues(
                            alpha: 0.5,
                          ),
                          inactiveThumbColor: dialogIsDark
                              ? Colors.white70
                              : Colors.grey.shade600,
                          inactiveTrackColor: dialogIsDark
                              ? Colors.white24
                              : Colors.grey.shade300,
                          onChanged: (value) {
                            setDialogState(() {
                              _showEmojiInProfile = value;
                            });
                            setState(() {
                              _showEmojiInProfile = value;
                            });
                            // Persist preference
                            TokenSecureStorage.instance.setShowEmojiInProfile(
                              value,
                            );
                            _log('✅ Show emoji in profile info: $value');
                          },
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: responsive?.spacing(16) ?? 16),

                  // Option 2: Show selected emoji in app launch
                  Container(
                    padding: EdgeInsets.all(responsive?.spacing(12) ?? 12),
                    decoration: BoxDecoration(
                      color: dialogIsDark
                          ? Colors.white.withValues(
                              alpha: _showEmojiInAppIcon ? 0.10 : 0.06,
                            )
                          : AppColors.lighterGrey.withValues(
                              alpha: _showEmojiInAppIcon ? 0.30 : 0.16,
                            ),
                      borderRadius: BorderRadius.circular(
                        responsive?.size(12) ?? 12,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Show selected emoji in app launch',
                            style: AppTextSizes.regular(context).copyWith(
                              fontWeight: FontWeight.w600,
                              color: dialogTheme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Switch(
                          value: _showEmojiInAppIcon,
                          activeThumbColor: AppColors.primary,
                          activeTrackColor: AppColors.primary.withValues(
                            alpha: 0.5,
                          ),
                          inactiveThumbColor: dialogIsDark
                              ? Colors.white70
                              : Colors.grey.shade600,
                          inactiveTrackColor: dialogIsDark
                              ? Colors.white24
                              : Colors.grey.shade300,
                          onChanged: (value) {
                            setDialogState(() {
                              _showEmojiInAppIcon = value;
                            });
                            setState(() {
                              _showEmojiInAppIcon = value;
                            });
                            // Persist preference
                            TokenSecureStorage.instance.setShowEmojiInAppIcon(
                              value,
                            );
                            _log('✅ Show selected emoji in app launch: $value');
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Close',
                    style: AppTextSizes.regular(context).copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEmojiCaptionBottomSheet(ResponsiveSize? responsive) async {
    final emojiState = ref.read(emojiNotifierProvider);
    final initialCaption = (emojiState.emoji?.caption ?? _emojiCaption).trim();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return EmojiCaptionBottomSheet(
          initialCaption: initialCaption,
          responsive: responsive,
          onSave: (caption) {
            final online = ref
                .read(internetStatusStreamProvider)
                .maybeWhen(data: (v) => v, orElse: () => false);
            if (!online) {
              AppSnackbar.showOfflineWarning(context, "You're offline");
              return;
            }

            final notifier = ref.read(emojiNotifierProvider.notifier);
            final current = ref.read(emojiNotifierProvider).emoji;
            final currentEmoji = current?.emoji ?? '';

            if (current == null || currentEmoji.trim().isEmpty) {
              AppSnackbar.showWarning(
                context,
                'Select emojis first to add a caption',
              );
              return;
            }

            setState(() => _emojiCaption = caption);

            _log(
              '[EmojiCaption] onSave(): id=${current.id}, emoji="$currentEmoji", caption="$caption"',
            );

            if (current.id != null) {
              notifier.updateEmoji(current.id!, currentEmoji, caption);
            } else {
              notifier.createEmoji(currentEmoji, caption);
            }

            AppSnackbar.showSuccess(
              context,
              'Caption updated',
              duration: const Duration(seconds: 1),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _statusCtrl.dispose();
    super.dispose();
  }

  /// Load mobile number once and cache it
  Future<void> _loadMobileNumber() async {
    if (_cachedMobileNumber != null) return; // Already loaded
    try {
      final map = await MobileNumberTable.instance.getMobileNumber();
      if (map != null && mounted) {
        final mobile = (map['mobile_no'] as String?)?.trim();
        if (mobile != null && mobile.isNotEmpty) {
          setState(() => _cachedMobileNumber = mobile);
        }
      }
    } catch (e) {
      _log('❌ Error reading mobile from DB: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    _log('Building CurrentUserProfilePage ');
    final mediaQuery = MediaQuery.of(context);
    final viewInsets = mediaQuery.viewInsets.bottom;

    _seedControllersOnce();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleProfileCompletion(context);
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        resizeToAvoidBottomInset: false,
        body: ResponsiveLayoutBuilder(
          builder: (context, constraints, breakpoint) {
            final responsive = ResponsiveSize(
              context: context,
              constraints: constraints,
              breakpoint: breakpoint,
            );
            final draggableVerticalPosition = constraints.maxHeight * 0.5;

            return Stack(
              children: [
                // Main content
                Column(
                  children: [
                    AppBar(
                      backgroundColor: Theme.of(
                        context,
                      ).scaffoldBackgroundColor,
                      scrolledUnderElevation: 0,
                      leadingWidth: responsive.size(30),
                      title: Padding(
                        padding: EdgeInsets.only(left: responsive.spacing(10)),
                        child: Text(
                          'Profile Info',
                          style: AppTextSizes.large(context).copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      centerTitle: false,
                      leading: Padding(
                        padding: EdgeInsets.only(left: responsive.spacing(16)),
                        child: Center(
                          child: IconButton(
                            iconSize: responsive.size(24),
                            onPressed: () => _handleProfileCompletion(context),
                            icon: Icon(
                              Icons.arrow_back,
                              color: AppColors.primary,
                            ),
                            padding: EdgeInsets.zero,
                            alignment: Alignment.center,
                          ),
                        ),
                      ),
                      actions: [
                        PopupMenuButton<_ProfileMenuAction>(
                          icon: Icon(
                            Icons.more_vert,
                            color: Theme.of(context).colorScheme.onSurface,
                            size: responsive.size(24),
                          ),
                          tooltip: 'Emoji Options',
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              responsive.size(12),
                            ),
                          ),
                          offset: const Offset(0, 30),
                          color: Theme.of(context).colorScheme.surface,
                          onSelected: (action) {
                            switch (action) {
                              case _ProfileMenuAction.emojiDisplaySettings:
                                _showEmojiSettingsDialog(responsive);
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: _ProfileMenuAction.emojiDisplaySettings,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.settings_rounded,
                                    size: responsive.size(18),
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                  SizedBox(width: responsive.spacing(8)),
                                  Expanded(
                                    child: Text(
                                      'Intro Emoji',
                                      style: AppTextSizes.natural(context)
                                          .copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Expanded(
                      child: AnimatedPadding(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        padding: EdgeInsets.only(
                          bottom: viewInsets > 0 ? viewInsets : 0,
                        ),
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: responsive.spacing(20),
                            ),
                            child: Column(
                              children: [
                                Column(
                                  children: [
                                    SizedBox(
                                      height:
                                          breakpoint ==
                                              DeviceBreakpoint.extraSmall
                                          ? responsive.spacing(40)
                                          : responsive.spacing(60),
                                    ),
                                    Consumer(
                                      builder: (context, subRef, _) {
                                        final chatPictureUrl = subRef.watch(
                                          profilePictureUrlProvider,
                                        );
                                        return GalleryWidget(
                                          chatPictureUrl: chatPictureUrl,
                                          responsive: responsive,
                                          onDeleteSelected: () async {
                                            await ref.read(
                                              deleteProfilePictureActionProvider,
                                            )();
                                          },
                                          onPhotoSelected: (String photoPath) async {
                                            _log(
                                              '[ProfilePage] onPhotoSelected() -> $photoPath',
                                            );
                                            await ref.read(
                                              updateProfilePictureActionProvider,
                                            )(photoPath);
                                          },
                                        );
                                      },
                                    ),
                                    SizedBox(
                                      height:
                                          breakpoint ==
                                              DeviceBreakpoint.extraSmall
                                          ? responsive.spacing(30)
                                          : responsive.spacing(50),
                                    ),
                                  ],
                                ),

                                // Status & Name widgets
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(height: responsive.spacing(5)),
                                    Consumer(
                                      builder: (context, subRef, _) {
                                        final displayName = subRef.watch(
                                          profileDisplayNameProvider,
                                        );
                                        return CurrentUserNameWidget(
                                          initialName: displayName,
                                          responsive: responsive,
                                          onNameSaved: (name) {
                                            _nameCtrl.text = name;
                                          },
                                        );
                                      },
                                    ),

                                    SizedBox(height: responsive.spacing(20)),
                                    Consumer(
                                      builder: (context, subRef, _) {
                                        final status = subRef.watch(
                                          profileDisplayStatusProvider,
                                        );
                                        return ShareYourVoiceWidget(
                                          initialStatus: status,
                                          responsive: responsive,
                                          onShareYourVoiceSaved: (val) async {
                                            _log(
                                              '[ProfilePage] onShareYourVoiceSaved() -> $val',
                                            );
                                            await ref.read(
                                              updateStatusActionProvider,
                                            )(val);
                                            if (!mounted) return;
                                            _statusCtrl.text = val;
                                          },
                                        );
                                      },
                                    ),
                                  ],
                                ),

                                SizedBox(height: responsive.spacing(20)),

                                // Mobile Number: cached to avoid rebuilds
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.only(
                                        left: responsive.spacing(33),
                                      ),
                                      child: Text(
                                        'Mobile Number',
                                        style: AppTextSizes.regular(context)
                                            .copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                            ),
                                      ),
                                    ),
                                    SizedBox(height: responsive.spacing(5)),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.phone,
                                          color:
                                              Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.white
                                              : AppColors.iconPrimary,
                                          size: responsive.size(24),
                                          semanticLabel: 'Mobile number',
                                        ),
                                        SizedBox(width: responsive.spacing(12)),
                                        // Display cached mobile number (no FutureBuilder)
                                        Text(
                                          (_cachedMobileNumber != null &&
                                                  _cachedMobileNumber!
                                                      .isNotEmpty)
                                              ? '+91-$_cachedMobileNumber'
                                              : 'Not set',
                                          style: AppTextSizes.natural(context)
                                              .copyWith(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                              ),
                                        ),
                                      ],
                                    ),

                                    SizedBox(height: responsive.spacing(20)),
                                    // Emojis area
                                    Consumer(
                                      builder: (context, subRef, _) {
                                        final emojiState = subRef.watch(
                                          emojiNotifierProvider,
                                        );
                                        final initialText =
                                            emojiState.emoji?.emoji ?? '';
                                        final initialEmojis = initialText
                                            .characters
                                            .toList();
                                        if (!_printedEmojiOnce &&
                                            emojiState.hasEverLoaded &&
                                            !emojiState.isProcessing &&
                                            !emojiState.forceNextCreate &&
                                            initialText.isNotEmpty) {
                                          _log(
                                            '[EmojiUI] read emojis from local DB: $initialText',
                                          );
                                          _printedEmojiOnce = true;
                                        }
                                        return EmojiUploader(
                                          initialEmojis: initialEmojis,
                                          responsive: responsive,
                                          onCaptionTap: () =>
                                              _showEmojiCaptionBottomSheet(
                                                responsive,
                                              ),
                                          onChanged: (list) async {
                                            final online = subRef
                                                .read(
                                                  internetStatusStreamProvider,
                                                )
                                                .maybeWhen(
                                                  data: (v) => v,
                                                  orElse: () => false,
                                                );
                                            if (!online) {
                                              AppSnackbar.showOfflineWarning(
                                                context,
                                                "You're offline",
                                              );
                                              return;
                                            }

                                            final notifier = subRef.read(
                                              emojiNotifierProvider.notifier,
                                            );
                                            final state = subRef.read(
                                              emojiNotifierProvider,
                                            );
                                            final existingCaption =
                                                state.emoji?.caption ?? '';
                                            final effectiveCaption =
                                                _emojiCaption.trim().isNotEmpty
                                                ? _emojiCaption.trim()
                                                : existingCaption.trim();
                                            final current = state.emoji;
                                            final emojiString = list.join();
                                            if (list.isEmpty) {
                                              if (current?.id != null) {
                                                await notifier.deleteEmoji(
                                                  current!.id!,
                                                  current.emoji ?? '',
                                                  current.caption ??
                                                      effectiveCaption,
                                                );
                                              }
                                              return;
                                            }
                                            if (current?.id != null) {
                                              await notifier.updateEmoji(
                                                current!.id!,
                                                emojiString,
                                                effectiveCaption,
                                              );
                                            } else {
                                              await notifier.createEmoji(
                                                emojiString,
                                                effectiveCaption,
                                              );
                                            }
                                          },
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Feature tip cards - all centered
                if (_tipsDismissalsLoaded && _showEmojiInProfile) ...[
                  // Personal Thoughts tip card
                  if (_showPersonalThoughtsTip)
                    Positioned(
                      left:
                          constraints.maxWidth *
                          0.05, // centered with 5% margin
                      right: constraints.maxWidth * 0.05,
                      top: responsive.spacing(140),
                      child: TipCard(
                        data: FeatureTips.personalThoughtsCard,
                        style: FeatureTips.tipCardStyle,
                        responsive: responsive,
                        onClose: () {
                          _dismissTip(FeatureTips.tipKeyPersonalThoughts);
                          setState(() {
                            _showPersonalThoughtsTip = false;
                          });
                        },
                      ),
                    ),

                  // Emoji Captions tip card
                  if (_showEmojiCaptionsTip)
                    Positioned(
                      left:
                          constraints.maxWidth *
                          0.05, // centered with 5% margin
                      right: constraints.maxWidth * 0.05,
                      top: responsive.spacing(300),
                      child: TipCard(
                        data: FeatureTips.emojiCaptionsCard,
                        style: FeatureTips.tipCardStyle,
                        responsive: responsive,
                        onClose: () {
                          _dismissTip(FeatureTips.tipKeyEmojiCaptions);
                          setState(() {
                            _showEmojiCaptionsTip = false;
                          });
                        },
                      ),
                    ),

                  // Draggable emoji tip card
                  if (_showDraggableTip)
                    Positioned(
                      left:
                          constraints.maxWidth *
                          0.05, // centered with 5% margin
                      right: constraints.maxWidth * 0.05,
                      top: responsive.spacing(460),
                      child: TipCard(
                        data: FeatureTips.draggableEmojiCard,
                        style: FeatureTips.tipCardStyle,
                        responsive: responsive,
                        onClose: () {
                          _dismissTip(FeatureTips.tipKeyDraggableEmoji);
                          setState(() {
                            _showDraggableTip = false;
                          });
                        },
                      ),
                    ),

                  // Dismiss All button
                  if (_showDraggableTip ||
                      _showPersonalThoughtsTip ||
                      _showEmojiCaptionsTip)
                    Positioned(
                      bottom: responsive.spacing(100),
                      right: responsive.spacing(16),
                      child: GestureDetector(
                        onTap: () {
                          _dismissAllTips();
                          setState(() {
                            _showDraggableTip = false;
                            _showPersonalThoughtsTip = false;
                            _showEmojiCaptionsTip = false;
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: responsive.spacing(12),
                            vertical: responsive.spacing(8),
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFFFF6B35), // bright orange
                                Color(0xFFE91E63), // bright pink
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(
                              responsive.size(20),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: responsive.size(8),
                                offset: Offset(0, responsive.spacing(2)),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.clear_all,
                                size: responsive.size(16),
                                color: Colors.white,
                              ),
                              SizedBox(width: responsive.spacing(4)),
                              Text(
                                'Dismiss All',
                                style: AppTextSizes.small(context).copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  Builder(
                    builder: (context) {
                      final draggable = ref.watch(draggableEmojiProvider);
                      if (draggable.isLoading ||
                          draggable.currentUserId == null) {
                        return const SizedBox.shrink();
                      }

                      return DraggableFloatingBall(
                        size: responsive.size(50),
                        color: AppColors.primary,
                        initialEmoji: draggable.emoji,
                        onEmojiChanged: (emoji) => _saveDraggableEmoji(emoji),
                        initialPosition: Offset(
                          constraints.maxWidth - responsive.size(70),
                          draggableVerticalPosition,
                        ),
                      );
                    },
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  static const String _statusPlaceholder =
      'Write custom or tap to choose preset';

  void _handleProfileCompletion(BuildContext context) {
    final name = ref.read(profileDisplayNameProvider).trim();
    final status = ref.read(profileDisplayStatusProvider).trim();
    final isIncomplete =
        name.isEmpty || status.isEmpty || status == _statusPlaceholder;
    if (isIncomplete) {
      AppDialogBox.show(
        context,
        icon: Icons.warning_amber_rounded,
        iconColor: AppColors.warning,
        title: '"Complete your ChatAway+ profile"',
        message:
            'To proceed on ChatAway+, please add your Name and Share Your Voice.',
        barrierDismissible: false,
        buttons: [
          DialogBoxButton(
            text: 'Complete Now',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      );
      return;
    }
    final args = ModalRoute.of(context)?.settings.arguments;
    bool fromOtp = false;
    if (args is Map) {
      final raw = args['fromOtp'];
      if (raw is bool) {
        fromOtp = raw;
      }
    }

    if (fromOtp) {
      NavigationService.goToChatList();
    } else {
      NavigationService.goToSettingsMain();
    }
  }
}
