import { Request, Response } from 'express';
import * as emojiUpdateService from '../services/emoji-update.service';
import * as statusService from '../services/status.service';
import { getUserDetailsByIds, getById } from '../services/user.service';
import { sendProfileUpdateToUser } from '../services/fcm.service';
import { chatController } from '../index';

export const createEmojiUpdate = async (req: Request, res: Response) => {
	try {
		const { emojis_update, emojis_caption } = req.body;

		if (!req.user) {
			return res.status(401).json({ message: 'Unauthorized' });
		}

		if (!emojis_update) {
			return res.status(400).json({ message: 'emojis_update is required' });
		}

		const userId = req.user.id;
		const emojiUpdate = await emojiUpdateService.createEmojiUpdate(emojis_update, emojis_caption, userId);

		// Prepare updated data for emoji update creation
		const updatedData: Record<string, any> = {
			emojis_update: emojiUpdate.emojis_update,
			emojis_caption: emojiUpdate.emojis_caption
		};

		// Emit WebSocket profile update to contacts
		const userIds: string[] = await chatController.emitProfileUpdate(userId, updatedData);

		// Get complete details of the user to send in FCM payload
		const user = await getById(userId);
		if (!user) {
			console.error('User not found for emoji update notification:', userId);
			return res.status(404).json({ message: 'User not found' });
		}

		// Get user's status
		const userStatus = await statusService.getUserStatus(userId);
		const newStatus = userStatus.length > 0 ? userStatus[0] : null;

		// Prepare the complete user data payload
		const completeUserPayload = {
			user: {
				id: user?.id,
				email: user?.email || null,
				firstName: user?.firstName || null,
				lastName: user?.lastName || null,
				mobileNo: user?.mobileNo,
				isVerified: user?.isVerified,
				metadata: JSON.stringify(user?.metadata || {}),
				chat_picture: user?.chat_picture || null,
				chat_picture_version: user?.chat_picture_version || null,
				createdAt: (user as any)?.createdAt,
				updatedAt: (user as any)?.updatedAt
			},
			share_your_voice: newStatus ? {
				id: newStatus.id,
				userId: newStatus.userId,
				share_your_voice: newStatus.share_your_voice,
				likesCount: newStatus.likesCount || 0,
				deletedAt: newStatus.deletedAt || null,
				createdAt: newStatus.createdAt,
				updatedAt: newStatus.updatedAt,
			} : null,
			emoji_update: {
				id: emojiUpdate.id,
				userId: emojiUpdate.userId,
				emojis_update: emojiUpdate.emojis_update,
				emojis_caption: emojiUpdate.emojis_caption || null,
				deletedAt: emojiUpdate.deletedAt || null,
				createdAt: emojiUpdate.createdAt,
				updatedAt: emojiUpdate.updatedAt
			}
		};

		// Send profile update to all contacts using multi-device support
		const userData = await getUserDetailsByIds(userIds);
		const sendPromises = userData.map(async (contactUser) => {
			if (!contactUser || !contactUser.id) return;

			try {
				const result = await sendProfileUpdateToUser({
					receiverId: contactUser.id,
					updatingUserId: userId,
					updatedData: completeUserPayload
				});

				console.log(`📤 Emoji update creation sent to user ${contactUser.id}:`, {
					tokenCount: result.tokenCount,
					successCount: result.successCount,
					failureCount: result.failureCount,
					invalidTokenCount: result.invalidTokenCount
				});
			} catch (error) {
				console.error(`Failed to send emoji update creation to user ${contactUser.id}:`, error);
			}
		});

		// Send all FCM notifications in parallel
		await Promise.all(sendPromises);

		res.status(201).json({
			success: true,
			data: emojiUpdate
		});
	} catch (error) {
		res.status(500).json({ message: `Error creating emoji update: ${error}` });
	}
};

export const getUserEmojiUpdates = async (req: Request, res: Response) => {
	try {
		const userId = req.params.userId || req.user?.id;

		if (!userId) {
			return res.status(401).json({ message: 'Unauthorized' });
		}

		const emojiUpdates = await emojiUpdateService.getUserEmojiUpdates(userId);
		res.json({
			success: true,
			data: emojiUpdates
		});
	} catch (error) {
		res.status(500).json({ message: `Error fetching emoji updates: ${error}` });
	}
};

