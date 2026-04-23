import 'package:chataway_plus/core/database/tables/chat/received_likes_table.dart';

/// Model for a received like entry displayed in the Likes Hub
class ReceivedLikeEntry {
  final String id;
  final String currentUserId;
  final String fromUserId;
  final String fromUserName;
  final String? fromUserProfilePic;
  final String likeType; // 'chat_picture' or 'voice'
  final String? statusId;
  final String? likeId;
  final String? message;
  final DateTime createdAt;

  const ReceivedLikeEntry({
    required this.id,
    required this.currentUserId,
    required this.fromUserId,
    required this.fromUserName,
    this.fromUserProfilePic,
    required this.likeType,
    this.statusId,
    this.likeId,
    this.message,
    required this.createdAt,
  });

  bool get isChatPicture => likeType == 'chat_picture';
  bool get isVoice => likeType == 'voice';

  factory ReceivedLikeEntry.fromMap(Map<String, dynamic> map) {
    final rawCreatedAt = map[ReceivedLikesTable.columnCreatedAt];
    final createdAtMs = rawCreatedAt is int
        ? rawCreatedAt
        : int.tryParse(rawCreatedAt?.toString() ?? '') ??
            DateTime.now().millisecondsSinceEpoch;

    return ReceivedLikeEntry(
      id: map[ReceivedLikesTable.columnId]?.toString() ?? '',
      currentUserId:
          map[ReceivedLikesTable.columnCurrentUserId]?.toString() ?? '',
      fromUserId: map[ReceivedLikesTable.columnFromUserId]?.toString() ?? '',
      fromUserName:
          map[ReceivedLikesTable.columnFromUserName]?.toString() ?? 'Someone',
      fromUserProfilePic:
          map[ReceivedLikesTable.columnFromUserProfilePic]?.toString(),
      likeType:
          map[ReceivedLikesTable.columnLikeType]?.toString() ?? 'chat_picture',
      statusId: map[ReceivedLikesTable.columnStatusId]?.toString(),
      likeId: map[ReceivedLikesTable.columnLikeId]?.toString(),
      message: map[ReceivedLikesTable.columnMessage]?.toString(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMs),
    );
  }
}

/// Local database service for received likes (Likes Hub)
class ReceivedLikesLocalDatabaseService {
  static final ReceivedLikesLocalDatabaseService _instance =
      ReceivedLikesLocalDatabaseService._internal();
  factory ReceivedLikesLocalDatabaseService() => _instance;
  ReceivedLikesLocalDatabaseService._internal();

  static ReceivedLikesLocalDatabaseService get instance => _instance;

  /// Save a received like notification
  Future<void> saveLike({
    required String currentUserId,
    required String fromUserId,
    required String fromUserName,
    String? fromUserProfilePic,
    required String likeType,
    String? statusId,
    String? likeId,
    String? message,
  }) async {
    final id = likeId ??
        '${likeType}_${fromUserId}_${DateTime.now().millisecondsSinceEpoch}';

    await ReceivedLikesTable.insert(
      id: id,
      currentUserId: currentUserId,
      fromUserId: fromUserId,
      fromUserName: fromUserName,
      fromUserProfilePic: fromUserProfilePic,
      likeType: likeType,
      statusId: statusId,
      likeId: likeId,
      message: message,
    );
  }

  /// Get all received likes within last 24 hours
  Future<List<ReceivedLikeEntry>> getAllLikes({
    required String currentUserId,
  }) async {
    // Clean up expired entries first
    await ReceivedLikesTable.deleteExpired();

    final rows = await ReceivedLikesTable.getAll(
      currentUserId: currentUserId,
    );

    return rows.map((row) => ReceivedLikeEntry.fromMap(row)).toList();
  }

  /// Delete a specific like
  Future<void> deleteLike(String id) async {
    await ReceivedLikesTable.deleteById(id);
  }

  /// Get count of likes within last 24 hours
  Future<int> getLikeCount({required String currentUserId}) async {
    return ReceivedLikesTable.getCount(currentUserId: currentUserId);
  }

  /// Clear all likes
  Future<void> clearAll({required String currentUserId}) async {
    await ReceivedLikesTable.clearAll(currentUserId: currentUserId);
  }
}
