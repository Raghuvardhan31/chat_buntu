module.exports = {
	up: async (queryInterface: any, Sequelize: any) => {
		await queryInterface.createTable('message_reactions', {
			id: {
				type: Sequelize.UUID,
				defaultValue: Sequelize.UUIDV4,
				primaryKey: true,
				allowNull: false,
			},
			messageId: {
				type: Sequelize.UUID,
				allowNull: false,
				references: {
					model: 'chats',
					key: 'id',
				},
				onDelete: 'CASCADE',
				onUpdate: 'CASCADE',
				field: 'messageId',
			},
			userId: {
				type: Sequelize.UUID,
				allowNull: false,
				references: {
					model: 'users',
					key: 'id',
				},
				onDelete: 'CASCADE',
				onUpdate: 'CASCADE',
				field: 'userId',
			},
			emoji: {
				type: Sequelize.STRING(20),
				allowNull: false,
			},
			createdAt: {
				type: Sequelize.DATE,
				allowNull: false,
				defaultValue: Sequelize.NOW,
				field: 'createdAt',
			},
			updatedAt: {
				type: Sequelize.DATE,
				allowNull: false,
				defaultValue: Sequelize.NOW,
				field: 'updatedAt',
			},
		});

		// Add unique constraint: one reaction per user per message
		await queryInterface.addConstraint('message_reactions', {
			fields: ['messageId', 'userId'],
			type: 'unique',
			name: 'unique_user_message_reaction',
		});

		// Add index for fast lookup of reactions by message
		await queryInterface.addIndex('message_reactions', ['messageId'], {
			name: 'idx_message_reactions_messageId',
		});

		// Add index for fast lookup of reactions by user
		await queryInterface.addIndex('message_reactions', ['userId'], {
			name: 'idx_message_reactions_userId',
		});

		// Add index for fast lookup by emoji (for analytics/stats)
		await queryInterface.addIndex('message_reactions', ['emoji'], {
			name: 'idx_message_reactions_emoji',
		});
	},

	down: async (queryInterface: any, Sequelize: any) => {
		await queryInterface.dropTable('message_reactions');
	},
};
