import { QueryInterface, DataTypes } from 'sequelize';

export default {
	up: async (queryInterface: QueryInterface) => {
		const tableDescription = await queryInterface.describeTable('chats');

		// Add messageStatus enum column
		if (!tableDescription.messageStatus) {
			await queryInterface.addColumn('chats', 'messageStatus', {
				type: DataTypes.ENUM('sent', 'delivered', 'read'),
				defaultValue: 'sent',
				allowNull: false,
			});
		}

		// Add isRead boolean column
		if (!tableDescription.isRead) {
			await queryInterface.addColumn('chats', 'isRead', {
				type: DataTypes.BOOLEAN,
				defaultValue: false,
				allowNull: false,
			});
		}

		// Add deliveredAt timestamp column
		if (!tableDescription.deliveredAt) {
			await queryInterface.addColumn('chats', 'deliveredAt', {
				type: DataTypes.DATE,
				allowNull: true,
			});
		}

		// Add readAt timestamp column
		if (!tableDescription.readAt) {
			await queryInterface.addColumn('chats', 'readAt', {
				type: DataTypes.DATE,
				allowNull: true,
			});
		}
	},

	down: async (queryInterface: QueryInterface) => {
		// Remove the columns in reverse order
		await queryInterface.removeColumn('chats', 'readAt');
		await queryInterface.removeColumn('chats', 'deliveredAt');
		await queryInterface.removeColumn('chats', 'isRead');
		await queryInterface.removeColumn('chats', 'messageStatus');
	},
};
