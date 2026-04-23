// ============================================================================
// APP STARTUP SNAPSHOT TABLE - Schema Definition & CRUD Operations
// ============================================================================
// Caches per-user startup routing snapshot for fast app launches (SWR pattern)
// Fields capture last known profile completeness and destination route
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../app_database.dart';

class AppStartupSnapshotTable {
  // ============================================================================
  // SCHEMA DEFINITIONS
  // ============================================================================

  /// Table name constant
  static const String tableName = 'app_startup_snapshot';

  /// Column name constants
  static const String columnUserId = 'user_id'; // ChatAway+ user UUID (PK)
  static const String columnProfileComplete = 'profile_complete'; // 0/1
  static const String columnLastKnownRoute =
      'last_known_route'; // chatList | currentUserProfile | phoneNumberEntry
  static const String columnLastVerifiedAt = 'last_verified_at'; // epoch millis

  /// SQL CREATE TABLE statement - App Startup Snapshot Table
  static const String createTableSQL =
      '''
CREATE TABLE $tableName (
  $columnUserId TEXT PRIMARY KEY,            -- ChatAway+ user UUID
  $columnProfileComplete INTEGER NOT NULL,   -- 0 = false, 1 = true
  $columnLastKnownRoute TEXT NOT NULL,       -- Last routed screen name
  $columnLastVerifiedAt INTEGER NOT NULL     -- Last verification timestamp (ms)
)
''';

  // ============================================================================
  // SINGLETON INSTANCE
  // ============================================================================

  AppStartupSnapshotTable._();
  static final AppStartupSnapshotTable _instance = AppStartupSnapshotTable._();
  static AppStartupSnapshotTable get instance => _instance;

  // Get database from AppDatabaseManager
  Future<Database> get _database async {
    return await AppDatabaseManager.instance.database;
  }

  // ============================================================================
  // CRUD OPERATIONS
  // ============================================================================

  /// Upsert snapshot for a user (REPLACE semantics on same user_id)
  Future<void> upsertSnapshot({
    required String userId,
    required bool profileComplete,
    required String lastKnownRoute,
    int? lastVerifiedAt,
  }) async {
    try {
      final db = await _database;
      await db.insert(tableName, {
        columnUserId: userId,
        columnProfileComplete: profileComplete ? 1 : 0,
        columnLastKnownRoute: lastKnownRoute,
        columnLastVerifiedAt:
            lastVerifiedAt ?? DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      if (kDebugMode) {
        debugPrint('✅ AppStartupSnapshot upserted for user: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ AppStartupSnapshot upsert error: $e');
      }
      rethrow;
    }
  }

  /// Get snapshot by userId
  Future<Map<String, Object?>?> getByUserId(String userId) async {
    try {
      final db = await _database;
      final rows = await db.query(
        tableName,
        where: '$columnUserId = ?',
        whereArgs: [userId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return rows.first;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ AppStartupSnapshot getByUserId error: $e');
      }
      return null;
    }
  }

  /// Delete snapshot for a user (on logout / account switch)
  Future<void> deleteByUserId(String userId) async {
    try {
      final db = await _database;
      await db.delete(
        tableName,
        where: '$columnUserId = ?',
        whereArgs: [userId],
      );
      if (kDebugMode) {
        debugPrint('✅ AppStartupSnapshot deleted for user: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ AppStartupSnapshot delete error: $e');
      }
      rethrow;
    }
  }

  /// Clear all snapshots (rare; maintenance)
  Future<void> clearAll() async {
    try {
      final db = await _database;
      await db.delete(tableName);
      if (kDebugMode) {
        debugPrint('✅ AppStartupSnapshot: cleared all rows');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ AppStartupSnapshot clearAll error: $e');
      }
      rethrow;
    }
  }

  // ============================================================================
  // HELPERS
  // ============================================================================

  /// Returns true if the provided snapshot row is fresh within [ttl]
  /// Default: 6 months (180 days) to match backend JWT/FCM token expiry
  bool isSnapshotFresh(
    Map<String, Object?> snapshot, {
    Duration ttl = const Duration(days: 180),
  }) {
    try {
      final last = (snapshot[columnLastVerifiedAt] as int?) ?? 0;
      final lastDt = DateTime.fromMillisecondsSinceEpoch(last, isUtc: false);
      return DateTime.now().difference(lastDt) <= ttl;
    } catch (_) {
      return false;
    }
  }
}
