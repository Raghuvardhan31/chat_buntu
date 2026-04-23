// lib/features/chat/utils/chat_image_utils.dart

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:image/image.dart' as img;

/// Utility class for handling image-related operations in chat
class ChatImageUtils {
  /// Get image dimensions from a file
  /// Returns a Size object with width and height
  static Future<ui.Size> getImageDimensions(File imageFile) async {
    try {
      final Uint8List bytes = await imageFile.readAsBytes();

      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        final baked = img.bakeOrientation(decoded);
        return ui.Size(baked.width.toDouble(), baked.height.toDouble());
      }

      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;

      final size = ui.Size(image.width.toDouble(), image.height.toDouble());

      image.dispose();
      codec.dispose();

      return size;
    } catch (e) {
      // Return a default size if we can't get dimensions
      return const ui.Size(800, 600);
    }
  }

  /// Calculate aspect ratio from dimensions
  static double calculateAspectRatio(int width, int height) {
    if (width <= 0 || height <= 0) return 1.0;
    return width / height;
  }

  /// Get optimized dimensions for display (maintaining aspect ratio)
  static ui.Size getOptimizedDisplaySize({
    required int originalWidth,
    required int originalHeight,
    required double maxWidth,
    required double maxHeight,
  }) {
    if (originalWidth <= 0 || originalHeight <= 0) {
      return ui.Size(maxWidth, maxHeight);
    }

    final aspectRatio = originalWidth / originalHeight;
    double displayWidth;
    double displayHeight;

    if (aspectRatio > 1) {
      // Landscape
      displayWidth = maxWidth;
      displayHeight = displayWidth / aspectRatio;

      if (displayHeight > maxHeight) {
        displayHeight = maxHeight;
        displayWidth = displayHeight * aspectRatio;
      }
    } else {
      // Portrait or square
      displayHeight = maxHeight;
      displayWidth = displayHeight * aspectRatio;

      if (displayWidth > maxWidth) {
        displayWidth = maxWidth;
        displayHeight = displayWidth / aspectRatio;
      }
    }

    return ui.Size(displayWidth, displayHeight);
  }
}
