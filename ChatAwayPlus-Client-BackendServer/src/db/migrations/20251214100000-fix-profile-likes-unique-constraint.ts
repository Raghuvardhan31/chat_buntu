import { QueryInterface } from 'sequelize';

module.exports = {
	up: async (queryInterface: QueryInterface) => {
		// Remove the old unique constraint (userId, likedUserId)
		try {
			await queryInterface.removeIndex('profile_likes', 'unique_user_liked_user');
		} catch (error) {
			console.log('Old index unique_user_liked_user not found, skipping...');
		}

		// Also try alternative constraint names that might exist
		try {
			await queryInterface.removeIndex('profile_likes', 'profile_likes_user_id_liked_user_id');
		} catch (error) {
			console.log('Old index profile_likes_user_id_liked_user_id not found, skipping...');
		}

		// Add the new unique constraint (userId, likedUserId, targetProfilePicId)
		const indexes: any[] = await queryInterface.showIndex('profile_likes') as any[];
		const indexExists = indexes.some((idx: any) => idx.name === 'unique_user_liked_user_pic');

		if (!indexExists) {
			await queryInterface.addIndex('profile_likes', ['userId', 'likedUserId', 'targetProfilePicId'], {
				unique: true,
				name: 'unique_user_liked_user_pic',
			});
		}

		console.log('✅ Successfully updated profile_likes unique constraint to include targetProfilePicId');
	},

	down: async (queryInterface: QueryInterface) => {
		// Remove the new constraint
		await queryInterface.removeIndex('profile_likes', 'unique_user_liked_user_pic');

		// Re-add the old constraint (for rollback)
		await queryInterface.addIndex('profile_likes', ['userId', 'likedUserId'], {
			unique: true,
			name: 'unique_user_liked_user',
		});
	},
};
