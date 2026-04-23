// ============================================================================
// CAMERA PERMISSION - Handle Camera Access
// ============================================================================
// This file handles camera permission for profile pictures and photo sharing.
//
// WHEN NEEDED:
// - User wants to take profile picture
// - User wants to share photo in chat (future feature)
// - User wants to scan QR code (future feature)
//
// WHAT GOES HERE:
// 1. Request camera permission
// 2. Check if camera permission granted
// 3. Open app settings if permission denied
// 4. Handle permission denied permanently
//
// TEAM EXAMPLE:
//   final cameraPermission = CameraPermission.instance;
//   
//   if (await cameraPermission.isGranted) {
//     // Open camera
//     openCamera();
//   } else {
//     // Request permission
//     final granted = await cameraPermission.request();
//     if (granted) {
//       openCamera();
//     } else {
//       showPermissionDeniedDialog();
//     }
//   }
//
// USES:
// - permission_handler package
// - Extends PermissionService base class
//
// ============================================================================

// TODO: Import permission_handler
// TODO: Import permission_service.dart
// TODO: Create singleton instance
// TODO: Add request() method
// TODO: Add isGranted getter
// TODO: Add openSettings() method
