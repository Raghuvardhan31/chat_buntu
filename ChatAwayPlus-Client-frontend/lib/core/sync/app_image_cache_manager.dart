import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'sync_config.dart';
import 'authenticated_image_cache_manager.dart';

/// Cache manager for non-authenticated images.
/// Uses PersistentFileSystem to store files in app documents directory (permanent)
/// instead of temp cache directory (which OS can delete on low storage).
class AppImageCacheManager extends CacheManager {
  static const String key = 'chataway_plus_image_cache_v2';
  static final AppImageCacheManager instance = AppImageCacheManager._internal();

  AppImageCacheManager._internal()
    : super(
        Config(
          key,
          stalePeriod: SyncConfig.imageStalePeriod,
          maxNrOfCacheObjects: SyncConfig.imageCacheMaxObjects,
          fileSystem: PersistentFileSystem(key),
          fileService: HttpFileService(),
        ),
      );
}
