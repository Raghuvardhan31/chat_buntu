// lib/features/profile/data/datasources/emoji_local_datasource.dart

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:chataway_plus/core/database/app_database.dart';
import '../models/emoji_model.dart';

/// Local datasource for emoji - handles emoji caching in database
/// Uses existing emoji_updates table from database
abstract class EmojiLocalDataSource {
  /// Save/update emoji to local database
  Future<void> saveEmoji(EmojiModel emoji);

  /// Save multiple emojis (batch operation)
  Future<void> saveAllEmojis(List<EmojiModel> emojis);

  /// Get emoji from local database
  Future<EmojiModel?> getEmoji();

  /// Get all emojis from local database
  Future<List<EmojiModel>> getAllEmojis();

  /// Update emoji fields
  Future<void> updateEmoji(String emoji, String caption);

  /// Clear emoji data (logout or delete)
  Future<void> clearEmoji();

  /// Check if emoji exists in local database
  Future<bool> emojiExists();

  /// Delete all emojis that do NOT belong to the specified user
  Future<void> deleteOtherUsersEmojis(String userId);
}

/// Implementation of [EmojiLocalDataSource] using existing emoji table
class EmojiLocalDataSourceImpl implements EmojiLocalDataSource {
  EmojiLocalDataSourceImpl();

  void _log(String message) {
    if (kDebugMode) debugPrint(message);
  }

