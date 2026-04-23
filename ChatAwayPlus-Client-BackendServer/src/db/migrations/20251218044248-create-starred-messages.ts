import { QueryInterface, DataTypes } from 'sequelize';

module.exports = {
	async up(queryInterface: QueryInterface) {
		await queryInterface.createTable('starred_messages', {
			id: {
				type: DataTypes.UUID,
				defaultValue: DataTypes.UUIDV4,
				primaryKey: true,
			},

			userId: {
				type: DataTypes.UUID,
				allowNull: false,
			},

			chatId: {
				type: DataTypes.UUID,
				allowNull: false,
			},

			createdAt: {
				type: DataTypes.DATE,
				allowNull: false,
				defaultValue: DataTypes.NOW,
			},
		});

		await queryInterface.addConstraint('starred_messages', {
			fields: ['userId', 'chatId'],
			type: 'unique',
			name: 'unique_user_chat_star',
		});
	},

	async down(queryInterface: QueryInterface) {
		await queryInterface.dropTable('starred_messages');
	},
};
