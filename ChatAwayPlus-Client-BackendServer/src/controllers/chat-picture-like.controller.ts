import { Request, Response } from 'express';
import {
	toggleChatPictureLike,
	getChatPictureLikeCount,
	hasUserLikedChatPicture,
	getUsersWhoLikedChatPicture,
} from '../services/chat-picture-like.service';
import { chatController } from '../index';

/**
 * Toggle like on a user's profile picture (like if not liked, unlike if already liked)
 * POST /api/chat-picture-likes/toggle
 * Body: { likedUserId: string, target_chat_picture_id: string }
 */
export const toggleLike = async (req: Request, res: Response) => {
	try {
		const userId = (req.user as any).id; // User who clicked the like button
		const { likedUserId, target_chat_picture_id } = req.body;

		if (!likedUserId) {
			return res.status(400).json({
				success: false,
				error: 'likedUserId is required',
			});
		}

		if (!target_chat_picture_id) {
			return res.status(400).json({
				success: false,
				error: 'target_chat_picture_id is required',
			});
		}

		const result = await toggleChatPictureLike(userId, likedUserId, target_chat_picture_id);

		// Send notification only on 'liked' action (not on 'unliked')
		if (result.action === 'liked' && result.likeId) {
			try {
				// Send notification via WebSocket (if online) or FCM (if offline)
				const notificationResult = await chatController.sendChatPictureLikeNotification({
					likeId: result.likeId,
					fromUserId: userId,
					toUserId: likedUserId,
					target_chat_picture_id: result.target_chat_picture_id,
				});

				// console.log(`🔔 Chat picture like notification sent:`, {
				// 	fromUserId: userId,
				// 	toUserId: likedUserId,
				// 	likeId: result.likeId,
				// 	...notificationResult,
				// });
			} catch (notificationError) {
				console.error('❌ Error sending chat-picture-like notification:', notificationError);
				// Don't fail the request if notification fails
			}
		}

		res.status(200).json({
			success: true,
			data: {
				action: result.action,
				likeCount: result.likeCount,
				likeId: result.likeId,
				target_chat_picture_id: result.target_chat_picture_id,
			},
			message: result.action === 'liked' ? 'Profile picture liked' : 'Profile picture unliked',
		});
	} catch (error) {
		const errorMessage = (error as Error).message;

		if (errorMessage === 'Cannot like your own profile' ||
			errorMessage === 'target_chat_picture_id is required' ||
			errorMessage === 'User not found') {
			return res.status(400).json({
				success: false,
				error: errorMessage,
			});
		}

		console.error('Error toggling chat picture like:', error);
		res.status(500).json({
			success: false,
			error: 'Failed to toggle chat picture like',
		});
	}
};

/**
 * Get the total number of likes for a user's profile (or specific profile picture)
 * POST /api/chat-picture-likes/count
 * Body: { likedUserId: string, target_chat_picture_id?: string }
 */
export const getLikeCount = async (req: Request, res: Response) => {
	try {
		const { likedUserId, target_chat_picture_id } = req.body;

		if (!likedUserId) {
			return res.status(400).json({
				success: false,
				error: 'likedUserId is required',
			});
		}

		const count = await getChatPictureLikeCount(
			likedUserId,
			target_chat_picture_id as string | undefined
		);

		res.status(200).json({
			success: true,
			data: {
				likedUserId,
				target_chat_picture_id: target_chat_picture_id || null,
				likeCount: count,
			},
		});
	} catch (error) {
		console.error('Error getting chat picture like count:', error);
		res.status(500).json({
			success: false,
			error: 'Failed to get chat picture like count',
		});
	}
};

/**
 * Check if current user has liked a specific profile picture
 * POST /api/chat-picture-likes/check
 * Body: { likedUserId: string, target_chat_picture_id: string }
 */
export const checkIfLiked = async (req: Request, res: Response) => {
	try {
		const currentUserId = (req.user as any).id;
		const { likedUserId, target_chat_picture_id } = req.body;

		if (!likedUserId) {
			return res.status(400).json({
				success: false,
				error: 'likedUserId is required',
			});
		}

		if (!target_chat_picture_id) {
			return res.status(400).json({
				success: false,
				error: 'target_chat_picture_id is required',
			});
		}

		const isLiked = await hasUserLikedChatPicture(
			currentUserId,
			likedUserId,
			target_chat_picture_id as string
		);

		res.status(200).json({
			success: true,
			data: {
				likedUserId,
				target_chat_picture_id,
				isLiked,
			},
		});
	} catch (error) {
		console.error('Error checking like status:', error);
		res.status(500).json({
			success: false,
			error: 'Failed to check like status',
		});
	}
};

/**
 * Get list of users who liked a profile (or specific profile picture)
 * POST /api/chat-picture-likes/users
 * Body: { likedUserId: string, target_chat_picture_id?: string, limit?: number }
 */
export const getUsersWhoLiked = async (req: Request, res: Response) => {
	try {
		const { likedUserId, target_chat_picture_id, limit = 50 } = req.body;

		if (!likedUserId) {
			return res.status(400).json({
				success: false,
				error: 'likedUserId is required',
			});
		}

		const users = await getUsersWhoLikedChatPicture(
			likedUserId,
			target_chat_picture_id as string | undefined,
			limit
		);

		res.status(200).json({
			success: true,
			data: {
				likedUserId,
				target_chat_picture_id: target_chat_picture_id || null,
				likeCount: users.length,
				users,
			},
		});
	} catch (error) {
		console.error('Error getting users who liked profile:', error);
		res.status(500).json({
			success: false,
			error: 'Failed to get users who liked profile',
		});
	}
};
