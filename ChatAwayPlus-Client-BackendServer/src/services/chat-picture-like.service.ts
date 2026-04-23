import ChatPictureLike from "../db/models/chat-picture-like.model";
import User from "../db/models/user.model";
import sequelize from "../config/database";

/**
 * Toggle chat picture like - if already liked, unlike it; if not liked, like it
 * @param userId - User who is clicking the like button
 * @param likedUserId - User whose profile is being liked
 * @param target_chat_picture_id - ID/version of the chat picture being liked
 * @returns Object with action performed, like count, and like details
 */
export const toggleChatPictureLike = async (
	userId: string,
	likedUserId: string,
	target_chat_picture_id: string,
): Promise<{
	action: "liked" | "unliked";
	likeCount: number;
	likeId?: string;
	target_chat_picture_id: string;
}> => {
	try {
		console.log(`🔄 [TOGGLE_LIKE] START: userId=${userId}, likedUserId=${likedUserId}, target_chat_picture_id=${target_chat_picture_id}`);

		// Check if user is trying to like their own profile
		if (userId === likedUserId) {
			throw new Error("Cannot like your own profile");
		}

		// Validate target_chat_picture_id
		if (!target_chat_picture_id) {
			throw new Error("target_chat_picture_id is required");
		}

		// Validate that the likedUserId exists in the database
		const likedUser = await User.findOne({
			where: { id: likedUserId },
			attributes: ["id"],
		});

		if (!likedUser) {
			console.log(`❌ [TOGGLE_LIKE] User not found: ${likedUserId}`);
			throw new Error("User not found");
		}
		console.log(`✅ [TOGGLE_LIKE] Liked user exists: ${likedUserId}`);

		// Check if the like already exists for this specific chat picture
		const existingLike = await ChatPictureLike.findOne({
			where: {
				userId,
				likedUserId,
				target_chat_picture_id,
			},
		});
		console.log(`🔍 [TOGGLE_LIKE] Existing like check: ${existingLike ? 'FOUND (id=' + (existingLike as any).id + ')' : 'NOT FOUND'}`);

		let action: "liked" | "unliked";
		let likeId: string | undefined;

		if (existingLike) {
			// Unlike - delete the record
			await existingLike.destroy();
			action = "unliked";
			console.log(
				`👎 User ${userId} unliked chat picture ${target_chat_picture_id} of user ${likedUserId}`,
			);
		} else {
			// Like - create new record using findOrCreate to handle race conditions
			try {
				console.log(`📝 [TOGGLE_LIKE] Creating new like record using findOrCreate...`);
				const [newLike, created] = await ChatPictureLike.findOrCreate({
					where: {
						userId,
						likedUserId,
						target_chat_picture_id,
					},
					defaults: {
						userId,
						likedUserId,
						target_chat_picture_id,
					},
				});

				console.log(`📝 [TOGGLE_LIKE] findOrCreate result: created=${created}, id=${(newLike as any).id}`);
				action = "liked";
				likeId = (newLike as any).id;

				if (created) {
					console.log(
						`👍 User ${userId} liked chat picture ${target_chat_picture_id} of user ${likedUserId} (likeId: ${likeId})`,
					);
				} else {
					console.log(
						`⚠️ Like already existed (race condition handled by findOrCreate) - likeId: ${likeId}`,
					);
				}
			} catch (createError: any) {
				// Handle race condition: findOrCreate in MySQL is not truly atomic
				// If concurrent requests cause unique constraint violation, query the existing record
				if (
					createError.name === "SequelizeUniqueConstraintError" ||
					createError.original?.code === "ER_DUP_ENTRY"
				) {
					console.log(`⚠️ [TOGGLE_LIKE] Duplicate detected (race condition) - querying existing record...`);
					const existingRecord = await ChatPictureLike.findOne({
						where: {
							userId,
							likedUserId,
							target_chat_picture_id,
						},
					});

					if (existingRecord) {
						console.log(`✅ [TOGGLE_LIKE] Found existing record after race condition: id=${(existingRecord as any).id}`);
						action = "liked";
						likeId = (existingRecord as any).id;
					} else {
						// Record was created and deleted in another concurrent request
						console.log(`⚠️ [TOGGLE_LIKE] Record not found after race condition - creating new one...`);
						const retryLike = await ChatPictureLike.create({
							userId,
							likedUserId,
							target_chat_picture_id,
						});
						action = "liked";
						likeId = (retryLike as any).id;
						console.log(`✅ [TOGGLE_LIKE] Created on retry: likeId=${likeId}`);
					}
				} else {
					console.error(`❌ [TOGGLE_LIKE] findOrCreate error:`, createError.name, createError.message);
					console.error(`❌ [TOGGLE_LIKE] Error details:`, JSON.stringify({
						name: createError.name,
						message: createError.message,
						original: createError.original,
						sql: createError.sql,
					}));
					throw createError;
				}
			}
		}

		// Get updated like count for this specific chat picture
		const likeCount = await ChatPictureLike.count({
			where: {
				likedUserId,
				target_chat_picture_id,
			},
		});
		console.log(`📊 [TOGGLE_LIKE] Like count for ${likedUserId}/${target_chat_picture_id}: ${likeCount}`);

		console.log(`✅ [TOGGLE_LIKE] END: action=${action}, likeCount=${likeCount}, likeId=${likeId}`);
		return { action, likeCount, likeId, target_chat_picture_id };
	} catch (error) {
		console.error("Error toggling chat picture like:", error);
		throw error;
	}
};

