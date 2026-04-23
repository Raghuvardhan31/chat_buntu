import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/connectivity/connectivity_service.dart';
import 'package:chataway_plus/core/snackbar/app_snackbar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chataway_plus/core/sync/app_image_cache_manager.dart';
import 'package:chataway_plus/core/sync/authenticated_image_cache_manager.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/features/profile/presentation/widgets/current_user_chat_picture_viewer.dart';

class GalleryWidget extends ConsumerStatefulWidget {
  final Future<void> Function(String photoPath) onPhotoSelected;
  final String? chatPictureUrl;
  final Future<void> Function()? onDeleteSelected;
  final ResponsiveSize? responsive;
  const GalleryWidget({
    super.key,
    required this.onPhotoSelected,
    this.chatPictureUrl,
    this.onDeleteSelected,
    this.responsive,
  });

  @override
  ConsumerState<GalleryWidget> createState() => _GalleryWidgetState();
}

// --- only the GalleryWidget class is shown / changed below ---
class _GalleryWidgetState extends ConsumerState<GalleryWidget> {
  late TextScaler textScaler;

  String? _imagePath; // local-only path (either picked or from cache)
  bool _busy = false;
  bool _hasDeleted =
      false; // track if user deleted current remote image locally
  int _profileImageLoadToken = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _attemptLoadCachedProfileImage();
    });
  }

  @override
  void didUpdateWidget(covariant GalleryWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chatPictureUrl != widget.chatPictureUrl) {
      // profile URL changed -> clear deletion flag and re-check cache
      _hasDeleted = false;
      _profileImageLoadToken++;
      _attemptLoadCachedProfileImage();
    }
  }

  /// Try to get cached file for `widget.chatPictureUrl`.
  /// If found -> use file (Image.file) so offline works reliably.
  /// If not cached and online -> download to cache and use downloaded file.
  Future<void> _attemptLoadCachedProfileImage() async {
    final url = widget.chatPictureUrl;
    if (url == null || url.isEmpty) return;
    if (_hasDeleted) return;

    final int token = ++_profileImageLoadToken;

    try {
      // 1) Check cache first (no network)
      final cached = await AuthenticatedImageCacheManager.instance
          .getFileFromCache(url);
      if (cached?.file != null) {
        if (mounted &&
            token == _profileImageLoadToken &&
            !_hasDeleted &&
            widget.chatPictureUrl == url) {
          setState(() {
            _imagePath = cached!.file.path;
          });
        }
        return;
      }

      // 2) If not in cache, download only when online (avoid blocking on network if offline)
      final online = ref
          .read(internetStatusStreamProvider)
          .maybeWhen(data: (v) => v, orElse: () => false);

      if (!online) {
        // No cache + offline -> nothing to do (placeholder will remain)
        return;
      }

      // Download & cache the file with authentication. This writes into cache manager storage.
      final file = await AuthenticatedImageCacheManager.instance.getSingleFile(
        url,
      );

      if (mounted &&
          token == _profileImageLoadToken &&
          !_hasDeleted &&
          widget.chatPictureUrl == url) {
        setState(() {
          _imagePath = file.path;
        });
        // Optional: if you want to persist the local path to your profile DB
        // you can call a notifier/repository here to save `file.path` and prefer local path next time.
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('GalleryWidget: failed to load cached image: $e\n$st');
      }
      // ignore gracefully
    }
  }

  @override
  Widget build(BuildContext context) {
    textScaler = MediaQuery.textScalerOf(context);
    final responsive = widget.responsive;

    final avatarSize = responsive?.size(220) ?? 220.0;
    final cameraBottom = responsive?.spacing(22) ?? 22.0;
    final cameraRight = responsive?.spacing(13) ?? 13.0;
    final cameraSize = responsive?.size(45) ?? 45.0;
    final cameraBorderWidth = responsive?.size(2) ?? 2.0;
    final cameraBlurRadius = responsive?.size(4) ?? 4.0;
    final cameraShadowOffsetY = responsive?.spacing(2) ?? 2.0;
    final cameraIconSize = responsive?.size(24) ?? 24.0;

    return SizedBox(
      width: avatarSize,
      height: avatarSize,
      child: Stack(
        children: [
          _buildProfileImage(responsive),
          if (_busy) _buildOverlay(responsive),
          Positioned(
            bottom: cameraBottom,
            right: cameraRight,
            child: GestureDetector(
              onTap: _showPhotoOptions,
              child: Container(
                width: cameraSize,
                height: cameraSize,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                  border:
                      !(((_imagePath != null && _imagePath!.isNotEmpty)) ||
                          (widget.chatPictureUrl != null &&
                              widget.chatPictureUrl!.isNotEmpty))
                      ? Border.all(
                          color: AppColors.primary,
                          width: cameraBorderWidth,
                        )
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: cameraBlurRadius,
                      offset: Offset(0, cameraShadowOffsetY),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.camera_alt,
                  color: AppColors.iconPrimary,
                  size: cameraIconSize * textScaler.scale(1.0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImage(ResponsiveSize? responsive) {
    final hasLocal = _imagePath != null && _imagePath!.isNotEmpty;
    final hasNetwork =
        (widget.chatPictureUrl != null &&
        widget.chatPictureUrl!.isNotEmpty &&
        !_hasDeleted);

    final avatarOuterSize = responsive?.size(224) ?? 224.0;
    final avatarPadding = responsive?.size(4) ?? 4.0;
    final iconBaseSize = responsive?.size(88) ?? 88.0;

    final placeholder = Container(
      width: avatarOuterSize,
      height: avatarOuterSize,
      padding: EdgeInsets.all(avatarPadding),
      child: ClipOval(
        child: Container(
          color: Colors.grey.shade200,
          child: Center(
            child: Icon(
              Icons.person,
              size: iconBaseSize * textScaler.scale(1.0),
              color: Colors.grey.shade500,
            ),
          ),
        ),
      ),
    );

    // No local or network image: show only the placeholder, but keep it tappable
    // so the user can still open the full-screen viewer and upload from there.
    if (!hasLocal && !hasNetwork) {
      return GestureDetector(onTap: _openViewer, child: placeholder);
    }

    final avatar = Container(
      width: avatarOuterSize,
      height: avatarOuterSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primary,
          width: responsive?.size(2) ?? 2.0,
        ),
      ),
      padding: EdgeInsets.all(avatarPadding),
      child: ClipOval(
        child: hasLocal
            ? Image.file(
                File(_imagePath!),
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                errorBuilder: (ctx, err, st) => Container(
                  color: Colors.grey.shade200,
                  child: Center(
                    child: Icon(
                      Icons.person,
                      size: iconBaseSize * textScaler.scale(1.0),
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
              )
            : CachedNetworkImage(
                imageUrl: widget.chatPictureUrl!,
                fit: BoxFit.cover,
                cacheManager: AuthenticatedImageCacheManager.instance,
                placeholder: (ctx, url) => Container(
                  color: Colors.grey.shade200,
                  child: Center(
                    child: Icon(
                      Icons.person,
                      size: responsive?.size(88) ?? 88.0,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
                errorWidget: (ctx, url, err) => Container(
                  color: Colors.grey.shade200,
                  child: Center(
                    child: Icon(
                      Icons.person,
                      size: responsive?.size(88) ?? 88.0,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
                // Once image is downloaded & cached by CachedNetworkImage, just display it
                // Note: _attemptLoadCachedProfileImage() already handles caching on init/didUpdateWidget
                // No need to re-fetch cache here - it causes unnecessary async work on every build
                imageBuilder: (ctx, imageProvider) {
                  return Image(image: imageProvider, fit: BoxFit.cover);
                },
              ),
      ),
    );

    return GestureDetector(onTap: _openViewer, child: avatar);
  }

  void _openViewer({bool replaceRoute = false}) {
    final hasLocal = _imagePath != null && _imagePath!.isNotEmpty;
    final hasNetwork =
        (widget.chatPictureUrl != null &&
        widget.chatPictureUrl!.isNotEmpty &&
        !_hasDeleted);

    final route = MaterialPageRoute(
      builder: (_) => CurrentUserChatPictureViewer(
        localImagePath: hasLocal ? _imagePath : null,
        chatPictureUrl: !hasLocal && hasNetwork ? widget.chatPictureUrl : null,
        onEdit: () {
          // Show photo options. User stays in viewer until they choose to go back.
          // After update/delete, we replace the viewer route with updated image.
          _showPhotoOptions(openViewerAfterAction: true);
        },
      ),
    );

    if (replaceRoute) {
      // Replace current viewer route so back button goes to Profile Info
      Navigator.of(context).pushReplacement(route);
    } else {
      Navigator.of(context).push(route);
    }
  }

  Widget _buildOverlay(ResponsiveSize? responsive) => CircleAvatar(
    radius: responsive?.size(110) ?? 110.0,
    backgroundColor: Colors.black54,
    child: CircularProgressIndicator(
      color: Colors.grey[300],
      strokeWidth: responsive?.size(3) ?? 3.0,
    ),
  );

  void _showPhotoOptions({bool openViewerAfterAction = false}) {
    final hasImage =
        (_imagePath != null && _imagePath!.isNotEmpty) ||
        (widget.chatPictureUrl != null && widget.chatPictureUrl!.isNotEmpty);
    final responsive = widget.responsive;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBackground = isDark ? Colors.black : Colors.white;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.grey[600]! : Colors.grey[400]!;
    final enabledIconColor = isDark ? Colors.white : AppColors.iconPrimary;
    final disabledIconColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;
    final dragHandleColor = isDark ? Colors.grey[700] : Colors.grey[300];
    final disabledBorderColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;

    final sheetRadius = responsive?.size(20) ?? 20.0;
    final sheetVerticalPadding = responsive?.spacing(30) ?? 30.0;
    final sheetHorizontalPadding = responsive?.spacing(20) ?? 20.0;
    final dragHandleWidth = responsive?.size(40) ?? 40.0;
    final dragHandleHeight = responsive?.size(4) ?? 4.0;
    final dragHandleBottomMargin = responsive?.spacing(24) ?? 24.0;
    final actionCircleSize = responsive?.size(60) ?? 60.0;
    final actionBorderWidth = responsive?.size(2) ?? 2.0;
    final actionIconSize = responsive?.size(28) ?? 28.0;
    final actionLabelSpacing = responsive?.spacing(12) ?? 12.0;
    final bottomSpacing = responsive?.spacing(30) ?? 30.0;

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(sheetRadius)),
      ),
      builder: (ctx) {
        return Container(
          color: sheetBackground,
          padding: EdgeInsets.symmetric(
            vertical: sheetVerticalPadding,
            horizontal: sheetHorizontalPadding,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: dragHandleWidth,
                height: dragHandleHeight,
                margin: EdgeInsets.only(bottom: dragHandleBottomMargin),
                decoration: BoxDecoration(
                  color: dragHandleColor,
                  borderRadius: BorderRadius.circular(
                    responsive?.size(2) ?? 2.0,
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _pickFromGallery(
                            openViewerAfterAction: openViewerAfterAction,
                          );
                        },
                        child: Container(
                          width: actionCircleSize,
                          height: actionCircleSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primaryDark,
                              width: actionBorderWidth,
                            ),
                          ),
                          child: Icon(
                            Icons.photo_library,
                            color: enabledIconColor,
                            size: actionIconSize * textScaler.scale(1.0),
                          ),
                        ),
                      ),
                      SizedBox(height: actionLabelSpacing),
                      Text(
                        'Gallery',
                        style: AppTextSizes.regular(context).copyWith(
                          fontWeight: FontWeight.w500,
                          color: primaryTextColor,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      GestureDetector(
                        onTap: hasImage
                            ? () async {
                                Navigator.of(ctx).pop();
                                await _deleteImage(
                                  openViewerAfterAction: openViewerAfterAction,
                                );
                              }
                            : null,
                        child: Container(
                          width: responsive?.size(60) ?? 60.0,
                          height: responsive?.size(60) ?? 60.0,
                          decoration: BoxDecoration(
                            color: sheetBackground,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: hasImage
                                  ? AppColors.primaryDark
                                  : disabledBorderColor,
                              width: actionBorderWidth,
                            ),
                          ),
                          child: Icon(
                            Icons.delete,
                            color: hasImage
                                ? enabledIconColor
                                : disabledIconColor,
                            size: actionIconSize * textScaler.scale(1.0),
                          ),
                        ),
                      ),
                      SizedBox(height: actionLabelSpacing),
                      Text(
                        'Delete',
                        style: AppTextSizes.regular(context).copyWith(
                          fontWeight: FontWeight.w500,
                          color: hasImage
                              ? primaryTextColor
                              : secondaryTextColor,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: bottomSpacing),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickFromGallery({bool openViewerAfterAction = false}) async {
    final file = await _checkPermissionsAndPickPhoto();
    if (file != null) {
      final cropped = await _cropImage(file);
      if (!mounted) return;
      if (cropped != null) {
        final online = ref
            .read(internetStatusStreamProvider)
            .maybeWhen(data: (v) => v, orElse: () => false);
        if (!online) {
          AppSnackbar.showOfflineWarning(
            context,
            "You're offline. Please connect to the internet",
          );
          return;
        }
        setState(() {
          _imagePath = cropped.path;
          _hasDeleted = false;
          _busy = true;
        });
        await widget.onPhotoSelected(cropped.path);
        if (!mounted) return;
        setState(() => _busy = false);
        AppSnackbar.showSuccess(
          context,
          'Chatpic updated',
          bottomPosition: 120,
          duration: const Duration(seconds: 1),
        );

        if (openViewerAfterAction) {
          // Wait for the frame to complete so state is fully updated
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final route = ModalRoute.of(context);
            if (route != null && !route.isCurrent) {
              Navigator.of(context).maybePop();
            }
          });
        }
      } else {
        final useOriginal = await _askUseOriginal();
        if (!mounted) return;
        if (useOriginal) {
          final online = ref
              .read(internetStatusStreamProvider)
              .maybeWhen(data: (v) => v, orElse: () => false);
          if (!online) {
            AppSnackbar.showOfflineWarning(
              context,
              "You're offline. Please connect to the internet",
            );
            return;
          }
          setState(() {
            _imagePath = file.path;
            _hasDeleted = false;
            _busy = true;
          });
          await widget.onPhotoSelected(file.path);
          if (!mounted) return;
          setState(() => _busy = false);
          AppSnackbar.showSuccess(
            context,
            'Chatpic updated',
            bottomPosition: 120,
            duration: const Duration(seconds: 1),
          );

          if (openViewerAfterAction) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              final route = ModalRoute.of(context);
              if (route != null && !route.isCurrent) {
                Navigator.of(context).maybePop();
              }
            });
          }
        }
      }
    }
  }

  Future<File?> _checkPermissionsAndPickPhoto() async {
    try {
      var permission = await Permission.photos.isGranted
          ? Permission.photos
          : Permission.storage;
      var status = await permission.status;
      if (status.isDenied) {
        status = await permission.request();
        if (status.isDenied && permission == Permission.photos) {
          permission = Permission.storage;
          status = await permission.request();
        }
        if (status.isDenied) {
          if (!mounted) return null;
          AppSnackbar.showError(
            context,
            'Permission to access photos is required',
            bottomPosition: 120,
            duration: const Duration(seconds: 2),
          );
          return null;
        }
      }
      if (status.isPermanentlyDenied) {
        await _showSettingsDialog();
        return null;
      }
      if (status.isGranted) {
        final picker = ImagePicker();
        // Don't pre-resize - let user see original photo, cropper handles final size
        final pickedFile = await picker.pickImage(source: ImageSource.gallery);
        if (pickedFile != null) return File(pickedFile.path);
      }
      return null;
    } catch (e) {
      if (!mounted) return null;
      AppSnackbar.showError(
        context,
        'Error updating chatpic',
        bottomPosition: 120,
        duration: const Duration(seconds: 2),
      );
      return null;
    }
  }

  Future<void> _showSettingsDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final responsive = widget.responsive;
        final dialogRadius = responsive?.size(16) ?? 16.0;
        final iconSize = responsive?.size(24) ?? 24.0;
        final iconTextSpacing = responsive?.spacing(12) ?? 12.0;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(dialogRadius),
          ),
          title: Row(
            children: [
              Icon(
                Icons.settings,
                color: AppColors.primary,
                size: iconSize * textScaler.scale(1.0),
              ),
              SizedBox(width: iconTextSpacing),
              Text(
                'Permission Required',
                style: AppTextSizes.large(
                  context,
                ).copyWith(fontWeight: FontWeight.w600, color: Colors.black87),
              ),
            ],
          ),
          content: Text(
            'Please grant ChatAway+ access to your photos in Settings to upload profile pictures.',
            style: AppTextSizes.regular(
              context,
            ).copyWith(color: Colors.black54, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Cancel',
                style: AppTextSizes.regular(
                  context,
                ).copyWith(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                openAppSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: Text(
                'Open Settings',
                style: AppTextSizes.regular(
                  context,
                ).copyWith(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _askUseOriginal() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            final responsive = widget.responsive;
            final dialogRadius = responsive?.size(16) ?? 16.0;
            final iconSize = responsive?.size(24) ?? 24.0;
            final iconTextSpacing = responsive?.spacing(12) ?? 12.0;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(dialogRadius),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.crop,
                    color: AppColors.primary,
                    size: iconSize * textScaler.scale(1.0),
                  ),
                  SizedBox(width: iconTextSpacing),
                  Text(
                    'Cropping Failed',
                    style: AppTextSizes.large(context).copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              content: Text(
                'Image cropping failed or was cancelled. Would you like to use the original image instead?',
                style: AppTextSizes.regular(
                  context,
                ).copyWith(color: Colors.black54, height: 1.4),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(
                    'Cancel',
                    style: AppTextSizes.regular(
                      context,
                    ).copyWith(color: Colors.grey.shade600),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: Text(
                    'Use Original',
                    style: AppTextSizes.regular(context).copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<CroppedFile?> _cropImage(File imageFile) async {
    try {
      final fileStat = await imageFile.stat();
      final fileSizeMB = fileStat.size / (1024 * 1024);
      if (fileSizeMB > 50) {
        if (!mounted) return null;
        AppSnackbar.showError(
          context,
          'Error updating chatpic',
          bottomPosition: 120,
          duration: const Duration(seconds: 2),
        );
        return null;
      }
      return await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1.0, ratioY: 1.0),
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Edit Chat Picture',
            toolbarColor: AppColors.iconPrimary,
            toolbarWidgetColor: Colors.white,
            backgroundColor: Colors.black,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: false,
            showCropGrid: false,
            cropGridColor: Colors.transparent,
            cropFrameColor: Colors.transparent,
            activeControlsWidgetColor: AppColors.iconPrimary,
            dimmedLayerColor: Colors.black.withAlpha((0.85 * 255).round()),
            cropStyle: CropStyle.circle,
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
          IOSUiSettings(
            title: 'Edit Chat Picture',
            doneButtonTitle: 'Done',
            cancelButtonTitle: 'Cancel',
            minimumAspectRatio: 1.0,
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            cropStyle: CropStyle.circle,
            aspectRatioPickerButtonHidden: true,
          ),
        ],
      );
    } catch (e) {
      if (!mounted) return null;
      AppSnackbar.showError(
        context,
        'Error updating chatpic',
        bottomPosition: 120,
        duration: const Duration(seconds: 2),
      );
      return null;
    }
  }

  Future<void> _deleteImage({bool openViewerAfterAction = false}) async {
    final urlToEvict = widget.chatPictureUrl;
    final online = ref
        .read(internetStatusStreamProvider)
        .maybeWhen(data: (v) => v, orElse: () => false);
    if (!online) {
      AppSnackbar.showOfflineWarning(
        context,
        "You're offline. Please connect to the internet",
      );
      return;
    }

    if (widget.onDeleteSelected != null) {
      await widget.onDeleteSelected!();
    }
    if (!mounted) return;

    if (urlToEvict != null && urlToEvict.isNotEmpty) {
      try {
        await AppImageCacheManager.instance.removeFile(urlToEvict);
      } catch (_) {}
      try {
        PaintingBinding.instance.imageCache.evict(NetworkImage(urlToEvict));
      } catch (_) {}
    }

    if (!mounted) return;

    setState(() {
      _imagePath = null;
      _hasDeleted = true;
      _profileImageLoadToken++;
    });
    AppSnackbar.showSuccess(
      context,
      'Chatpic deleted',
      bottomPosition: 120,
      duration: const Duration(seconds: 1),
    );

    if (openViewerAfterAction) {
      // Wait for the frame to complete so state is fully updated
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final route = ModalRoute.of(context);
        if (route != null && !route.isCurrent) {
          Navigator.of(context).maybePop();
        }
      });
    }
  }
}
