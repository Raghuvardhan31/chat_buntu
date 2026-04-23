import { QueryInterface } from 'sequelize';

export default {
	up: async (queryInterface: QueryInterface) => {
		// Rename targetProfilePicId column to target_chat_picture_id
		await queryInterface.renameColumn('profile_likes', 'targetProfilePicId', 'target_chat_picture_id');
	},

	down: async (queryInterface: QueryInterface) => {
		// Revert: rename target_chat_picture_id back to targetProfilePicId
		await queryInterface.renameColumn('profile_likes', 'target_chat_picture_id', 'targetProfilePicId');
	},
};
