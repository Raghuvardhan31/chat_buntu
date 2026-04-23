import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chataway_plus/core/constants/api_url/api_urls.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/snackbar/app_snackbar.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import 'package:chataway_plus/core/sync/authenticated_image_cache_manager.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/features/chat/data/services/business/chat_picture_likes_service.dart';
import 'package:chataway_plus/features/chat/data/services/local/chat_picture_likes_local_db.dart';
import 'package:chataway_plus/core/connectivity/connectivity_service.dart';
import 'package:chataway_plus/features/shared/widgets/avatars/cached_circle_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppUserChatPictureView extends StatefulWidget {
  const AppUserChatPictureView({
    super.key,
    required this.displayName,
    this.chatPictureUrl,
    this.contactId,
    this.chatPictureVersion,
    this.showLikeButton = true,
  });

  final String displayName;
  final String? chatPictureUrl;
  final String? contactId;
  final String? chatPictureVersion;
  final bool showLikeButton;

  @override
  State<AppUserChatPictureView> createState() => _AppUserChatPictureViewState();
}

class _AppUserChatPictureViewState extends State<AppUserChatPictureView> {
  bool? _isLoved;
  bool _loveRequestInProgress = false;
  bool _loveInitStarted = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    if (widget.showLikeButton) {
      _loadInitialLikeState();
    }
  }

  Future<void> _loadInitialLikeState() async {
    if (_loveInitStarted) return;
    _loveInitStarted = true;

    final contactId = widget.contactId;
    final targetChatPictureId = widget.chatPictureVersion ?? '';
    if (contactId == null || contactId.isEmpty || targetChatPictureId.isEmpty) {
      if (mounted) setState(() => _isLoved = false);
      return;
    }

    _currentUserId = await TokenSecureStorage.instance.getCurrentUserIdUUID();
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      if (mounted) setState(() => _isLoved = false);
      return;
    }

    final cached = await ChatPictureLikesDatabaseService.instance.getLikeState(
      currentUserId: _currentUserId!,
      likedUserId: contactId,
      targetChatPictureId: targetChatPictureId,
    );
    if (!mounted) return;
    setState(() => _isLoved = cached ?? false);
  }

  Future<void> _handleLoveTap() async {
    if (_loveRequestInProgress) return;
    if (!ConnectivityCache.instance.isOnline) {
      if (mounted) {
        AppSnackbar.showOfflineWarning(context, "You're offline");
      }
      return;
    }

    final contactId = widget.contactId;
    final targetChatPictureId = widget.chatPictureVersion ?? '';
    if (contactId == null || contactId.isEmpty || targetChatPictureId.isEmpty) {
      AppSnackbar.showError(context, 'No picture available to like');
      return;
    }

    _currentUserId ??= await TokenSecureStorage.instance.getCurrentUserIdUUID();
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      if (mounted) AppSnackbar.showError(context, 'User not authenticated');
      return;
    }

    // If we don't know the current state, check server first
    if (_isLoved == null) {
      try {
        debugPrint('🌐 [ChatPictureView] isLoved unknown; checking server...');
        final liked = await ChatPictureLikesService.instance.check(
          likedUserId: contactId,
          targetChatPictureId: targetChatPictureId,
        );
        if (!mounted) return;
        setState(() => _isLoved = liked);
        await ChatPictureLikesDatabaseService.instance.upsert(
          currentUserId: _currentUserId!,
          likedUserId: contactId,
          targetChatPictureId: targetChatPictureId,
          isLiked: liked,
        );
      } catch (e) {
        debugPrint('⚠️ [ChatPictureView] Failed to check like state: $e');
        if (mounted) setState(() => _isLoved = _isLoved ?? false);
      }
    }

    // Check rate limit (max 4 toggles per picture)
    final canToggle = await ChatPictureLikesDatabaseService.instance.canToggle(
      currentUserId: _currentUserId!,
      likedUserId: contactId,
      targetChatPictureId: targetChatPictureId,
    );
    if (!canToggle) {
      if (mounted) {
        AppSnackbar.showTopInfo(
          context,
          'Limit reached. New picture = new chance!',
        );
      }
      return;
    }

    final beforeLoved = _isLoved ?? false;
    final optimistic = !beforeLoved;

    // Set optimistic state
    setState(() {
      _isLoved = optimistic;
      _loveRequestInProgress = true;
    });

    try {
      final result = await ChatPictureLikesService.instance.toggle(
        likedUserId: contactId,
        targetChatPictureId: targetChatPictureId,
        currentUiState: beforeLoved,
      );

      if (!mounted) return;

      // Increment toggle count after successful toggle
      await ChatPictureLikesDatabaseService.instance.incrementToggleCount(
        currentUserId: _currentUserId!,
        likedUserId: contactId,
        targetChatPictureId: targetChatPictureId,
      );

      await ChatPictureLikesDatabaseService.instance.upsert(
        currentUserId: _currentUserId!,
        likedUserId: contactId,
        targetChatPictureId: targetChatPictureId,
        isLiked: result.isLiked,
        likeId: result.likeId,
        likeCount: result.likeCount,
      );

      // Reconcile UI with server response
      setState(() {
        _loveRequestInProgress = false;
        if (result.isLiked != _isLoved) {
          _isLoved = result.isLiked;
        }
      });
    } catch (e) {
      debugPrint('❤️ [ChatPictureView] Like Error: $e');
      if (!mounted) return;
      // Revert to previous state on error
      try {
        await ChatPictureLikesDatabaseService.instance.upsert(
          currentUserId: _currentUserId!,
          likedUserId: contactId,
          targetChatPictureId: targetChatPictureId,
          isLiked: beforeLoved,
        );
      } catch (_) {}
      setState(() {
        _isLoved = beforeLoved;
        _loveRequestInProgress = false;
      });
      if (mounted) AppSnackbar.showError(context, 'Failed to update');
    }
  }

  @override
  Widget build(BuildContext context) {
    final showLikeButton =
        widget.showLikeButton &&
        widget.contactId != null &&
        widget.contactId!.isNotEmpty &&
        (widget.chatPictureVersion ?? '').isNotEmpty;

    return ResponsiveLayoutBuilder(
      builder: (context, constraints, breakpoint) {
        final responsive = ResponsiveSize(
          context: context,
          constraints: constraints,
          breakpoint: breakpoint,
        );

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.black,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: Colors.black,
            systemNavigationBarIconBrightness: Brightness.light,
          ),
          child: Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                color: Colors.white,
                iconSize: responsive.size(24),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              title: Text(
                widget.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextSizes.large(
                  context,
                ).copyWith(color: Colors.white),
              ),
              centerTitle: false,
              actions: [
                if (showLikeButton)
                  IconButton(
                    icon: Icon(
                      (_isLoved ?? false)
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: (_isLoved ?? false)
                          ? const Color(0xFFE91E63)
                          : Colors.white70,
                    ),
                    iconSize: responsive.size(24),
                    onPressed: _loveRequestInProgress ? null : _handleLoveTap,
                    tooltip: 'Like Chat Picture',
                  ),
              ],
            ),
            body: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black,
              alignment: Alignment.center,
              child: _buildImage(responsive),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImage(ResponsiveSize responsive) {
    final url = widget.chatPictureUrl?.trim() ?? '';

    final fallback = Builder(
      builder: (context) {
        final initials = CachedCircleAvatar.getInitials(widget.displayName);
        if (initials.isNotEmpty) {
          final color = CachedCircleAvatar.getColorForName(widget.displayName);
          return CircleAvatar(
            radius: responsive.size(56),
            backgroundColor: color,
            child: Text(
              initials,
              style: TextStyle(
                color: Colors.white,
                fontSize: responsive.size(42),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          );
        }
        return Icon(
          Icons.person,
          size: responsive.size(72),
          color: AppColors.iconSecondary,
        );
      },
    );

    if (url.isEmpty) return fallback;

    if (url.startsWith('file://')) {
      try {
        final filePath = Uri.parse(url).toFilePath();
        return InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Image.file(
            File(filePath),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => fallback,
          ),
        );
      } catch (_) {
        return fallback;
      }
    }

    final fullUrl = url.startsWith('http')
        ? url
        : '${ApiUrls.mediaBaseUrl}$url';

    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: CachedNetworkImage(
        imageUrl: fullUrl,
        cacheManager: AuthenticatedImageCacheManager.instance,
        fit: BoxFit.contain,
        placeholder: (context, url) => fallback,
        errorWidget: (context, url, error) => fallback,
      ),
    );
  }
}
