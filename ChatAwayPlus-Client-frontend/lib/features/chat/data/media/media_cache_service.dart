// lib/features/chat/data/media/media_cache_service.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:chataway_plus/core/constants/api_url/api_urls.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import 'package:chataway_plus/core/database/app_database.dart';

/// Service to download and cache media files locally
/// Enables offline viewing of images, videos, and PDFs
class MediaCacheService {
  static final MediaCacheService _instance = MediaCacheService._internal();
  factory MediaCacheService() => _instance;
  static MediaCacheService get instance => _instance;
  MediaCacheService._internal();

  final http.Client _httpClient = http.Client();
  final TokenSecureStorage _tokenStorage = TokenSecureStorage.instance;

  /// Get the cache directory for media files
  Future<Directory> get _cacheDirectory async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory(path.join(appDir.path, 'media_cache'));
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// Download file from server and cache it locally
  /// Returns the local file path
  Future<String?> downloadAndCacheFile({
    required String messageId,
    required String fileUrl, // S3 key: 'uploads/user-id/filename.jpg'
    required String messageType,
    Function(double progress)? onProgress,
  }) async {
    try {
      debugPrint('📥 FileCacheService: Downloading file');
      debugPrint('📥 Message ID: $messageId');
      debugPrint('📥 File URL: $fileUrl');
      debugPrint('📥 Message type: $messageType');

      // Check if already cached
      final cachedPath = await _getCachedFilePath(messageId);
      if (cachedPath != null) {
        final file = File(cachedPath);
        if (await file.exists()) {
          debugPrint('✅ File already cached: $cachedPath');
          return cachedPath;
        }
      }

      // Get auth token
      final token = await _tokenStorage.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('⚠️ No auth token, skipping download');
        return null;
      }

      // Download file
      final Uri uri;
      if (fileUrl.startsWith('http')) {
        uri = Uri.parse(fileUrl);
      } else if (fileUrl.startsWith('/api/')) {
        uri = Uri.parse('${ApiUrls.mediaBaseUrl}$fileUrl');
      } else {
        uri = Uri.parse('${ApiUrls.apiBaseUrl}/chats/file/$fileUrl');
      }
      debugPrint('📥 Downloading from: $uri');

      final request = http.Request('GET', uri);
      request.headers['Authorization'] = 'Bearer $token';

      final streamedResponse = await _httpClient.send(request);

      if (streamedResponse.statusCode != 200) {
        debugPrint('❌ Download failed: ${streamedResponse.statusCode}');
        return null;
      }

      // Determine file extension from URL or messageType
      final ext = _getFileExtension(fileUrl, messageType);
      final cacheDir = await _cacheDirectory;
      final localPath = path.join(cacheDir.path, '$messageId$ext');
      final file = File(localPath);

      // Track download progress
      final contentLength = streamedResponse.contentLength ?? 0;
      int bytesDownloaded = 0;

      // Write file
      final sink = file.openWrite();
      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        bytesDownloaded += chunk.length;
        if (onProgress != null && contentLength > 0) {
          final progress = (bytesDownloaded / contentLength) * 100;
          onProgress(progress);
        }
      }
      await sink.close();

      debugPrint('✅ File downloaded and cached: $localPath');
      debugPrint('✅ File size: ${await file.length()} bytes');

      // Update database with cached path
      await _updateCachedPath(messageId, localPath);

