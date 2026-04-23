import { Request, Response } from 'express';
import * as messageReactionService from '../services/message-reaction.service';
import Chat from '../db/models/chat.model';
import User from '../db/models/user.model';
import { chatController } from '../index';
import { sendReactionNotificationToUser } from '../services/fcm.service';
import * as notificationService from '../services/notification.service';

interface AuthenticatedRequest extends Request {
	user?: {
		id: string;
		email: string;
		mobileNo?: string;
		firstName?: string;
		lastName?: string;
	};
}

/**
 * Add or update a reaction to a message
 * POST /api/reactions
 * Body: { messageId: string, emoji: string }
 *
 * WhatsApp behavior:
 * - First tap: Add reaction
 * - Tap different emoji: Update reaction
 * - Tap same emoji: Remove reaction (toggle)
 */
export const addOrUpdateReaction = async (req: AuthenticatedRequest, res: Response) => {
	try {
		const { messageId, emoji } = req.body;
		const userId = req.user?.id;

		if (!userId) {
			return res.status(401).json({
				success: false,
				error: 'User not authenticated'
			});
		}

		if (!messageId || !emoji) {
			return res.status(400).json({
				success: false,
				error: 'messageId and emoji are required'
			});
		}

		// Validate emoji format (basic check)
		if (emoji.length > 20 || emoji.trim().length === 0) {
			return res.status(400).json({
				success: false,
				error: 'Invalid emoji format'
			});
		}

		try {
			const reaction = await messageReactionService.addOrUpdateReaction(
				messageId,
				userId,
				emoji
			);

			// Get updated reactions for the message
			const messageReactions = await messageReactionService.getMessageReactions(
				messageId,
				userId
			);

			// Get the message to find its conversation
			const message = await Chat.findByPk(messageId);

			if (message) {
				// Get reactor user details
				const reactorUser = await User.findByPk(userId, {
					attributes: ['id', 'firstName', 'lastName'],
					raw: true
				});

				// Determine the receiver of the notification
				const receiverId = message.senderId === userId ? message.receiverId : message.senderId;
				const isYou = message.senderId === userId;

				// Send FCM notification to the other user
				const reactorName = reactorUser?.firstName
					? `${reactorUser.firstName}${reactorUser.lastName ? ' ' + reactorUser.lastName : ''}`
					: 'Someone';

				try {
					await sendReactionNotificationToUser({
						receiverId,
						reactorId: userId,
						reactorName,
						emoji,
						messageText: message.message || '[Media]',
						messageId,
						isYou
					});
					console.log(`📨 Sent reaction notification to user ${receiverId}`);
				} catch (fcmError) {
					console.error('Failed to send reaction FCM notification:', fcmError);
				}

				// 🔔 Create persistent in-app notification
				try {
					// Increased truncation limit to show more context as requested
					const truncatedMessage = (message.message || '[Media]').substring(0, 100);
					const notificationMessage = `${reactorName} reacted ${emoji} to: ${truncatedMessage}${truncatedMessage.length >= 100 ? '...' : ''}`;
					
					const dbNotification = await notificationService.createNotification({
						senderId: userId,
						receiverId,
						message: notificationMessage,
						type: 'message_reaction',
						metadata: {
							messageId,
							emoji,
							reactorName
						}
					});

					// Emit real-time notification via socket
					chatController.emitNewNotification(receiverId, dbNotification);
				} catch (dbNotifError) {
					console.error('Failed to create/emit DB notification:', dbNotifError);
				}

				// Find the latest message in this conversation
				const latestMessage = await Chat.findOne({
					where: {
						deletedAt: null
					},
					order: [['createdAt', 'DESC']],
					raw: true
				});

				// Update chat activity if reaction is on the latest message
				if (latestMessage && messageId === latestMessage.id) {
					await Chat.update(
						{
							lastActivityType: 'reaction',
							lastActivityAt: new Date(),
							lastActivityActorId: userId,
							lastActivityEmoji: emoji,
							lastActivityMessageId: messageId
						},
						{ where: { id: messageId } }
					);

					// Emit socket event for chat list update
					const otherUserId = message.senderId === userId ? message.receiverId : message.senderId;
					chatController.emitChatActivityUpdate(otherUserId, {
						chatId: messageId,
						activityType: 'reaction',
						actorId: userId,
						emoji: emoji,
						messageId: messageId,
						timestamp: new Date().toISOString()
					});
				}

				// Emit normal reaction update event
				chatController.emitReactionUpdate(message.senderId, message.receiverId, {
					messageId,
					userId,
					emoji,
					action: reaction ? 'updated' : 'added',
					reactions: messageReactions,
					timestamp: new Date().toISOString()
				});
			}

			return res.status(200).json({
				success: true,
				action: reaction ? 'updated' : 'created',
				data: {
					reaction,
					messageReactions
				}
			});
		} catch (error: any) {
			// Handle special case: reaction removed (toggle)
			if (error.message === 'REACTION_REMOVED') {
				const messageReactions = await messageReactionService.getMessageReactions(
					messageId,
					userId
				);

				// Get the message to emit socket events
				const message = await Chat.findByPk(messageId);

				if (message) {
					// Clear chat activity if it was the last activity
					const chatActivity = await Chat.findOne({
						where: { id: messageId },
						attributes: ['lastActivityType', 'lastActivityMessageId'],
						raw: true
					});

					if (chatActivity?.lastActivityType === 'reaction' && chatActivity?.lastActivityMessageId === messageId) {
						await Chat.update(
							{
								lastActivityType: null,
								lastActivityAt: null,
								lastActivityActorId: null,
								lastActivityEmoji: null,
								lastActivityMessageId: null
							},
							{ where: { id: messageId } }
						);

						// Emit socket event for chat list update
						const otherUserId = message.senderId === userId ? message.receiverId : message.senderId;
						chatController.emitChatActivityUpdate(otherUserId, {
							chatId: messageId,
							activityType: 'reaction_removed',
							actorId: userId,
							emoji: null,
							messageId: messageId,
							timestamp: new Date().toISOString()
						});
					}

					// Emit reaction removed event
					chatController.emitReactionUpdate(message.senderId, message.receiverId, {
						messageId,
						userId,
						emoji: '',
						action: 'removed',
						reactions: messageReactions,
						timestamp: new Date().toISOString()
					});
				}

				return res.status(200).json({
					success: true,
					action: 'removed',
					data: {
						messageReactions
					}
				});
			}
			throw error;
		}
	} catch (error: any) {
		console.error('❌ Error adding/updating reaction:', error);
		return res.status(500).json({
			success: false,
			error: error.message || 'Failed to add reaction'
		});
	}
};

