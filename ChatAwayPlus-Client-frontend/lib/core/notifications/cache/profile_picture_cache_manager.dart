// ============================================================================
// PROFILE PICTURE CACHE MANAGER
// ============================================================================
// Manages profile picture caching for notifications with a cache-first approach
//
// FLOW:
// 1. Check SQLite cache first
// 2. If cached and URL matches → Return instantly ⚡
// 3. If not cached or URL changed → Download, process, save to cache
// 4. Handle cleanup and invalidation
//
// USAGE:
// ```dart
// final cacheManager = ProfilePictureCacheManager();
// final bitmap = await cacheManager.getCircularProfilePicture(
//   userId: 'user-123',
//   chatPictureUrl: '/uploads/profile/pic.jpg',
// );
// ```
// ============================================================================

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'dart:math';
import 'package:path_provider/path_provider.dart';

import 'package:chataway_plus/core/database/tables/cache/profile_picture_cache_table.dart';
import 'package:chataway_plus/core/constants/api_url/api_urls.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';

/// Profile Picture Cache Manager
/// Handles downloading, processing, caching, and retrieval of profile pictures
class ProfilePictureCacheManager {
  // Singleton pattern
  static ProfilePictureCacheManager? _instance;

  ProfilePictureCacheManager._();

  static ProfilePictureCacheManager get instance {
    _instance ??= ProfilePictureCacheManager._();
    return _instance!;
  }

  /// Get circular profile picture with cache-first approach
  ///
  /// Returns ByteArrayAndroidBitmap ready for notification display
  ///
  /// FLOW:
  /// 1. Check cache → If found and URL matches, return instantly ⚡
  /// 2. If not cached → Download from server
  /// 3. Process to circular bitmap
  /// 4. Save to cache for next time
  /// 5. Return processed bitmap
  Future<ByteArrayAndroidBitmap?> getCircularProfilePicture({
    required String userId,
    String? chatPictureUrl,
  }) async {
    // Validate inputs
    if (chatPictureUrl == null || chatPictureUrl.isEmpty) {
      debugPrint('🖼️ [ProfileCache] No profile picture URL provided');
      return null;
    }

    try {
      debugPrint('🔍 [ProfileCache] Getting profile picture for: $userId');

      // STEP 1: Check cache first (CACHE-FIRST APPROACH) ⚡
      final cachedBytes =
          await ProfilePictureCacheTable.getCachedProfilePicture(
            userId: userId,
            currentProfileUrl: chatPictureUrl,
          );

      if (cachedBytes != null) {
        // Cache HIT! Return immediately ⚡
        debugPrint('⚡ [ProfileCache] Using cached bitmap (instant!)');
        // Also ensure native file cache exists for Kotlin (killed-state notifications)
        _ensureNativeCacheExists(userId, cachedBytes);
        return ByteArrayAndroidBitmap(cachedBytes);
      }

      // STEP 2: Cache MISS - Download and process
      debugPrint('📥 [ProfileCache] Cache miss, downloading and processing...');

      final circularBitmapBytes = await _downloadAndProcessProfilePicture(
        chatPictureUrl: chatPictureUrl,
      );

      if (circularBitmapBytes != null) {
        // STEP 3: Save to cache for next time
        await ProfilePictureCacheTable.saveToCache(
          userId: userId,
          profileUrl: chatPictureUrl,
          circularBitmapBytes: circularBitmapBytes,
        );

        // STEP 3b: Also save to native file cache for Kotlin access (killed-state notifications)
        await _saveToNativeCache(userId, circularBitmapBytes);

        // STEP 4: Return processed bitmap
        return ByteArrayAndroidBitmap(circularBitmapBytes);
      }

      return null;
    } catch (e, stackTrace) {
      debugPrint('❌ [ProfileCache] Error getting profile picture: $e');
      debugPrint('❌ [ProfileCache] Stack trace: $stackTrace');
      return null;
    }
  }

  /// Download and process profile picture to circular bitmap
  /// This is only called on cache miss
  Future<Uint8List?> _downloadAndProcessProfilePicture({
    required String chatPictureUrl,
  }) async {
    try {
      // Download image
      final imageBytes = await _downloadImage(chatPictureUrl);
      if (imageBytes == null) return null;

      // Process to circular bitmap
      final circularBytes = await _createCircularBitmap(imageBytes);

      return circularBytes;
    } catch (e) {
      debugPrint('❌ [ProfileCache] Error in download and process: $e');
      return null;
    }
  }

