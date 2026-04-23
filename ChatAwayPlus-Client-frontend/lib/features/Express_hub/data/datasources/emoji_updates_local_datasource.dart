// lib/features/voice_hub/data/datasources/emoji_updates_local_datasource.dart

import 'package:chataway_plus/core/database/tables/contacts/app_users_emoji_table.dart';
import '../models/emoji_update_model.dart';

/// Local datasource for emoji updates - handles database operations
abstract class EmojiUpdatesLocalDataSource {
  /// Save multiple emoji updates to database
  Future<void> saveAllEmojiUpdates(List<EmojiUpdateModel> emojiUpdates);

  /// Get all emoji updates from database
  Future<List<EmojiUpdateModel>> getAllEmojiUpdates();

  /// Clear all emoji updates
  Future<void> clearAllEmojiUpdates();
}

/// Implementation of [EmojiUpdatesLocalDataSource]
class EmojiUpdatesLocalDataSourceImpl implements EmojiUpdatesLocalDataSource {
  EmojiUpdatesLocalDataSourceImpl();

  @override
  Future<void> saveAllEmojiUpdates(List<EmojiUpdateModel> emojiUpdates) async {
    try {
      final emojiMaps = emojiUpdates.map((emoji) => emoji.toMap()).toList();
      await AppUsersEmojiTable.instance.saveAllEmojis(emojiMaps);
    } catch (e) {
      throw Exception('Failed to save emoji updates locally: $e');
    }
  }

  @override
  Future<List<EmojiUpdateModel>> getAllEmojiUpdates() async {
    try {
      final emojiMaps = await AppUsersEmojiTable.instance.getAllEmojis();
      return emojiMaps.map((map) => _emojiFromMap(map)).toList();
    } catch (e) {
      throw Exception('Failed to load emoji updates from database: $e');
    }
  }

  @override
  Future<void> clearAllEmojiUpdates() async {
    try {
      await AppUsersEmojiTable.instance.deleteAllEmojis();
    } catch (e) {
      throw Exception('Failed to clear emoji updates: $e');
    }
  }

  /// Helper to convert database map to model
  EmojiUpdateModel _emojiFromMap(Map<String, dynamic> map) {
    DateTime? parseDateTime(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    return EmojiUpdateModel(
      id: map[AppUsersEmojiTable.columnId] as String? ?? '',
      userId: map[AppUsersEmojiTable.columnUserId] as String? ?? '',
      emoji: map[AppUsersEmojiTable.columnEmoji] as String? ?? '',
      caption: map[AppUsersEmojiTable.columnCaption] as String?,
      createdAt: parseDateTime(map[AppUsersEmojiTable.columnCreatedAt]),
      updatedAt: parseDateTime(map[AppUsersEmojiTable.columnUpdatedAt]),
      userFirstName: map[AppUsersEmojiTable.columnUserFirstName] as String?,
      userLastName: map[AppUsersEmojiTable.columnUserLastName] as String?,
      userProfilePic: map[AppUsersEmojiTable.columnUserProfilePic] as String?,
    );
  }
}