      return localPath;
    } catch (e, stackTrace) {
      debugPrint('❌ FileCacheService error: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      return null;
    }
  }

  /// Get file extension from URL or message type
  String _getFileExtension(String fileUrl, String messageType) {
    // Try to get extension from URL
    final urlExt = path.extension(fileUrl);
    if (urlExt.isNotEmpty) {
      return urlExt;
    }

    // Fallback to message type
    switch (messageType) {
      case 'image':
        return '.jpg';
      case 'video':
        return '.mp4';
      case 'pdf':
      case 'document':
        return '.pdf';
      default:
        return '.dat';
    }
  }

  /// Get cached file path from database
  Future<String?> _getCachedFilePath(String messageId) async {
    try {
      final db = await AppDatabaseManager.instance.database;
      final result = await db.query(
        MessagesTable.tableName,
        columns: [MessagesTable.columnCachedFilePath],
        where: '${MessagesTable.columnId} = ?',
        whereArgs: [messageId],
        limit: 1,
      );

      if (result.isNotEmpty) {
        return result.first[MessagesTable.columnCachedFilePath] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting cached path: $e');
      return null;
    }
  }

  /// Update database with cached file path
  Future<void> _updateCachedPath(String messageId, String cachedPath) async {
    try {
      final db = await AppDatabaseManager.instance.database;
      await db.update(
        MessagesTable.tableName,
        {MessagesTable.columnCachedFilePath: cachedPath},
        where: '${MessagesTable.columnId} = ?',
        whereArgs: [messageId],
      );
      debugPrint('✅ Updated cached path in database');
    } catch (e) {
      debugPrint('❌ Error updating cached path: $e');
    }
  }

  /// Get cached file path for a message
  /// Returns the local path if cached, otherwise null
  Future<String?> getCachedFile(String messageId) async {
    final cachedPath = await _getCachedFilePath(messageId);
    if (cachedPath == null) return null;

    final file = File(cachedPath);
    if (await file.exists()) {
      return cachedPath;
    }

    return null;
  }

  /// Cache a local file to permanent storage (for sender's files)
  /// This ensures the sender can view their sent files without re-downloading
  /// even after the original temp file (from file picker) is cleaned up
  Future<String?> cacheLocalFile({
    required String messageId,
    required File sourceFile,
    required String messageType,
  }) async {
    try {
      if (!await sourceFile.exists()) {
        debugPrint('⚠️ Source file does not exist: ${sourceFile.path}');
        return null;
      }

      // Check if already cached
      final existingCached = await getCachedFile(messageId);
      if (existingCached != null) {
        debugPrint('✅ File already cached: $existingCached');
        return existingCached;
      }

      // Determine file extension
      final ext = _getFileExtension(sourceFile.path, messageType);
      final cacheDir = await _cacheDirectory;
      final cachedPath = path.join(cacheDir.path, '$messageId$ext');

      // Copy file to cache
      await sourceFile.copy(cachedPath);

      debugPrint('✅ File cached locally: $cachedPath');

      // Update database with cached path
      await _updateCachedPath(messageId, cachedPath);

      return cachedPath;
    } catch (e) {
      debugPrint('❌ Error caching local file: $e');
      return null;
    }
  }

  /// Check if a file is cached
  Future<bool> isFileCached(String messageId) async {
    final cachedPath = await getCachedFile(messageId);
    return cachedPath != null;
  }

  /// Clear cache for a specific message
  Future<void> clearMessageCache(String messageId) async {
    try {
      final cachedPath = await _getCachedFilePath(messageId);
      if (cachedPath != null) {
        final file = File(cachedPath);
        if (await file.exists()) {
          await file.delete();
          debugPrint('✅ Deleted cached file: $cachedPath');
        }
      }

      // Update database
      final db = await AppDatabaseManager.instance.database;
      await db.update(
        MessagesTable.tableName,
        {MessagesTable.columnCachedFilePath: null},
        where: '${MessagesTable.columnId} = ?',
        whereArgs: [messageId],
      );
    } catch (e) {
      debugPrint('❌ Error clearing cache: $e');
    }
  }

  /// Clear all cached files
  Future<void> clearAllCache() async {
    try {
      final cacheDir = await _cacheDirectory;
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create();
        debugPrint('✅ Cleared all cached files');
      }

      // Update database
      final db = await AppDatabaseManager.instance.database;
      await db.update(MessagesTable.tableName, {
        MessagesTable.columnCachedFilePath: null,
      });
    } catch (e) {
      debugPrint('❌ Error clearing all cache: $e');
    }
  }

  /// Get total cache size in bytes
  Future<int> getCacheSize() async {
    try {
      final cacheDir = await _cacheDirectory;
      if (!await cacheDir.exists()) return 0;

      int totalSize = 0;
      await for (final entity in cacheDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      return totalSize;
    } catch (e) {
      debugPrint('❌ Error getting cache size: $e');
      return 0;
    }
  }

  /// Get cache size in human-readable format
  Future<String> getCacheSizeFormatted() async {
    final bytes = await getCacheSize();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Dispose resources
  void dispose() {
    _httpClient.close();
  }
}