/**
 * Remove a reaction from a message
 * DELETE /api/reactions/:messageId
 */
export const removeReaction = async (req: AuthenticatedRequest, res: Response) => {
	try {
		const { messageId } = req.params;
		const userId = req.user?.id;

		if (!userId) {
			return res.status(401).json({
				success: false,
				error: 'User not authenticated'
			});
		}

		if (!messageId) {
			return res.status(400).json({
				success: false,
				error: 'messageId is required'
			});
		}

		const removed = await messageReactionService.removeReaction(messageId, userId);

		if (!removed) {
			return res.status(404).json({
				success: false,
				error: 'Reaction not found'
			});
		}

		// Get updated reactions
		const messageReactions = await messageReactionService.getMessageReactions(
			messageId,
			userId
		);

		return res.status(200).json({
			success: true,
			action: 'removed',
			data: {
				messageReactions
			}
		});
	} catch (error: any) {
		console.error('❌ Error removing reaction:', error);
		return res.status(500).json({
			success: false,
			error: error.message || 'Failed to remove reaction'
		});
	}
};

/**
 * Get all reactions for a specific message
 * GET /api/reactions/:messageId
 */
export const getMessageReactions = async (req: AuthenticatedRequest, res: Response) => {
	try {
		const { messageId } = req.params;
		const userId = req.user?.id;

		if (!messageId) {
			return res.status(400).json({
				success: false,
				error: 'messageId is required'
			});
		}

		const reactions = await messageReactionService.getMessageReactions(
			messageId,
			userId
		);

		return res.status(200).json({
			success: true,
			data: reactions
		});
	} catch (error: any) {
		console.error('❌ Error fetching reactions:', error);
		return res.status(500).json({
			success: false,
			error: error.message || 'Failed to fetch reactions'
		});
	}
};

/**
 * Get reactions for multiple messages (batch)
 * POST /api/reactions/batch
 * Body: { messageIds: string[] }
 */
export const getReactionsForMessages = async (req: AuthenticatedRequest, res: Response) => {
	try {
		const { messageIds } = req.body;
		const userId = req.user?.id;

		if (!messageIds || !Array.isArray(messageIds)) {
			return res.status(400).json({
				success: false,
				error: 'messageIds array is required'
			});
		}

		if (messageIds.length > 100) {
			return res.status(400).json({
				success: false,
				error: 'Cannot fetch reactions for more than 100 messages at once'
			});
		}

		const reactionsMap = await messageReactionService.getReactionsForMessages(
			messageIds,
			userId
		);

		// Convert Map to object for JSON response
		const reactionsObject: { [key: string]: any } = {};
		reactionsMap.forEach((value, key) => {
			reactionsObject[key] = value;
		});

		return res.status(200).json({
			success: true,
			data: reactionsObject
		});
	} catch (error: any) {
		console.error('❌ Error fetching batch reactions:', error);
		return res.status(500).json({
			success: false,
			error: error.message || 'Failed to fetch reactions'
		});
	}
};

/**
 * Get most popular emojis used in reactions
 * GET /api/reactions/popular-emojis
 */
export const getMostUsedEmojis = async (req: AuthenticatedRequest, res: Response) => {
	try {
		const limit = parseInt(req.query.limit as string) || 6;

		if (limit > 20) {
			return res.status(400).json({
				success: false,
				error: 'Limit cannot exceed 20'
			});
		}

		const emojis = await messageReactionService.getMostUsedEmojis(limit);

		return res.status(200).json({
			success: true,
			data: emojis
		});
	} catch (error: any) {
		console.error('❌ Error fetching popular emojis:', error);
		return res.status(500).json({
			success: false,
			error: error.message || 'Failed to fetch popular emojis'
		});
	}
};
