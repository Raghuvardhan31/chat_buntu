import 'dart:io' as io;
import 'package:file/file.dart' hide FileSystem;
import 'package:file/local.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'sync_config.dart';

/// Custom FileSystem that stores files in app DOCUMENTS directory (permanent)
/// instead of temp CACHE directory (which OS can delete anytime on low storage).
/// This ensures offline images persist reliably across all devices.
class PersistentFileSystem implements FileSystem {
  final Future<Directory> _fileDir;
  final String _cacheKey;

  PersistentFileSystem(this._cacheKey)
    : _fileDir = _createPersistentDirectory(_cacheKey);

  static Future<Directory> _createPersistentDirectory(String key) async {
    // Use app documents directory (permanent) instead of temp directory
    final baseDir = await getApplicationDocumentsDirectory();
    final path = p.join(baseDir.path, 'image_cache', key);
    const fs = LocalFileSystem();
    final directory = fs.directory(path);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  @override
  Future<File> createFile(String name) async {
    final directory = await _fileDir;
    if (!await directory.exists()) {
      await _createPersistentDirectory(_cacheKey);
    }
    return directory.childFile(name);
  }
}

/// Custom file service that adds authentication headers to image requests
class AuthenticatedHttpFileService extends FileService {
  static final io.HttpClient _http = io.HttpClient();

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    // Get auth token
    final token = await TokenSecureStorage.instance.getToken();

    // Merge headers with auth token
    final authHeaders = <String, String>{
      ...?headers,
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final uri = Uri.parse(url);
    final request = await _http.getUrl(uri);

    // Add headers to request
    authHeaders.forEach((key, value) {
      request.headers.set(key, value);
    });

    final response = await request.close();

    return AuthenticatedFileServiceResponse(response, url: url);
  }
}

/// Response wrapper for authenticated HTTP requests
class AuthenticatedFileServiceResponse implements FileServiceResponse {
  final io.HttpClientResponse _response;
  final String _url;

  AuthenticatedFileServiceResponse(this._response, {required String url})
    : _url = url;

  @override
  Stream<List<int>> get content => _response;

  @override
  int? get contentLength {
    final length = _response.contentLength;
    // Return null if content length is unknown (-1) to avoid assertion errors
    return (length < 0) ? null : length;
  }

  @override
  String? get eTag => _response.headers.value(io.HttpHeaders.etagHeader);

  @override
  String get fileExtension {
    final contentType = _response.headers.contentType;
    final mimeType = contentType?.mimeType;
    if (mimeType == 'image/jpeg') return 'jpg';
    if (mimeType == 'image/png') return 'png';
    if (mimeType == 'image/webp') return 'webp';
    if (mimeType == 'image/heic') return 'heic';
    if (mimeType == 'image/gif') return 'gif';
    if (mimeType == 'image/bmp') return 'bmp';
    if (mimeType == 'video/mp4') return 'mp4';
    if (mimeType == 'video/quicktime') return 'mov';
    if (mimeType == 'video/x-matroska') return 'mkv';
    if (mimeType == 'video/webm') return 'webm';

    final uri = Uri.tryParse(_url);
    final path = uri?.path;
    if (path != null && path.isNotEmpty) {
      final lastDot = path.lastIndexOf('.');
      if (lastDot >= 0 && lastDot < path.length - 1) {
        return path.substring(lastDot + 1).toLowerCase();
      }
    }

    return 'jpg';
  }

  @override
  int get statusCode => _response.statusCode;

  @override
  DateTime get validTill {
    // Check cache-control header
    final cacheControl = _response.headers.value(
      io.HttpHeaders.cacheControlHeader,
    );
    if (cacheControl != null) {
      final lower = cacheControl.toLowerCase();
      if (lower.contains('no-store') || lower.contains('no-cache')) {
        return DateTime.now();
      }
      final maxAgeMatch = RegExp(r'max-age=(\d+)').firstMatch(cacheControl);
      if (maxAgeMatch != null) {
        final maxAge = int.tryParse(maxAgeMatch.group(1) ?? '0') ?? 0;
        return DateTime.now().add(Duration(seconds: maxAge));
      }
    }

    final expires = _response.headers.value(io.HttpHeaders.expiresHeader);
    if (expires != null && expires.isNotEmpty) {
      try {
        return io.HttpDate.parse(expires);
      } catch (_) {}
    }

    // Use default stale period
    return DateTime.now().add(SyncConfig.imageStalePeriod);
  }
}

/// Cache manager for authenticated image requests (profile pictures, etc.)
/// Uses PersistentFileSystem to store files in app documents directory (permanent)
/// instead of temp cache directory (which OS can delete on low storage).
class AuthenticatedImageCacheManager extends CacheManager {
  static const String key = 'chataway_plus_auth_image_cache_v2';
  static final AuthenticatedImageCacheManager instance =
      AuthenticatedImageCacheManager._internal();

  AuthenticatedImageCacheManager._internal()
    : super(
        Config(
          key,
          stalePeriod: SyncConfig.imageStalePeriod,
          maxNrOfCacheObjects: SyncConfig.imageCacheMaxObjects,
          fileSystem: PersistentFileSystem(key),
          fileService: AuthenticatedHttpFileService(),
        ),
      );
}