  @override
  Future<void> saveEmoji(EmojiModel emoji) async {
    try {
      final db = await AppDatabaseManager.instance.database;

      final emojiData = {
        EmojiTable.columnId: emoji.id ?? '',
        EmojiTable.columnUserId: emoji.userId ?? '',
        EmojiTable.columnEmoji: emoji.emoji ?? '',
        EmojiTable.columnCaption: emoji.caption ?? '',
        EmojiTable.columnDeletedAt: emoji.deletedAt?.toIso8601String(),
        EmojiTable.columnCreatedAt: emoji.createdAt?.toIso8601String(),
        EmojiTable.columnUpdatedAt: emoji.updatedAt?.toIso8601String(),
        EmojiTable.columnUserFirstName: emoji.userFirstName ?? '',
        EmojiTable.columnUserLastName: emoji.userLastName ?? '',
        EmojiTable.columnUserProfilePic: emoji.userProfilePic ?? '',
      };

      _log(
        '[EmojiLocal] saveEmoji(): id=${emoji.id}, userId=${emoji.userId}, emoji="${emoji.emoji}", caption="${emoji.caption}"',
      );
      await db.insert(
        EmojiTable.tableName,
        emojiData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw Exception('Failed to save emoji locally: $e');
    }
  }

  @override
  Future<void> saveAllEmojis(List<EmojiModel> emojis) async {
    try {
      final db = await AppDatabaseManager.instance.database;
      final batch = db.batch();

      for (final emoji in emojis) {
        final emojiData = {
          EmojiTable.columnId: emoji.id ?? '',
          EmojiTable.columnUserId: emoji.userId ?? '',
          EmojiTable.columnEmoji: emoji.emoji ?? '',
          EmojiTable.columnCaption: emoji.caption ?? '',
          EmojiTable.columnDeletedAt: emoji.deletedAt?.toIso8601String(),
          EmojiTable.columnCreatedAt: emoji.createdAt?.toIso8601String(),
          EmojiTable.columnUpdatedAt: emoji.updatedAt?.toIso8601String(),
          EmojiTable.columnUserFirstName: emoji.userFirstName ?? '',
          EmojiTable.columnUserLastName: emoji.userLastName ?? '',
          EmojiTable.columnUserProfilePic: emoji.userProfilePic ?? '',
        };

        batch.insert(
          EmojiTable.tableName,
          emojiData,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
    } catch (e) {
      throw Exception('Failed to save all emojis locally: $e');
    }
  }

  @override
  Future<EmojiModel?> getEmoji() async {
    try {
      _log('[EmojiLocal] getEmoji(): reading');
      final db = await AppDatabaseManager.instance.database;

      final List<Map<String, dynamic>> maps = await db.query(
        EmojiTable.tableName,
        limit: 1,
      );

      if (maps.isEmpty) {
        _log('[EmojiLocal] getEmoji(): MISS');
        return null;
      }

      final data = maps.first;
      _log(
        '[EmojiLocal] getEmoji(): HIT -> emoji="${data[EmojiTable.columnEmoji]}" caption="${data[EmojiTable.columnCaption]}" userId=${data[EmojiTable.columnUserId]}',
      );
      return EmojiModel.fromJson({
        'id': data[EmojiTable.columnId],
        'userId': data[EmojiTable.columnUserId],
        'emoji': data[EmojiTable.columnEmoji],
        'caption': data[EmojiTable.columnCaption],
        'deletedAt': data[EmojiTable.columnDeletedAt],
        'createdAt': data[EmojiTable.columnCreatedAt],
        'updatedAt': data[EmojiTable.columnUpdatedAt],
        'userFirstName': data[EmojiTable.columnUserFirstName],
        'userLastName': data[EmojiTable.columnUserLastName],
        'userProfilePic': data[EmojiTable.columnUserProfilePic],
      });
    } catch (e) {
      _log('[EmojiLocal] getEmoji(): error: $e');
      return null;
    }
  }

  @override
  Future<List<EmojiModel>> getAllEmojis() async {
    try {
      _log('[EmojiLocal] getAllEmojis(): reading');
      final db = await AppDatabaseManager.instance.database;

      final List<Map<String, dynamic>> maps = await db.query(
        EmojiTable.tableName,
        orderBy: '${EmojiTable.columnUpdatedAt} DESC',
      );

      if (maps.isEmpty) {
        _log('[EmojiLocal] getAllEmojis(): MISS (0 rows)');
        return [];
      }

      _log(
        '[EmojiLocal] getAllEmojis(): HIT count=${maps.length}; latest emoji="${maps.first[EmojiTable.columnEmoji]}" caption="${maps.first[EmojiTable.columnCaption]}" userId=${maps.first[EmojiTable.columnUserId]}',
      );

      return maps.map((data) {
        return EmojiModel.fromJson({
          'id': data[EmojiTable.columnId],
          'userId': data[EmojiTable.columnUserId],
          'emoji': data[EmojiTable.columnEmoji],
          'caption': data[EmojiTable.columnCaption],
          'deletedAt': data[EmojiTable.columnDeletedAt],
          'createdAt': data[EmojiTable.columnCreatedAt],
          'updatedAt': data[EmojiTable.columnUpdatedAt],
          'userFirstName': data[EmojiTable.columnUserFirstName],
          'userLastName': data[EmojiTable.columnUserLastName],
          'userProfilePic': data[EmojiTable.columnUserProfilePic],
        });
      }).toList();
    } catch (e) {
      _log('[EmojiLocal] getAllEmojis(): error: $e');
      return [];
    }
  }

  @override
  Future<void> updateEmoji(String emoji, String caption) async {
    try {
      _log('[EmojiLocal] updateEmoji(): emoji="$emoji" caption="$caption"');
      final db = await AppDatabaseManager.instance.database;

      await db.update(EmojiTable.tableName, {
        EmojiTable.columnEmoji: emoji,
        EmojiTable.columnCaption: caption,
        EmojiTable.columnUpdatedAt: DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      _log('[EmojiLocal] updateEmoji(): error: $e');
      throw Exception('Failed to update emoji locally: $e');
    }
  }

  @override
  Future<void> clearEmoji() async {
    try {
      final db = await AppDatabaseManager.instance.database;
      await db.delete(EmojiTable.tableName);
    } catch (e) {
      throw Exception('Failed to clear emoji: $e');
    }
  }

  @override
  Future<bool> emojiExists() async {
    try {
      _log('[EmojiLocal] emojiExists(): checking');
      final db = await AppDatabaseManager.instance.database;
      final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM ${EmojiTable.tableName}'),
      );
      final exists = (count ?? 0) > 0;
      _log('[EmojiLocal] emojiExists(): count=${count ?? 0} -> $exists');
      return exists;
    } catch (e) {
      _log('[EmojiLocal] emojiExists(): error: $e');
      return false;
    }
  }

  @override
  Future<void> deleteOtherUsersEmojis(String userId) async {
    try {
      _log('[EmojiLocal] deleteOtherUsersEmojis(): keep userId=$userId');
      await EmojiTable.instance.deleteOtherUsersEmojis(userId);
    } catch (e) {
      _log('[EmojiLocal] deleteOtherUsersEmojis(): error: $e');
      // Swallow errors to avoid breaking UI if cleanup fails
    }
  }
}
