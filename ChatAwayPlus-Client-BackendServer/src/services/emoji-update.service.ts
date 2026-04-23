import { Transaction, Op } from 'sequelize';

import EmojiUpdate from '../db/models/emoji-update.model';
import User from '../db/models/user.model';
import sequelize from '../db/config/database';

export const createEmojiUpdate = async (emojis_update: string, emojis_caption: string | undefined, userId: string): Promise<EmojiUpdate> => {
	const t: Transaction = await sequelize.transaction();

	try {
		// Soft delete all existing emoji updates for the user
		await EmojiUpdate.update(
			{ deletedAt: new Date() },
			{
				where: {
					userId,
					deletedAt: null
				},
				transaction: t
			}
		);

		// Create new emoji update
		const emojiUpdate = await EmojiUpdate.create(
			{
				userId,
				emojis_update,
				emojis_caption,
			},
			{ transaction: t }
		);

		await t.commit();
		return emojiUpdate;
	} catch (error) {
		await t.rollback();
		throw new Error(`Error creating emoji update: ${error}`);
	}
};

export const getUserEmojiUpdates = async (userId: string): Promise<EmojiUpdate[]> => {
	try {
		const emojiUpdates = await EmojiUpdate.findAll({
			where: {
				userId,
				deletedAt: null
			},
			// include: [
			// 	{
			// 		model: User,
			// 		as: 'user',
			// 		attributes: ['id', 'firstName', 'lastName', 'chat_picture'],
			// 	},
			// ],
			order: [['createdAt', 'DESC']],
		});
		return emojiUpdates;
	} catch (error) {
		throw new Error(`Error fetching user emoji updates: ${error}`);
	}
};

export const getAllEmojiUpdates = async (): Promise<EmojiUpdate[]> => {
	try {
		const emojiUpdates = await EmojiUpdate.findAll({
			where: {
				deletedAt: null
			},
			include: [
				{
					model: User,
					as: 'user',
					attributes: ['id', 'firstName', 'lastName', 'chat_picture'],
				},
			],
			order: [['createdAt', 'DESC']],
		});
		return emojiUpdates;
	} catch (error) {
		throw new Error(`Error fetching all emoji updates: ${error}`);
	}
};

export const getEmojiUpdateById = async (emojiUpdateId: string): Promise<EmojiUpdate | null> => {
	try {
		const emojiUpdate = await EmojiUpdate.findOne({
			where: {
				id: emojiUpdateId,
				deletedAt: null
			},
			include: [
				{
					model: User,
					as: 'user',
					attributes: ['id', 'firstName', 'lastName', 'chat_picture'],
				},
			],
		});
		return emojiUpdate;
	} catch (error) {
		throw new Error(`Error fetching emoji update: ${error}`);
	}
};

export const updateEmojiUpdate = async (emojiUpdateId: string, userId: string, emojis_update?: string, emojis_caption?: string): Promise<EmojiUpdate | null> => {
	try {
		const updateData: any = {};
		if (emojis_update !== undefined) updateData.emojis_update = emojis_update;
		if (emojis_caption !== undefined) updateData.emojis_caption = emojis_caption;

		const [updatedCount] = await EmojiUpdate.update(
			updateData,
			{
				where: {
					id: emojiUpdateId,
					userId,
					deletedAt: null
				}
			}
		);

		if (updatedCount === 0) {
			return null;
		}

		return await getEmojiUpdateById(emojiUpdateId);
	} catch (error) {
		throw new Error(`Error updating emoji update: ${error}`);
	}
};

export const deleteEmojiUpdate = async (emojiUpdateId: string, userId: string): Promise<boolean> => {
	try {
		const [updatedCount] = await EmojiUpdate.update(
			{ deletedAt: new Date() },
			{
				where: {
					id: emojiUpdateId,
					userId,
					deletedAt: null
				}
			}
		);

		return updatedCount > 0;
	} catch (error) {
		throw new Error(`Error deleting emoji update: ${error}`);
	}
};
