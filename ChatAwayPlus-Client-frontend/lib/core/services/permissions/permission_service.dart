// ============================================================================
// PERMISSION SERVICE - Base Permission Interface
// ============================================================================
// This is the BASE interface that all permission services implement.
//
// WHY NEEDED:
// - Ensures all permission services have consistent methods
// - Easy to add new permission types
// - Type-safe permission handling
//
// WHAT GOES HERE:
// 1. Define common permission methods (request, check, openSettings)
// 2. Abstract class that others extend
// 3. Common permission logic
//
// HOW OTHER SERVICES USE THIS:
//   class ContactsPermission extends PermissionService {
//     // Implements request(), check(), etc.
//   }
//
// TEAM EXAMPLE:
//   abstract class PermissionService {
//     Future<bool> request();
//     Future<bool> check();
//     Future<void> openSettings();
//   }
//
// ============================================================================

// TODO: Define abstract PermissionService class
// TODO: Add abstract request() method
// TODO: Add abstract check() method
// TODO: Add abstract openSettings() method
// TODO: Add common permission utilities
