import 'package:flutter/material.dart';

import '../../../../core/constants/assets/image_assets.dart';
import '../../../../core/snackbar/app_snackbar.dart';
import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/features/chat/data/services/business/status_likes_service.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';

const Color _syvtLikeColor = Color(0xFFFF6D00);

class ShareYourVoiceTile extends StatefulWidget {
  const ShareYourVoiceTile({
    super.key,
    required this.voiceText,
    required this.responsive,
    required this.isDark,
    required this.statusOwnerId,
    this.statusId,
    this.statusCreatedAt,
  });

  final String voiceText;
  final ResponsiveSize responsive;
  final bool isDark;
  final String statusOwnerId;
  final String? statusId;
  final DateTime? statusCreatedAt;

  @override
  State<ShareYourVoiceTile> createState() => _ShareYourVoiceTileState();
}

class _ShareYourVoiceTileState extends State<ShareYourVoiceTile> {
  bool _isLiked = false;
  bool _isLoading = false;
  String? _lastStatusKey;

  String get _statusId {
    // ✓ CORRECT - Always use the actual status ID, never fallback to user ID
    if (widget.statusId != null && widget.statusId!.isNotEmpty) {
      return widget.statusId!;
    }
    // If statusId is not available, we can't perform the like action
    throw Exception('Status ID is required to toggle status like');
  }

  String get _statusKey =>
      '${widget.statusOwnerId}_${widget.statusId ?? ''}_${widget.voiceText}';

  @override
  void initState() {
    super.initState();
    _lastStatusKey = _statusKey;
    _initializeService();
  }

  @override
  void didUpdateWidget(covariant ShareYourVoiceTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newKey = _statusKey;
    if (_lastStatusKey != newKey) {
      _lastStatusKey = newKey;
      _isLiked = false;
      _loadCachedLikeState();
    }
  }

  Future<void> _initializeService() async {
    final currentUserId = await TokenSecureStorage.instance
        .getCurrentUserIdUUID();
    if (currentUserId != null && currentUserId.isNotEmpty) {
      StatusLikesService.instance.initialize(currentUserId: currentUserId);
      await _loadCachedLikeState();
    }
  }

  Future<void> _loadCachedLikeState() async {
    if (widget.statusOwnerId.isEmpty || widget.voiceText.isEmpty) return;
    if (widget.statusId == null || widget.statusId!.isEmpty) return;

    try {
      final cachedNullable = await StatusLikesService.instance
          .getCachedLikeStateNullable(statusId: _statusId);

      if (cachedNullable != null && mounted && cachedNullable != _isLiked) {
        setState(() => _isLiked = cachedNullable);
      }
      // No server call here — avoids flicker on widget creation.
      // The toggle itself reconciles with the server.
    } catch (e) {
      debugPrint('⚠️ [ShareYourVoiceTile] Error loading like state: $e');
    }
  }

  Future<void> _toggleLike() async {
    if (_isLoading) return;
    if (!ConnectivityCache.instance.isOnline) {
      if (mounted) {
        AppSnackbar.showOfflineWarning(context, "You're offline");
      }
      return;
    }
    if (widget.statusOwnerId.isEmpty || widget.voiceText.isEmpty) return;

    if (widget.statusId == null || widget.statusId!.isEmpty) {
      if (mounted) {
        AppSnackbar.showTopInfo(context, 'Unable to like status at this time');
      }
      return;
    }

    // Check rate limit (max 4 toggles per status)
    final canToggle = await StatusLikesService.instance.canToggle(
      statusId: _statusId,
    );
    if (!canToggle) {
      if (mounted) {
        AppSnackbar.showTopInfo(
          context,
          'Limit reached. New status = new chance!',
        );
      }
      return;
    }

    // Optimistic — flip the heart color instantly, fire toggle in background
    final previousState = _isLiked;
    setState(() {
      _isLiked = !_isLiked;
      _isLoading = true;
    });

    try {
      final result = await StatusLikesService.instance.toggle(
        statusId: _statusId,
        statusOwnerId: widget.statusOwnerId,
      );

      // Increment toggle count
      StatusLikesService.instance.incrementToggleCount(statusId: _statusId);

      if (mounted) {
        setState(() {
          // Reconcile with server if different from optimistic
          if (result.isLiked != _isLiked) {
            _isLiked = result.isLiked;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ [ShareYourVoiceTile] Error: $e');
      if (mounted) {
        setState(() {
          _isLiked = previousState;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasStatus = widget.voiceText.isNotEmpty;
    // ✓ Only enable likes if statusId is available (backend data requirement)
    final canLike =
        hasStatus && widget.statusId != null && widget.statusId!.isNotEmpty;

    return Row(
      children: [
        Expanded(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.mic,
              color: widget.isDark ? Colors.white70 : AppColors.colorGrey,
            ),
            title: Text(
              'Share your voice',
              style: AppTextSizes.regular(context).copyWith(
                color: widget.isDark ? Colors.white : AppColors.colorBlack,
              ),
            ),
            subtitle: Text(
              hasStatus ? widget.voiceText : 'Share your voice',
              style: AppTextSizes.small(context).copyWith(
                color: widget.isDark ? Colors.white70 : AppColors.colorGrey,
              ),
            ),
          ),
        ),
        if (canLike)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _isLoading ? null : _toggleLike,
            child: Padding(
              padding: EdgeInsets.only(left: widget.responsive.spacing(4)),
              child: SizedBox(
                width: widget.responsive.size(44),
                height: widget.responsive.size(44),
                child: Center(
                  child: _isLoading
                      ? SizedBox(
                          width: widget.responsive.size(24),
                          height: widget.responsive.size(24),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _syvtLikeColor,
                          ),
                        )
                      : _isLiked
                      ? Icon(
                          Icons.favorite,
                          size: widget.responsive.size(24),
                          color: _syvtLikeColor,
                        )
                      : Image.asset(
                          ImageAssets.syvlIcon,
                          width: widget.responsive.size(24),
                          height: widget.responsive.size(24),
                          color: widget.isDark ? Colors.white : null,
                          fit: BoxFit.contain,
                        ),
                ),
              ),
            ),
          ),
        if (!canLike && hasStatus)
          Padding(
            padding: EdgeInsets.only(left: widget.responsive.spacing(8)),
            child: Tooltip(
              message: 'Status ID unavailable',
              child: Opacity(
                opacity: 0.3,
                child: Image.asset(
                  ImageAssets.syvlIcon,
                  width: widget.responsive.size(24),
                  height: widget.responsive.size(24),
                  color: widget.isDark ? Colors.white : null,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        if (!hasStatus)
          Padding(
            padding: EdgeInsets.only(left: widget.responsive.spacing(8)),
            child: Image.asset(
              ImageAssets.syvlIcon,
              width: widget.responsive.size(24),
              height: widget.responsive.size(24),
              color: widget.isDark ? Colors.white : null,
              fit: BoxFit.contain,
            ),
          ),
      ],
    );
  }
}
