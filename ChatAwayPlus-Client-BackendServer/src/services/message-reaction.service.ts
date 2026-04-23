import MessageReaction from '../db/models/message-reaction.model';
import Chat from '../db/models/chat.model';
import User from '../db/models/user.model';
import { Op } from 'sequelize';

/**
 * Message Reaction Service - WhatsApp-style reactions
 *
 * Handles business logic for message reactions:
 * - Add reaction (or update if exists)
 * - Remove reaction
 * - Get reactions for a message
 * - Get reaction summary with counts
 */

interface ReactionSummary {
	emoji: string;
	count: number;
	users: Array<{
		id: string;
		firstName: string;
		lastName: string;
		chat_picture?: string;
	}>;
}

interface MessageWithReactions {
	messageId: string;
	reactions: ReactionSummary[];
	totalReactions: number;
	currentUserReaction?: string | null;
}

/**
 * Add or update a reaction to a message
 * WhatsApp behavior: If user already reacted, update to new emoji
 */
export const addOrUpdateReaction = async (
	messageId: string,
	userId: string,
	emoji: string
): Promise<MessageReaction> => {
	// Validate message exists
	const message = await Chat.findByPk(messageId);
	if (!message) {
		throw new Error('Message not found');
	}

	// Check if user already reacted to this message
	const existingReaction = await MessageReaction.findOne({
		where: { messageId, userId }
	});

	if (existingReaction) {
		// Same emoji - this is a toggle to remove
		if (existingReaction.emoji === emoji) {
			await existingReaction.destroy();
			throw new Error('REACTION_REMOVED'); // Special case to handle in controller
		}

		// Different emoji - update the reaction
		existingReaction.emoji = emoji;
		await existingReaction.save();
		await existingReaction.reload(); // Ensure we have fresh data
		return existingReaction;
	}

	// Create new reaction
	const reaction = await MessageReaction.create({
		messageId,
		userId,
		emoji
	});

	return reaction;
};

/**
 * Remove a reaction from a message
 */
export const removeReaction = async (
	messageId: string,
	userId: string
): Promise<boolean> => {
	const reaction = await MessageReaction.findOne({
		where: { messageId, userId }
	});

	if (!reaction) {
		return false;
	}

	await reaction.destroy();
	return true;
};

/**
 * Get all reactions for a message with user details
 */
export const getMessageReactions = async (
	messageId: string,
	currentUserId?: string
): Promise<MessageWithReactions> => {
	const reactions = await MessageReaction.findAll({
		where: { messageId },
		include: [
			{
				model: User,
				as: 'user',
				attributes: ['id', 'firstName', 'lastName', 'chat_picture']
			}
		],
		order: [['createdAt', 'ASC']],
		raw: false
	});

	// Group reactions by emoji
	const reactionMap = new Map<string, ReactionSummary>();

	reactions.forEach((reaction: any) => {
		const emoji = reaction.emoji;

		if (!reactionMap.has(emoji)) {
			reactionMap.set(emoji, {
				emoji,
				count: 0,
				users: []
			});
		}

		const summary = reactionMap.get(emoji)!;
		summary.count++;
		summary.users.push({
			id: reaction.user.id,
			firstName: reaction.user.firstName,
			lastName: reaction.user.lastName,
			chat_picture: reaction.user.chat_picture
		});
	});

	// Find current user's reaction
	let currentUserReaction: string | null = null;
	if (currentUserId) {
		const userReaction = reactions.find((r: any) => r.userId === currentUserId);
		currentUserReaction = userReaction ? userReaction.emoji : null;
	}

	return {
		messageId,
		reactions: Array.from(reactionMap.values()),
		totalReactions: reactions.length,
		currentUserReaction
	};
};

/**
 * Get reactions for multiple messages (batch operation)
 * Useful for loading chat history with reactions
 */
export const getReactionsForMessages = async (
	messageIds: string[],
	currentUserId?: string
): Promise<Map<string, MessageWithReactions>> => {
	if (messageIds.length === 0) {
		return new Map();
	}

	const reactions = await MessageReaction.findAll({
		where: {
			messageId: {
				[Op.in]: messageIds
			}
		},
		include: [
			{
				model: User,
				as: 'user',
				attributes: ['id', 'firstName', 'lastName', 'chat_picture']
			}
		],
		order: [['createdAt', 'ASC']],
		raw: false
	});

	// Group by message ID
	const messageReactionsMap = new Map<string, MessageWithReactions>();

	// Initialize all messages with empty reactions
	messageIds.forEach(messageId => {
		messageReactionsMap.set(messageId, {
			messageId,
			reactions: [],
			totalReactions: 0,
			currentUserReaction: null
		});
	});

	// Group reactions by message and emoji
	const tempMap = new Map<string, Map<string, ReactionSummary>>();

	reactions.forEach((reaction: any) => {
		const messageId = reaction.messageId;

		if (!tempMap.has(messageId)) {
			tempMap.set(messageId, new Map());
		}

		const emojiMap = tempMap.get(messageId)!;
		const emoji = reaction.emoji;

		if (!emojiMap.has(emoji)) {
			emojiMap.set(emoji, {
				emoji,
				count: 0,
				users: []
			});
		}

		const summary = emojiMap.get(emoji)!;
		summary.count++;
		summary.users.push({
			id: reaction.user.id,
			firstName: reaction.user.firstName,
			lastName: reaction.user.lastName,
			chat_picture: reaction.user.chat_picture
		});

		// Track current user's reaction
		if (currentUserId && reaction.userId === currentUserId) {
			const messageData = messageReactionsMap.get(messageId)!;
			messageData.currentUserReaction = emoji;
		}
	});

	// Convert to final format
	tempMap.forEach((emojiMap, messageId) => {
		const messageData = messageReactionsMap.get(messageId)!;
		messageData.reactions = Array.from(emojiMap.values());
		messageData.totalReactions = Array.from(emojiMap.values()).reduce(
			(sum, r) => sum + r.count,
			0
		);
	});

	return messageReactionsMap;
};

/**
 * Check if a user has reacted to a message
 */
export const hasUserReacted = async (
	messageId: string,
	userId: string
): Promise<string | null> => {
	const reaction = await MessageReaction.findOne({
		where: { messageId, userId },
		attributes: ['emoji']
	});

	return reaction ? reaction.emoji : null;
};

/**
 * Get total reaction count for a message
 */
export const getReactionCount = async (messageId: string): Promise<number> => {
	return await MessageReaction.count({
		where: { messageId }
	});
};

/**
 * Get most popular emojis used in reactions (for suggestions)
 */
export const getMostUsedEmojis = async (limit: number = 6): Promise<Array<{ emoji: string; count: number }>> => {
	const reactions = await MessageReaction.findAll({
		attributes: [
			'emoji',
			[MessageReaction.sequelize!.fn('COUNT', MessageReaction.sequelize!.col('emoji')), 'count']
		],
		group: ['emoji'],
		order: [[MessageReaction.sequelize!.literal('count'), 'DESC']],
		limit,
		raw: true
	}) as any[];

	return reactions as Array<{ emoji: string; count: number }>;
};
