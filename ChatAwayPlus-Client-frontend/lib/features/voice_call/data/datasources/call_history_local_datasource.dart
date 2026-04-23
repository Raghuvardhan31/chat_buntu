import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:chataway_plus/core/database/app_database.dart';
import 'package:chataway_plus/features/voice_call/data/models/call_model.dart';

/// Local SQLite datasource for call history
/// Saves all call records offline so they persist without trusting server
class CallHistoryLocalDatasource {
  CallHistoryLocalDatasource._();
  static final CallHistoryLocalDatasource instance =
      CallHistoryLocalDatasource._();

  /// Insert or update a call record
  Future<void> saveCall(CallModel call) async {
    try {
      final db = await AppDatabaseManager.instance.database;
      await db.insert(
        CallHistoryTable.tableName,
        _callToMap(call),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ CallHistoryLocal: Failed to save call: $e');
      }
    }
  }

  /// Insert multiple call records (e.g. from server sync)
  Future<void> saveCallsBatch(List<CallModel> calls) async {
    if (calls.isEmpty) return;
    try {
      final db = await AppDatabaseManager.instance.database;
      final batch = db.batch();
      for (final call in calls) {
        batch.insert(
          CallHistoryTable.tableName,
          _callToMap(call),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await batch.commit(noResult: true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ CallHistoryLocal: Failed to save batch: $e');
      }
    }
  }

  /// Get all call history sorted by timestamp descending
  Future<List<CallModel>> getAllCalls({int limit = 100}) async {
    try {
      final db = await AppDatabaseManager.instance.database;
      final rows = await db.query(
        CallHistoryTable.tableName,
        orderBy: '${CallHistoryTable.columnTimestamp} DESC',
        limit: limit,
      );
      return rows.map(_mapToCall).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ CallHistoryLocal: Failed to get calls: $e');
      }
      return [];
    }
  }

  /// Get calls filtered by direction (incoming/outgoing)
  Future<List<CallModel>> getCallsByDirection(
    CallDirection direction, {
    int limit = 100,
  }) async {
    try {
      final db = await AppDatabaseManager.instance.database;
      final rows = await db.query(
        CallHistoryTable.tableName,
        where: '${CallHistoryTable.columnDirection} = ?',
        whereArgs: [direction.name],
        orderBy: '${CallHistoryTable.columnTimestamp} DESC',
        limit: limit,
      );
      return rows.map(_mapToCall).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ CallHistoryLocal: Failed to get calls by direction: $e');
      }
      return [];
    }
  }

  /// Get missed calls only
  Future<List<CallModel>> getMissedCalls({int limit = 100}) async {
    try {
      final db = await AppDatabaseManager.instance.database;
      final rows = await db.query(
        CallHistoryTable.tableName,
        where: '${CallHistoryTable.columnStatus} = ?',
        whereArgs: ['missed'],
        orderBy: '${CallHistoryTable.columnTimestamp} DESC',
        limit: limit,
      );
      return rows.map(_mapToCall).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ CallHistoryLocal: Failed to get missed calls: $e');
      }
      return [];
    }
  }

  /// Delete a single call record
  Future<void> deleteCall(String callId) async {
    try {
      final db = await AppDatabaseManager.instance.database;
      await db.delete(
        CallHistoryTable.tableName,
        where: '${CallHistoryTable.columnCallId} = ?',
        whereArgs: [callId],
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ CallHistoryLocal: Failed to delete call: $e');
      }
    }
  }

  /// Clear all call history
  Future<void> clearAll() async {
    try {
      final db = await AppDatabaseManager.instance.database;
      await db.delete(CallHistoryTable.tableName);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ CallHistoryLocal: Failed to clear calls: $e');
      }
    }
  }

  /// Get call count
  Future<int> getCallCount() async {
    try {
      final db = await AppDatabaseManager.instance.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${CallHistoryTable.tableName}',
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // MAPPING HELPERS
  // ═══════════════════════════════════════════════════════════════════

  Map<String, dynamic> _callToMap(CallModel call) {
    return {
      CallHistoryTable.columnCallId: call.id,
      CallHistoryTable.columnContactId: call.contactId,
      CallHistoryTable.columnContactName: call.contactName,
      CallHistoryTable.columnContactProfilePic: call.contactProfilePic,
      CallHistoryTable.columnCallType: call.callType.name,
      CallHistoryTable.columnDirection: call.direction.name,
      CallHistoryTable.columnStatus: call.status.name,
      CallHistoryTable.columnTimestamp: call.timestamp.millisecondsSinceEpoch,
      CallHistoryTable.columnDurationSeconds: call.durationSeconds,
    };
  }

  CallModel _mapToCall(Map<String, dynamic> row) {
    return CallModel(
      id: (row[CallHistoryTable.columnCallId] ?? '').toString(),
      contactId: (row[CallHistoryTable.columnContactId] ?? '').toString(),
      contactName: (row[CallHistoryTable.columnContactName] ?? 'Unknown')
          .toString(),
      contactProfilePic:
          row[CallHistoryTable.columnContactProfilePic] as String?,
      callType: CallType.values.firstWhere(
        (e) =>
            e.name ==
            (row[CallHistoryTable.columnCallType] ?? 'voice').toString(),
        orElse: () => CallType.voice,
      ),
      direction: CallDirection.values.firstWhere(
        (e) =>
            e.name ==
            (row[CallHistoryTable.columnDirection] ?? 'outgoing').toString(),
        orElse: () => CallDirection.outgoing,
      ),
      status: CallStatus.values.firstWhere(
        (e) =>
            e.name ==
            (row[CallHistoryTable.columnStatus] ?? 'ended').toString(),
        orElse: () => CallStatus.ended,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (row[CallHistoryTable.columnTimestamp] as int?) ?? 0,
      ),
      durationSeconds: row[CallHistoryTable.columnDurationSeconds] as int?,
    );
  }
}