export const getAllEmojiUpdates = async (req: Request, res: Response) => {
	try {
		const emojiUpdates = await emojiUpdateService.getAllEmojiUpdates();
		res.json({
			success: true,
			data: emojiUpdates
		});
	} catch (error) {
		res.status(500).json({ message: `Error fetching all emoji updates: ${error}` });
	}
};

export const getEmojiUpdate = async (req: Request, res: Response) => {
	try {
		const { emojiUpdateId } = req.params;
		const emojiUpdate = await emojiUpdateService.getEmojiUpdateById(emojiUpdateId);

		if (!emojiUpdate) {
			return res.status(404).json({ message: 'Emoji update not found' });
		}

		res.json({
			success: true,
			data: emojiUpdate
		});
	} catch (error) {
		res.status(500).json({ message: `Error fetching emoji update: ${error}` });
	}
};

export const getCurrentUserEmojiUpdate = async (req: Request, res: Response) => {
	try {
		if (!req.user) {
			return res.status(401).json({ message: 'Unauthorized' });
		}

		const userId = req.user.id;
		const emojiUpdates = await emojiUpdateService.getUserEmojiUpdates(userId);

		// Since we only allow one emoji update per user, get the first (and only) active one
		const currentEmojiUpdate = emojiUpdates.length > 0 ? emojiUpdates[0] : null;

		if (!currentEmojiUpdate) {
			return res.status(404).json({ message: 'No emoji update found for current user' });
		}

		res.json({
			success: true,
			data: currentEmojiUpdate
		});
	} catch (error) {
		res.status(500).json({ message: `Error fetching current user emoji update: ${error}` });
	}
};

export const updateEmojiUpdate = async (req: Request, res: Response) => {
	try {
		const { emojiUpdateId } = req.params;
		const { emojis_update, emojis_caption } = req.body;

		if (!req.user) {
			return res.status(401).json({ message: 'Unauthorized' });
		}

		const userId = req.user.id;
		const updatedEmojiUpdate = await emojiUpdateService.updateEmojiUpdate(emojiUpdateId, userId, emojis_update, emojis_caption);

		if (!updatedEmojiUpdate) {
			return res.status(404).json({ message: 'Emoji update not found or you are not authorized to update it' });
		}

		// Prepare updated data for emoji update modification
		const updatedData: Record<string, any> = {
			emojis_update: updatedEmojiUpdate.emojis_update,
			emojis_caption: updatedEmojiUpdate.emojis_caption
		};

		// Emit WebSocket profile update to contacts
		const userIds: string[] = await chatController.emitProfileUpdate(userId, updatedData);

		// Get complete details of the user to send in FCM payload
		const user = await getById(userId);
		if (!user) {
			console.error('User not found for emoji update modification notification:', userId);
			return res.status(404).json({ message: 'User not found' });
		}

		// Get user's status
		const userStatus = await statusService.getUserStatus(userId);
		const newStatus = userStatus.length > 0 ? userStatus[0] : null;

		// Prepare the complete user data payload
		const completeUserPayload = {
			user: {
				id: user?.id,
				email: user?.email || null,
				firstName: user?.firstName || null,
				lastName: user?.lastName || null,
				mobileNo: user?.mobileNo,
				isVerified: user?.isVerified,
				metadata: JSON.stringify(user?.metadata || {}),
				chat_picture: user?.chat_picture || null,
				chat_picture_version: user?.chat_picture_version || null,
				createdAt: (user as any)?.createdAt,
				updatedAt: (user as any)?.updatedAt
			},
			share_your_voice: newStatus ? {
				id: newStatus.id,
				userId: newStatus.userId,
				share_your_voice: newStatus.share_your_voice,
				likesCount: newStatus.likesCount || 0,
				deletedAt: newStatus.deletedAt || null,
				createdAt: newStatus.createdAt,
				updatedAt: newStatus.updatedAt,
			} : null,
			emoji_update: {
				id: updatedEmojiUpdate.id,
				userId: updatedEmojiUpdate.userId,
				emojis_update: updatedEmojiUpdate.emojis_update,
				emojis_caption: updatedEmojiUpdate.emojis_caption || null,
				deletedAt: updatedEmojiUpdate.deletedAt || null,
				createdAt: updatedEmojiUpdate.createdAt,
				updatedAt: updatedEmojiUpdate.updatedAt
			}
		};

		// Send profile update to all contacts using multi-device support
		const userData = await getUserDetailsByIds(userIds);
		const sendPromises = userData.map(async (contactUser) => {
			if (!contactUser || !contactUser.id) return;

			try {
				const result = await sendProfileUpdateToUser({
					receiverId: contactUser.id,
					updatingUserId: userId,
					updatedData: completeUserPayload
				});

				console.log(`📤 Emoji update modification sent to user ${contactUser.id}:`, {
					tokenCount: result.tokenCount,
					successCount: result.successCount,
					failureCount: result.failureCount,
					invalidTokenCount: result.invalidTokenCount
				});
			} catch (error) {
				console.error(`Failed to send emoji update modification to user ${contactUser.id}:`, error);
			}
		});

		// Send all FCM notifications in parallel
		await Promise.all(sendPromises);

		res.json({
			success: true,
			data: updatedEmojiUpdate
		});
	} catch (error) {
		res.status(500).json({ message: `Error updating emoji update: ${error}` });
	}
};

