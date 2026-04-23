import { QueryInterface, DataTypes } from 'sequelize';

export default {
	up: async (queryInterface: QueryInterface) => {
		// Create emoji_updates table
		await queryInterface.createTable('emoji_updates', {
			id: {
				type: DataTypes.UUID,
				defaultValue: DataTypes.UUIDV4,
				allowNull: false,
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
			emoji: {
				type: DataTypes.STRING(50),
				allowNull: false,
			},
			caption: {
				type: DataTypes.TEXT,
				allowNull: true,
			},
			deletedAt: {
				type: DataTypes.DATE,
				allowNull: true,
				defaultValue: null,
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

		// Add indexes for better performance
		await queryInterface.addIndex('emoji_updates', ['userId']);
		await queryInterface.addIndex('emoji_updates', ['deletedAt']);
		await queryInterface.addIndex('emoji_updates', ['createdAt']);
	},

	down: async (queryInterface: QueryInterface) => {
		await queryInterface.dropTable('emoji_updates');
	},
};
