import { QueryInterface, DataTypes } from 'sequelize';

module.exports = {
	up: async (queryInterface: QueryInterface) => {
		await queryInterface.createTable('profile_likes', {
			id: {
				type: DataTypes.UUID,
				defaultValue: DataTypes.UUIDV4,
				primaryKey: true,
			},
			userId: {
				type: DataTypes.UUID,
				allowNull: false,
				references: {
					model: 'users',
					key: 'id',
				},
				onUpdate: 'CASCADE',
				onDelete: 'CASCADE',
			},
			likedUserId: {
				type: DataTypes.UUID,
				allowNull: false,
				references: {
					model: 'users',
					key: 'id',
				},
				onUpdate: 'CASCADE',
				onDelete: 'CASCADE',
			},
			targetProfilePicId: {
				type: DataTypes.STRING,
				allowNull: false,
				comment: 'ID/version of the profile picture that was liked',
			},
			createdAt: {
				type: DataTypes.DATE,
				allowNull: false,
			},
			updatedAt: {
				type: DataTypes.DATE,
				allowNull: false,
			},
		});

		// Add indexes only if they don't exist
		const indexes: any[] = await queryInterface.showIndex('profile_likes') as any[];
		const indexNames = indexes.map((idx: any) => idx.name);

		if (!indexNames.includes('unique_user_liked_user_pic')) {
			await queryInterface.addIndex('profile_likes', ['userId', 'likedUserId', 'targetProfilePicId'], {
				unique: true,
				name: 'unique_user_liked_user_pic',
			});
		}

		// Add index for counting likes per user
		if (!indexNames.includes('profile_likes_liked_user_id')) {
			await queryInterface.addIndex('profile_likes', ['likedUserId']);
		}

		// Add index for targetProfilePicId for efficient queries
		if (!indexNames.includes('profile_likes_target_profile_pic_id')) {
			await queryInterface.addIndex('profile_likes', ['targetProfilePicId']);
		}
	},

	down: async (queryInterface: QueryInterface) => {
		await queryInterface.dropTable('profile_likes');
	},
};
