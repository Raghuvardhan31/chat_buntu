import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:image_cropper/image_cropper.dart';

/// WhatsApp-style image preview page before sending
/// Shows the captured/selected image with:
/// - Top bar: close (X), receiver name, delete, retake, crop
/// - Center: full image preview with pinch-to-zoom
/// - Bottom: caption input field, receiver name + green send FAB
class ImagePreviewPage extends StatefulWidget {
  const ImagePreviewPage({
    super.key,
    required this.imageFile,
    required this.receiverName,
    required this.onSend,
  });

  final File imageFile;
  final String receiverName;
  final void Function(File imageFile, String caption) onSend;

  @override
  State<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<ImagePreviewPage> {
  final TextEditingController _captionController = TextEditingController();
  final FocusNode _captionFocusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isSending = false;
  late File _currentImageFile;

  @override
  void initState() {
    super.initState();
    _currentImageFile = widget.imageFile;
  }

  @override
  void dispose() {
    _captionController.dispose();
    _captionFocusNode.dispose();
    super.dispose();
  }

  // ── Actions ──────────────────────────────────────────────────────────

  void _handleSend() {
    if (_isSending) return;
    setState(() => _isSending = true);

    final caption = _captionController.text.trim();
    widget.onSend(_currentImageFile, caption);
    Navigator.of(context).pop();
  }

  void _handleDelete() {
    Navigator.of(context).pop();
  }

  Future<void> _handleRetake() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
      );
      if (photo != null && mounted) {
        setState(() {
          _currentImageFile = File(photo.path);
        });
      }
    } catch (e) {
      debugPrint('📷 Retake error: $e');
    }
  }

  Future<void> _handleCrop() async {
    if (_isSending) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: _currentImageFile.path,
      compressQuality: 90,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop',
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.white,
          backgroundColor: Colors.black,
          statusBarLight: true,
          activeControlsWidgetColor: AppColors.primary,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          hideBottomControls: false,
          showCropGrid: true,
          cropGridColor: Colors.white54,
          cropFrameColor: Colors.white,
          dimmedLayerColor: Colors.black.withAlpha((0.7 * 255).round()),
          cropStyle: CropStyle.rectangle,
          aspectRatioPresets: [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
          ],
        ),
        IOSUiSettings(
          title: 'Crop',
          cancelButtonTitle: 'Cancel',
          doneButtonTitle: 'Done',
          aspectRatioLockEnabled: false,
          resetAspectRatioEnabled: true,
          cropStyle: CropStyle.rectangle,
          aspectRatioPickerButtonHidden: false,
        ),
      ],
    );

    if (cropped == null) return;
    if (!mounted) return;

    setState(() {
      _currentImageFile = File(cropped.path);
    });
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ResponsiveLayoutBuilder(
        builder: (context, constraints, breakpoint) {
          final responsive = ResponsiveSize(
            context: context,
            constraints: constraints,
            breakpoint: breakpoint,
          );

          return SafeArea(
            child: Column(
              children: [
                // Top bar: close, name, action icons
                _buildTopBar(responsive),

                // Image preview (expandable, pinch-to-zoom)
                Expanded(child: _buildImagePreview(responsive)),

                // Caption + send bar
                _buildBottomSection(responsive),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Top bar: [X close]  receiverName  [🗑️] [📷] [✂️]
  Widget _buildTopBar(ResponsiveSize responsive) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.spacing(4),
        vertical: responsive.spacing(8),
      ),
      child: Row(
        children: [
          // Close / discard
          _buildCircleAction(
            icon: Icons.close,
            onTap: _handleDelete,
            responsive: responsive,
          ),
          SizedBox(width: responsive.spacing(8)),
          // Receiver name + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.receiverName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: responsive.size(16),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Photo',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: responsive.size(12),
                  ),
                ),
              ],
            ),
          ),
          // Action icons: delete, retake, crop
          _buildCircleAction(
            icon: Icons.delete_outline_rounded,
            onTap: _handleDelete,
            responsive: responsive,
            tooltip: 'Delete',
          ),
          SizedBox(width: responsive.spacing(4)),
          _buildCircleAction(
            icon: Icons.camera_alt_outlined,
            onTap: _handleRetake,
            responsive: responsive,
            tooltip: 'Retake',
          ),
          SizedBox(width: responsive.spacing(4)),
          _buildCircleAction(
            icon: Icons.crop_rotate_rounded,
            onTap: _handleCrop,
            responsive: responsive,
            tooltip: 'Crop',
          ),
        ],
      ),
    );
  }

  /// Circular dark icon button used in top bar
  Widget _buildCircleAction({
    required IconData icon,
    required VoidCallback onTap,
    required ResponsiveSize responsive,
    String? tooltip,
  }) {
    final btn = GestureDetector(
      onTap: _isSending ? null : onTap,
      child: Container(
        width: responsive.size(36),
        height: responsive.size(36),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha((0.12 * 255).round()),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: responsive.size(20)),
      ),
    );
    if (tooltip != null) {
      return Tooltip(message: tooltip, child: btn);
    }
    return btn;
  }

  /// Image preview with pinch-to-zoom
  Widget _buildImagePreview(ResponsiveSize responsive) {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: Image.file(
          _currentImageFile,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.broken_image,
                  color: Colors.white54,
                  size: responsive.size(64),
                ),
                SizedBox(height: responsive.spacing(16)),
                Text(
                  'Failed to load image',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: responsive.size(16),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Bottom section: caption text field + receiver name row with send FAB
  Widget _buildBottomSection(ResponsiveSize responsive) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Container(
        color: Colors.black,
        padding: EdgeInsets.only(
          left: responsive.spacing(8),
          right: responsive.spacing(8),
          top: responsive.spacing(8),
          bottom: responsive.spacing(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Caption input
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1F2C34),
                borderRadius: BorderRadius.circular(responsive.size(24)),
              ),
              child: Row(
                children: [
                  SizedBox(width: responsive.spacing(16)),
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    color: Colors.white54,
                    size: responsive.size(22),
                  ),
                  SizedBox(width: responsive.spacing(8)),
                  Expanded(
                    child: TextField(
                      controller: _captionController,
                      focusNode: _captionFocusNode,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: responsive.size(14),
                      ),
                      maxLines: 3,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Add a caption...',
                        hintStyle: TextStyle(
                          color: Colors.white38,
                          fontSize: responsive.size(14),
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: responsive.spacing(10),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: responsive.spacing(12)),
                ],
              ),
            ),
            SizedBox(height: responsive.spacing(10)),
            // Receiver name + Send FAB
            Row(
              children: [
                SizedBox(width: responsive.spacing(8)),
                Expanded(
                  child: Text(
                    widget.receiverName,
                    style: AppTextSizes.small(context).copyWith(
                      color: Colors.white60,
                      fontSize: responsive.size(13),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Green send FAB
                GestureDetector(
                  onTap: _handleSend,
                  child: Container(
                    width: responsive.size(48),
                    height: responsive.size(48),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: _isSending
                        ? Padding(
                            padding: EdgeInsets.all(responsive.spacing(12)),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: responsive.size(2.5),
                            ),
                          )
                        : Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: responsive.size(22),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