  /// Download image from server
  Future<Uint8List?> _downloadImage(String profilePicPath) async {
    try {
      String fullUrl;

      // Build full URL
      if (profilePicPath.startsWith('/')) {
        fullUrl = '${ApiUrls.mediaBaseUrl}$profilePicPath';
      } else if (profilePicPath.startsWith('http')) {
        fullUrl = profilePicPath;
      } else {
        debugPrint('❌ [ProfileCache] Invalid profile picture path');
        return null;
      }

      debugPrint('📥 [ProfileCache] Downloading from: $fullUrl');

      // Get authentication token
      final token = await TokenSecureStorage.instance.getToken();

      final headers = <String, String>{
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http
          .get(Uri.parse(fullUrl), headers: headers)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        debugPrint('✅ [ProfileCache] Downloaded successfully');
        return response.bodyBytes;
      } else {
        debugPrint(
          '❌ [ProfileCache] Download failed with status: ${response.statusCode}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('❌ [ProfileCache] Error downloading image: $e');
      return null;
    }
  }

  /// Create circular bitmap from image bytes
  /// Optimized for notification display (64x64 pixels)
  Future<Uint8List?> _createCircularBitmap(Uint8List imageBytes) async {
    try {
      debugPrint('🎨 [ProfileCache] Creating circular bitmap...');

      final img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        debugPrint('❌ [ProfileCache] Failed to decode image');
        return null;
      }

      // Resize to notification size (64x64) to save space
      const targetSize = 128; // 2x for better quality on high DPI
      final resizedImage = img.copyResize(
        image,
        width: targetSize,
        height: targetSize,
        interpolation: img.Interpolation.linear,
      );

      final size = resizedImage.width;

      // Create circular image
      final circularImage = img.Image(
        width: size,
        height: size,
        numChannels: 4,
      );

      // Fill with transparent background
      img.fill(circularImage, color: img.ColorRgba8(0, 0, 0, 0));

      final radius = size / 2;
      final centerX = size / 2;
      final centerY = size / 2;

      // Apply circular mask
      for (int y = 0; y < size; y++) {
        for (int x = 0; x < size; x++) {
          final dx = x - centerX;
          final dy = y - centerY;
          final distance = sqrt(dx * dx + dy * dy);

          if (distance <= radius) {
            circularImage.setPixel(x, y, resizedImage.getPixel(x, y));
          }
        }
      }

      // Encode to PNG with compression
      final circularBytes = img.encodePng(
        circularImage,
        level: 6, // Compression level (0-9, 6 is good balance)
      );

      debugPrint(
        '✅ [ProfileCache] Circular bitmap created (${circularBytes.length} bytes)',
      );

      return Uint8List.fromList(circularBytes);
    } catch (e) {
      debugPrint('❌ [ProfileCache] Error creating circular bitmap: $e');
      return null;
    }
  }

  /// Invalidate cache when profile picture changes
  /// Call this when user updates their profile picture
  Future<void> invalidateCacheForUser(String userId) async {
    await ProfilePictureCacheTable.invalidateCache(userId);
    await _deleteNativeCache(userId);
  }

  Future<void> _deleteNativeCache(String userId) async {
    try {
      if (userId.isEmpty) return;
      final cacheDir = await getTemporaryDirectory();
      final file = File('${cacheDir.path}/notif_avatar_$userId.png');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  /// Cleanup old cache entries
  /// Call this periodically (e.g., on app start or during idle time)
  Future<void> cleanupOldCache({int daysOld = 30}) async {
    await ProfilePictureCacheTable.cleanupOldEntries(daysOld: daysOld);
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    return await ProfilePictureCacheTable.getCacheStats();
  }

  /// Clear all cache
  Future<void> clearAllCache() async {
    await ProfilePictureCacheTable.clearAllCache();
  }

  /// Save avatar to native file cache for Kotlin access (killed-state notifications)
  /// Kotlin reads from: cacheDir/notif_avatar_$senderId.png
  Future<void> _saveToNativeCache(String userId, Uint8List bytes) async {
    try {
      if (userId.isEmpty) return;
      final cacheDir = await getTemporaryDirectory();
      final file = File('${cacheDir.path}/notif_avatar_$userId.png');
      await file.writeAsBytes(bytes, flush: true);
      debugPrint('📁 [ProfileCache] Saved to native cache: ${file.path}');
    } catch (e) {
      debugPrint('⚠️ [ProfileCache] Failed to save to native cache: $e');
    }
  }

  /// Ensure native file cache exists for Kotlin access (fire-and-forget, non-blocking)
  /// Called on cache HIT to ensure Kotlin can find the avatar when app is killed
  void _ensureNativeCacheExists(String userId, Uint8List bytes) {
    if (userId.isEmpty) return;
    Future.microtask(() async {
      try {
        final cacheDir = await getTemporaryDirectory();
        final file = File('${cacheDir.path}/notif_avatar_$userId.png');
        if (!await file.exists()) {
          await file.writeAsBytes(bytes, flush: true);
          debugPrint(
            '📁 [ProfileCache] Created native cache for Kotlin: ${file.path}',
          );
        }
      } catch (e) {
        debugPrint('⚠️ [ProfileCache] Failed to ensure native cache: $e');
      }
    });
  }

  /// Prewarm cache for frequent contacts
  /// Call this during app idle time to cache profile pictures
  /// for contacts that are likely to send messages
  Future<void> prewarmCacheForFrequentContacts(
    List<Map<String, String>> contacts,
  ) async {
    debugPrint(
      '🔥 [ProfileCache] Prewarming cache for ${contacts.length} contacts',
    );

    for (final contact in contacts) {
      final userId = contact['user_id'];
      final profileUrl = contact['profile_url'];

      if (userId == null || profileUrl == null) continue;

      try {
        // This will download, process, and cache if not already cached
        await getCircularProfilePicture(
          userId: userId,
          chatPictureUrl: profileUrl,
        );

        // Small delay to avoid overwhelming the server
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        debugPrint('⚠️ [ProfileCache] Failed to prewarm for $userId: $e');
      }
    }

    debugPrint('✅ [ProfileCache] Prewarm complete');
  }
}
