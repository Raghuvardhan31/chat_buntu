/// =============================================================================
/// PERMISSIONS SERVICES INDEX - CHATAWAY+ FLUTTER APPLICATION
/// =============================================================================
library;

/// Permissions Services Export File
///
/// Central export file for all permission-related services in the ChatAway+ app.
/// This allows for clean imports from anywhere in the app.
///
/// Usage:
/// ```dart
/// import 'package:chataway_plus/core/services/permissions/index.dart';
///
/// ContactPermissionsService.instance.requestPermission();
/// PhotosPermissionService.instance.requestPermission();
/// PermissionManager.instance.requestMultiplePermissions([...]);
/// ```

export 'contacts_permission_service.dart';
// Photo Permission Service
export 'photos_permission_service.dart';

// Permission Manager
export 'permission_manager.dart';

// Future permission services can be added here:
// export 'camera_permission_service.dart';
// export 'location_permission_service.dart';