export const deleteEmojiUpdate = async (req: Request, res: Response) => {
	try {
		const { emojiUpdateId } = req.params;

		if (!req.user) {
			return res.status(401).json({ message: 'Unauthorized' });
		}

		const userId = req.user.id;
		const deleted = await emojiUpdateService.deleteEmojiUpdate(emojiUpdateId, userId);

		if (!deleted) {
			return res.status(404).json({ message: 'Emoji update not found or you are not authorized to delete it' });
		}

		// Prepare updated data for emoji update deletion
		const updatedData: Record<string, any> = {
			emojis_update: null,
			emojis_caption: null
		};

		// Emit WebSocket profile update to contacts
		const userIds: string[] = await chatController.emitProfileUpdate(userId, updatedData);

		// Get complete details of the user to send in FCM payload
		const user = await getById(userId);
		if (!user) {
			console.error('User not found for emoji update deletion notification:', userId);
			return res.status(404).json({ message: 'User not found' });
		}

		// Get user's status
		const userStatus = await statusService.getUserStatus(userId);
		const newStatus = userStatus.length > 0 ? userStatus[0] : null;

		// Prepare the complete user data payload with null emoji_update
		const completeUserPayload = {
			user: {
				id: user?.id,
				email: user?.email || null,
				firstName: user?.firstName || null,
				lastName: user?.lastName || null,
				mobileNo: user?.mobileNo,
				isVerified: user?.isVerified,
				metadata: JSON.stringify(user?.metadata || {}),
				chat_picture: user?.chat_picture || null,
				chat_picture_version: user?.chat_picture_version || null,
				createdAt: (user as any)?.createdAt,
				updatedAt: (user as any)?.updatedAt
			},
			share_your_voice: newStatus ? {
				id: newStatus.id,
				userId: newStatus.userId,
				share_your_voice: newStatus.share_your_voice,
				likesCount: newStatus.likesCount || 0,
				deletedAt: newStatus.deletedAt || null,
				createdAt: newStatus.createdAt,
				updatedAt: newStatus.updatedAt,
			} : null,
			emoji_update: null // Emoji update was deleted
		};

		// Send profile update to all contacts using multi-device support
		const userData = await getUserDetailsByIds(userIds);
		const sendPromises = userData.map(async (contactUser) => {
			if (!contactUser || !contactUser.id) return;

			try {
				const result = await sendProfileUpdateToUser({
					receiverId: contactUser.id,
					updatingUserId: userId,
					updatedData: completeUserPayload
				});

				console.log(`📤 Emoji update deletion sent to user ${contactUser.id}:`, {
					tokenCount: result.tokenCount,
					successCount: result.successCount,
					failureCount: result.failureCount,
					invalidTokenCount: result.invalidTokenCount
				});
			} catch (error) {
				console.error(`Failed to send emoji update deletion to user ${contactUser.id}:`, error);
			}
		});

		// Send all FCM notifications in parallel
		await Promise.all(sendPromises);

		res.json({
			success: true,
			message: 'Emoji update deleted successfully'
		});
	} catch (error) {
		res.status(500).json({ message: `Error deleting emoji update: ${error}` });
	}
};