/**
 * Get the total number of likes for a user's profile
 * @param likedUserId - User whose chat picture like count to retrieve
 * @param target_chat_picture_id - Optional: filter by specific chat picture version
 * @returns Number of likes
 */
export const getChatPictureLikeCount = async (
	likedUserId: string,
	target_chat_picture_id?: string,
): Promise<number> => {
	try {
		const whereClause: any = { likedUserId };
		if (target_chat_picture_id) {
			whereClause.target_chat_picture_id = target_chat_picture_id;
		}

		const count = await ChatPictureLike.count({
			where: whereClause,
		});
		return count;
	} catch (error) {
		console.error("Error getting chat picture like count:", error);
		throw error;
	}
};

/**
 * Check if current user has liked a specific user's chat picture
 * @param userId - Current user
 * @param likedUserId - User to check if liked
 * @param target_chat_picture_id - Specific chat picture version to check
 * @returns Boolean indicating if liked
 */
export const hasUserLikedChatPicture = async (
	userId: string,
	likedUserId: string,
	target_chat_picture_id: string,
): Promise<boolean> => {
	try {
		const like = await ChatPictureLike.findOne({
			where: {
				userId,
				likedUserId,
				target_chat_picture_id,
			},
		});
		return !!like;
	} catch (error) {
		console.error("Error checking if user liked chat picture:", error);
		throw error;
	}
};

/**
 * Get users who liked a specific profile
 * @param likedUserId - User whose chat picture likes to retrieve
 * @param target_chat_picture_id - Optional: filter by specific chat picture version
 * @param limit - Maximum number of users to return
 * @returns Array of users who liked the profile
 */
export const getUsersWhoLikedChatPicture = async (
	likedUserId: string,
	target_chat_picture_id?: string,
	limit: number = 50,
): Promise<any[]> => {
	try {
		const whereClause: any = { likedUserId };
		if (target_chat_picture_id) {
			whereClause.target_chat_picture_id = target_chat_picture_id;
		}

		const likes = await ChatPictureLike.findAll({
			where: whereClause,
			order: [["createdAt", "DESC"]],
			limit,
			raw: true,
		});

		if (likes.length === 0) {
			return [];
		}

		const userIds = likes.map((like: any) => like.userId);

		const users = await User.findAll({
			where: { id: userIds },
			attributes: [
				"id",
				"firstName",
				"lastName",
				"chat_picture",
				"chat_picture_version",
			],
			raw: true,
		});

		const userMap = new Map(users.map((u: any) => [u.id, u]));

		return likes.map((like: any) => ({
			likeId: like.id,
			userId: like.userId,
			target_chat_picture_id: like.target_chat_picture_id,
			likedAt: like.createdAt,
			user: userMap.get(like.userId),
		}));
	} catch (error) {
		console.error("Error getting users who liked chat picture:", error);
		throw error;
	}
};
